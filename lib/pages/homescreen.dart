import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/api/apimanage.dart';
import 'package:kiddo_tracker/model/child.dart';
import 'package:kiddo_tracker/model/route.dart';
import 'package:kiddo_tracker/mqtt/MQTTService.dart';
import 'package:kiddo_tracker/routes/routes.dart';
import 'package:kiddo_tracker/services/children_provider.dart';
import 'package:kiddo_tracker/services/mqtt_message_handler.dart';
import 'package:kiddo_tracker/services/notification_service.dart';
import 'package:kiddo_tracker/services/permission_service.dart';
import 'package:kiddo_tracker/widget/bus_current_location.dart';
import 'package:kiddo_tracker/widget/child_card_widget.dart';
import 'package:kiddo_tracker/widget/location_and_route_dialog.dart';
import 'package:kiddo_tracker/widget/mqtt_widget.dart';
import 'package:kiddo_tracker/widget/stop_locations_dialog.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../services/workmanager_callback.dart';

// Top-level function for isolate entry point
void getNotificationIsolate(dynamic message) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    message['rootIsolateToken'],
  );
  final SendPort sendPort = message['sendPort'];
  final List<Map<String, String>> routes = message['routes'];
  try {
    final userId = await SharedPreferenceHelper.getUserNumber();
    final sessionId = await SharedPreferenceHelper.getUserSessionId();
    if (userId != null && sessionId != null) {
      List results = [];
      for (var route in routes) {
        final response = await ApiService.getNotification(
          userId,
          sessionId,
          route['routeId']!,
          route['oprId']!,
        );
        results.add(response.data);
        Logger().i('Data added: ${response.data}');
      }
      sendPort.send({'success': true, 'data': results});
    } else {
      sendPort.send({
        'success': false,
        'error': 'User ID or Session ID is null',
      });
    }
  } catch (e) {
    sendPort.send({'success': false, 'error': e.toString()});
  }
}

class HomeScreen extends StatefulWidget {
  final Function(int)? onNewMessage;

  const HomeScreen({super.key, this.onNewMessage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  static bool _hasFetchedNotifications = false;

  bool _isLoading = true;
  final SqfliteHelper _sqfliteHelper = SqfliteHelper();

  bool _hasInitialized = false;

  int _boardRefreshKey = 0;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  late MQTTService _mqttService;
  final Completer<MQTTService> _mqttCompleter = Completer<MQTTService>();

  List<String> stopArrivalTimes = [];

  String _mqttStatus = 'Disconnected';

  @override
  bool get wantKeepAlive => true;

  @override
  @override
  void initState() {
    super.initState();
    if (!_hasInitialized) {
      _initAsync();
      _hasInitialized = true;
    }
    SharedPreferenceHelper.setAppActive(true);
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  Future<void> _initAsync() async {
    await PermissionService.requestNotificationPermission();
    await PermissionService.requestLocationPermission();
    await _fetchChildrenFromDb();
    await _updateActiveRoutesOnLoad();
    await _mqttCompleter.future;
    await _subscribeToTopics();
    await _fetchRouteStoapge();
    await getNotificationInIsolate();
    // Populate stop arrival times after fetching route storage
    stopArrivalTimes.clear();
    final children = Provider.of<ChildrenProvider>(
      context,
      listen: false,
    ).children;
    for (var child in children) {
      for (var route in child.routeInfo) {
        if (route.stopArrivalTime.isNotEmpty) {
          stopArrivalTimes.add(route.stopArrivalTime);
        }
      }
    }
    //print the stopArrivalTimes list
    Logger().i('Stop Arrival Times: $stopArrivalTimes');
    stopArrivalTimes.sort(); // Sort the list in ascending order
    //get the earliest time
    final earliestTime = stopArrivalTimes.first;
    Logger().i('Earliest Stop Arrival Time: $earliestTime');
    // Extract the first time from the format "(HH:MM - HH:MM)"
    final firstTime = earliestTime.substring(1, earliestTime.indexOf(' - '));
    //split the first time into hour and minute
    final timeParts = firstTime.split(':');
    final hourStr = timeParts[0]
        .replaceAll(RegExp(r'^\D+'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    final minuteStr = timeParts[1]
        .replaceAll(RegExp(r'^\D+'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    final hour = int.parse(hourStr.isEmpty ? '0' : hourStr);
    final minute = int.parse(minuteStr.isEmpty ? '0' : minuteStr);
    // Store the earliest route hour and minute in shared preferences
    await SharedPreferenceHelper.setEarliestRouteHour(hour);
    await SharedPreferenceHelper.setEarliestRouteMinute(minute);
    Logger().d("The Alarm will set on: $hour : $minute");
    await scheduleDailyDataLoad(hour, minute);
    // await scheduleDailyDataLoad(15, 40);
  }

  Future<void> _subscribeToTopics() async {
    try {
      await Provider.of<ChildrenProvider>(
        context,
        listen: false,
      ).subscribeToTopics(mqttService: _mqttService);
    } catch (e) {
      Logger().e('Error subscribing to topics: $e');
    }
  }

  @override
  void dispose() {
    SharedPreferenceHelper.setAppActive(false);
    _controller.dispose();
    _hasFetchedNotifications = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChildrenProvider>(
      builder: (context, provider, child) {
        final children = provider.children;
        final studentSubscriptions = provider.studentSubscriptions;
        return Scaffold(
          body: FadeTransition(
            opacity: _animation,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // MQTT Status Indicator
                      MqttWidget(
                        onMessageReceived: _onMQTTMessageReceived,
                        onStatusChanged: _onMQTTStatusChanged,
                        onLog: _onMQTTLog,
                        onInitialized: (mqttService) {
                          _mqttService = mqttService;
                          if (!_mqttCompleter.isCompleted) {
                            _mqttCompleter.complete(mqttService);
                          }
                          Provider.of<ChildrenProvider>(
                            context,
                            listen: false,
                          ).setMqttService(mqttService);
                        },
                      ),
                      Expanded(
                        child: children.isEmpty
                            ? const Center(
                                child: Text(
                                  'No children found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: children.length,
                                itemBuilder: (context, index) {
                                  final child = children[index];
                                  //print the child routeInfo
                                  Logger().i(
                                    'Child ${child.name} Route Info: ${child.routeInfo}',
                                  );
                                  return ValueListenableBuilder<Child>(
                                    valueListenable: provider
                                        .childNotifiers[child.studentId]!,
                                    builder: (context, updatedChild, _) {
                                      return ValueListenableBuilder<
                                        Map<String, bool>
                                      >(
                                        valueListenable:
                                            provider.activeRoutesNotifier,
                                        builder: (context, activeRoutes, _) {
                                          return ChildCardWidget(
                                                child: updatedChild,
                                                subscription:
                                                    studentSubscriptions[child
                                                        .studentId],
                                                onSubscribeTap: () =>
                                                    _onSubscribe(updatedChild),
                                                onBusTap: (routeId, routes) =>
                                                    _onBusTap(routeId, routes),
                                                onLocationTap:
                                                    (routeId, routes) =>
                                                        _onLocationTap(
                                                          routeId,
                                                          routes,
                                                        ),
                                                onDeleteTap:
                                                    (
                                                      routeId,
                                                      routes,
                                                    ) => _onDeleteTap(
                                                      routeId,
                                                      routes,
                                                      updatedChild.studentId,
                                                    ),
                                                onOnboardTap:
                                                    (routeId, routes) =>
                                                        _onOnboard(
                                                          routeId,
                                                          routes,
                                                        ),
                                                onOffboardTap:
                                                    (routeId, routes) =>
                                                        _onOffboard(
                                                          routeId,
                                                          routes,
                                                        ),
                                                onAddRouteTap: () =>
                                                    _onAddRoute(updatedChild),
                                                activeRoutes: activeRoutes,
                                                boardRefreshKey:
                                                    _boardRefreshKey,
                                              )
                                              .animate()
                                              .fade(duration: 600.ms)
                                              .slide(
                                                begin: const Offset(0, 0.1),
                                              );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Future<void> _fetchChildrenFromDb() async {
    try {
      setState(() {
        _isLoading = true;
      });
      await Provider.of<ChildrenProvider>(
        context,
        listen: false,
      ).updateChildren();
      Logger().i(
        'Fetched children: ${Provider.of<ChildrenProvider>(context, listen: false).children}',
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Logger().e('Error fetching children from DB: $e');
    }
  }

  Future<void> _updateActiveRoutesOnLoad() async {
    final userId = await SharedPreferenceHelper.getUserNumber();
    final sessionId = await SharedPreferenceHelper.getUserSessionId();
    if (userId == null || sessionId == null) return;

    final children = Provider.of<ChildrenProvider>(
      context,
      listen: false,
    ).children;
    final Set<String> uniqueRoutes = <String>{};
    for (var child in children) {
      for (var route in child.routeInfo) {
        final String key = '${route.routeId}_${route.oprId}';
        if (!uniqueRoutes.contains(key)) {
          uniqueRoutes.add(key);
          try {
            final response = await ApiService.fetchOperationStatus(
              userId,
              route.oprId.toString(),
              sessionId,
            );
            Logger().i(response);
            if (response.statusCode == 200 &&
                response.data.isNotEmpty &&
                response.data[0]['result'] == 'ok' &&
                response.data.length > 1) {
              final operationData = response.data[1]['data'];
              if (operationData is List && operationData.isNotEmpty) {
                final operationStatus = operationData[0]['operation_status'];
                final provider = Provider.of<ChildrenProvider>(
                  context,
                  listen: false,
                );
                if (operationStatus == 1) {
                  await provider.updateActiveRoutes(key, true);
                } else {
                  await provider.updateActiveRoutes(key, false);
                }
              }
            }
          } catch (e) {
            Logger().e('Error fetching operation status for $key: $e');
          }
        }
      }
    }
  }

  Future<void> _onMQTTMessageReceived(String message) async {
    final provider = Provider.of<ChildrenProvider>(context, listen: false);
    await MQTTMessageHandler.handleMQTTMessage(
      message,
      _sqfliteHelper,
      provider: provider,
      context: context,
    );
  }

  // Future<void> _handleOnboardMessage(
  //   Map<String, dynamic> data,
  //   Map<String, dynamic> jsonMessage,
  // ) async {
  //   final String? studentId = data['studentid'] as String?;
  //   final int status = data['status'] as int? ?? 1; // Default to onboard

  //   if (studentId != null) {
  //     await _updateChildStatus(studentId, status, jsonMessage);
  //   } else {
  //     Logger().w('Missing studentid in onboard message');
  //   }
  // }

  // Future<void> _handleOffboardMessage(
  //   Map<String, dynamic> data,
  //   Map<String, dynamic> jsonMessage,
  // ) async {
  //   final List<dynamic>? offlist = data['offlist'] as List<dynamic>?;

  //   if (offlist != null) {
  //     for (var id in offlist) {
  //       if (id is String) {
  //         await _updateChildStatus(id, 2, jsonMessage); // Offboard status
  //       }
  //     }
  //   } else {
  //     Logger().w('Missing offlist in offboard message');
  //   }
  // }

  // void _handleBusStatusMessage(int? msgtype, Map<String, dynamic> jsonMessage) {
  //   String devid = jsonMessage['devid'] ?? '';
  //   if (devid.isNotEmpty) {
  //     final provider = Provider.of<ChildrenProvider>(context, listen: false);
  //     final children = provider.children;
  //     for (var child in children) {
  //       for (var route in child.routeInfo) {
  //         String key = '${route.routeId}_${route.oprId}';
  //         if (key == devid) {
  //           NotificationService.notifyBusStatus(
  //             routeName: route.routeName,
  //             isActivated: msgtype == 1,
  //           );
  //           if (msgtype == 1) {
  //             provider.updateActiveRoutes(key, true);
  //           } else if (msgtype == 4) {
  //             provider.updateActiveRoutes(key, false);
  //           }
  //         }
  //       }
  //     }
  //   } else {
  //     Logger().w('Missing devid in bus active/inactive message');
  //   }
  // }

  // Future<void> _updateChildStatus(
  //   String studentId,
  //   int status,
  //   Map<String, dynamic> jsonMessage,
  // ) async {
  //   final provider = Provider.of<ChildrenProvider>(context, listen: false);
  //   final children = provider.children;
  //   final childIndex = children.indexWhere(
  //     (child) => child.studentId == studentId,
  //   );
  //   String onBoardLocation = "";
  //   String offBoardLocation = "";

  //   if (childIndex != -1) {
  //     // Show a notification
  //     NotificationService.notifyChildStatus(
  //       childName: children[childIndex].name,
  //       isOnboard: status == 1,
  //     );
  //     //set location base on jsonMessage['data']['msgtype']
  //     if (status == 1) {
  //       onBoardLocation = jsonMessage['data']['location'];
  //     } else if (status == 2) {
  //       offBoardLocation = jsonMessage['data']['location'];
  //     }
  //     //save to database
  //     _sqfliteHelper.insertActivity({
  //       'student_id': studentId,
  //       'student_name': children[childIndex].name,
  //       'status': status == 1 ? 'onboarded' : 'offboarded',
  //       'on_location': onBoardLocation,
  //       'off_location': offBoardLocation,
  //       'route_id': jsonMessage['devid'].split('_')[0],
  //       'oprid': jsonMessage['devid'].split('_')[1],
  //     });

  //     // Update the status of the child
  //     Logger().i('Updating status for child $studentId to $status');
  //     provider.updateChildOnboardStatus(studentId, status);
  //     //update the ActivityScreen after data insert in database
  //     provider.updateActivity();
  //     if (status == 1 || status == 2) {
  //       setState(() {
  //         _boardRefreshKey++;
  //       });
  //     }
  //     Logger().i('Updated status for child $studentId to $status');
  //   } else {
  //     Logger().w('Child with studentId $studentId not found');
  //   }
  // }

  void _onMQTTStatusChanged(String status) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _mqttStatus = status;
        });
      });
    }
  }

  void _onMQTTLog(String log) {
    Logger().i('MQTT: $log');
  }

  // Action methods
  Future<void> _onSubscribe(Child child) async {
    // Implement subscribe action
    Logger().i('Subscribe clicked for ${child.name}, ${child.studentId}');
    // Add your subscription logic here
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.subscribe,
      arguments: child.studentId,
    );
    if (result == true) {
      await Provider.of<ChildrenProvider>(
        context,
        listen: false,
      ).updateChildren();
    }
  }

  void _onOnboard(String routeId, List<RouteInfo> routes) {
    // Implement onboard action
    Logger().i('Onboard clicked for route $routeId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Onboard tapped for route $routeId')),
    );
    // Add your onboard logic here
  }

  void _onOffboard(String routeId, List<RouteInfo> routes) {
    // Implement offboard action
    Logger().i('Offboard clicked for route $routeId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Offboard tapped for route $routeId')),
    );
    // Add your offboard logic here
  }

  Future<void> _onAddRoute(Child child) async {
    Logger().i('Add route clicked for ${child.name}');
    // Navigate to AddChildRoutePage and wait for result
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.addRoute,
      arguments: {'childName': child.nickname, 'childId': child.studentId},
    );

    // If a new route was added successfully, refresh the children list to show updated data
    if (result == true) {
      await Provider.of<ChildrenProvider>(
        context,
        listen: false,
      ).updateChildren();
    }
  }

  Future<void> _onBusTap(String routeId, List<RouteInfo> routes) async {
    // Implement bus tap action
    Logger().i('Bus tapped for route $routeId');
    if (routes.isEmpty) {
      Logger().e('No routes available for routeId: $routeId');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No routes available for $routeId')),
      );
      return;
    }
    // check route status active or inactive
    // base on '${route.routeId}_${route.oprId}';
    final provider = Provider.of<ChildrenProvider>(context, listen: false);
    final activeRoutes = provider.activeRoutesNotifier.value;
    String key = '${routeId}_${routes.first.oprId}';
    final isActive = activeRoutes[key] ?? false;
    Logger().i('Route $routeId is ${isActive ? 'active' : 'inactive'}');
    // only for inactive show a snackbar in red color
    if (!isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bus for route $routeId is inactive'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    } else {
      // call an ApiService.fetchOperationStatus to get the bus current location.
      final userId = await SharedPreferenceHelper.getUserNumber();
      final sessionId = await SharedPreferenceHelper.getUserSessionId();
      final oprId = routes.first.oprId;
      final vehicleId = routes.first.vehicleId;

      try {
        final responseLocation = await ApiService.fetchOperationStatus(
          userId!,
          oprId.toString(),
          sessionId!,
        );
        Logger().w(responseLocation);

        final responseVehicle = await ApiService.fetchVehicleInfo(
          userId,
          sessionId,
          vehicleId,
        );
        Logger().w(responseVehicle);

        String currentLocation = '';
        String busName = '';

        if (responseLocation.statusCode == 200 &&
            responseLocation.data.isNotEmpty &&
            responseLocation.data[0]['result'] == 'ok' &&
            responseLocation.data.length > 1) {
          final operationData = responseLocation.data[1]['data'];
          if (operationData is List && operationData.isNotEmpty) {
            currentLocation = operationData[0]['current_location'] ?? '';
          }
        }
        Logger().i('Current Location: $currentLocation');

        if (responseVehicle.statusCode == 200 &&
            responseVehicle.data.isNotEmpty &&
            responseVehicle.data[0]['result'] == 'ok' &&
            responseVehicle.data.length > 1) {
          final vehicleData = responseVehicle.data[1]['data'];
          if (vehicleData is List && vehicleData.isNotEmpty) {
            busName = vehicleData[0]['vehicle_name'] ?? '';
          }
        }
        Logger().i('Bus Name: $busName');

        if (currentLocation.isNotEmpty && busName.isNotEmpty) {
          final latLng = currentLocation.split(',');
          final latitude = double.tryParse(latLng[0]) ?? 0.0;
          final longitude = double.tryParse(latLng[1]) ?? 0.0;

          Logger().i(
            'Opening map dialog with coordinates: lat=$latitude, lng=$longitude, bus=$busName',
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BusCurrentLocationDialog(
                routeId: routeId,
                routes: routes,
                latitude: latitude,
                longitude: longitude,
                busName: busName,
              ),
            ),
          );
        } else {
          Logger().w(
            'Cannot open map dialog: currentLocation="$currentLocation", busName="$busName"',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to fetch bus location')),
          );
        }
      } catch (e) {
        Logger().e('Error fetching bus location: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error fetching bus location')),
        );
      }

      // open a dialog to the bus location in google map
    }
  }

  Future<void> _onLocationTap(String routeId, List<RouteInfo> routes) async {
    final userId = await SharedPreferenceHelper.getUserNumber();
    final sessionId = await SharedPreferenceHelper.getUserSessionId();
    final oprId = routes.first.oprId;
    final vehicleId = routes.first.vehicleId;
    Logger().i(
      'Location tapped for route $routeId, userId: $userId, oprId: $oprId, sessionId: $sessionId',
    );

    try {
      // Fetch location and route details

      final responseRouteDetail = await ApiService.fetchVehicleInfo(
        userId!,
        sessionId!,
        vehicleId,
      );
      Logger().i(responseRouteDetail);
      //[{result: ok}, {data: [{vehicle_id: OD946890001, vehicle_name: Marcopolo XL, reg_no: OD11Z5898, type: BUS, capacity: 50, driver_name: Mr. Driver, assistant_name: Mr. Assistant, contact1: 8093705005, contact2: 8093705005}]}]

      final responseLocation = await ApiService.fetchOperationStatus(
        userId,
        oprId.toString(),
        sessionId,
      );
      Logger().i(responseLocation);
      //[{result: ok}, {data: [{operation_status: 0, current_location: , stop_details: [{"1":["Mumbai","08:00","08:30","18.9581934,72.8320729"]},{"2":["Goa","10:00","10:00","15.30106506,74.13523982"]}]}]}]
      //now update the bus active status in ChildrenProvider
      if (responseLocation.statusCode == 200 &&
          responseLocation.data.isNotEmpty &&
          responseLocation.data[0]['result'] == 'ok' &&
          responseLocation.data.length > 1) {
        final operationData = responseLocation.data[1]['data'];
        if (operationData is List && operationData.isNotEmpty) {
          final operationStatus = operationData[0]['operation_status'];
          String key = '${routeId}_$oprId';
          final provider = Provider.of<ChildrenProvider>(
            context,
            listen: false,
          );
          if (operationStatus == 1) {
            provider.updateActiveRoutes(key, true);
          } else {
            provider.updateActiveRoutes(key, false);
          }
        }
      }

      //get stop_list from database
      final sqliteStopList = await _sqfliteHelper.getStopListByOprIdAndRouteId(
        oprId.toString(),
        routeId,
      );
      Logger().i('sqliteStopList: $sqliteStopList');
      //sqliteStopList: [{stop_list: [{"stop_id":"1","stop_name":"Mumbai","location":"18.9581934,72.8320729","stop_type":1},{"stop_id":"2","stop_name":"Goa","location":"15.30106506,74.13523982","stop_type":3}]}]

      final stopList = await _sqfliteHelper.getStopListByOprIdAndRouteId(
        oprId.toString(),
        routeId,
      );
      Logger().i('oprId: $oprId, routeId: $routeId, stopList: $stopList');
      //oprId: 1, routeId: OD94689000001, stopList: [{stop_list: [{"stop_id":"1","stop_name":"Mumbai","location":"18.9581934,72.8320729","stop_type":1},{"stop_id":"2","stop_name":"Goa","location":"15.30106506,74.13523982","stop_type":3}]}]

      //now get responseRouteDetail vechile data driver_name and contact1 and contact2

      //get the driver_name and contact1 and contact2 from responseRouteDetail
      String driverName = '';
      String contact1 = '';
      String contact2 = '';

      if (responseRouteDetail.data.isNotEmpty &&
          responseRouteDetail.data[0]['result'] == 'ok' &&
          responseRouteDetail.data.length > 1) {
        final vehicleData = responseRouteDetail.data[1]['data'];
        if (vehicleData is List && vehicleData.isNotEmpty) {
          final vehicleInfo = vehicleData[0];
          driverName = vehicleInfo['driver_name'] ?? '';
          contact1 = vehicleInfo['contact1'] ?? '';
          contact2 = vehicleInfo['contact2'] ?? '';
        }
      }
      //use stopList and show the stop_name and location in a list
      final stopListMap = stopList.toList();
      Logger().i('stopListMap: $stopListMap');
      //stopListMap: [{stop_list: [{"stop_id":"1","stop_name":"Mumbai","location":"18.9581934,72.8320729","stop_type":1},{"stop_id":"2","stop_name":"Goa","location":"15.30106506,74.13523982","stop_type":3}]}]
      //get the stop Name and location
      if (stopListMap.isNotEmpty) {
        Logger().i('stop_list: ${stopListMap[0]['stop_list']}');
        final stopListJson = stopListMap[0]['stop_list'];
        if (stopListJson is String && stopListJson.isNotEmpty) {
          //get the stop_name and location from stopListJson
          try {
            final List<dynamic> stopsData = jsonDecode(stopListJson);
            //get 'stop_name' and 'location' from stopsData
            //list to add stop_name and location

            //using a list to store the StopLocations
            late List<StopLocation> stopLocations = [];
            // List<Map<String, String>> stopLocations = [];
            //store the stop_name and location in a list
            for (var stopData in stopsData) {
              Logger().i(
                'stop_name: ${stopData['stop_name']}, location: ${stopData['location']}',
              );
              stopLocations.add(
                StopLocation(
                  stopId: stopData['stop_id'],
                  stopName: stopData['stop_name'],
                  location: stopData['location'],
                ),
              );
              // stopLocations.add({
              //   'stop_name': stopData['stop_name'],
              //   'location': stopData['location'],
              // });
            }
            Logger().i('Stop locations: $stopLocations');
            //show the stopLocations in a dialog
            // _showStopLocationsDialog(stopLocations, driverName, contact1, contact2);
            Logger().i('Showing ${stopsData.length} stop locations dialog');
            showDialog(
              context: context,
              builder: (context) => StopLocationsDialog(
                stopLocations,
                driverName,
                contact1,
                contact2,
              ),
            );
          } catch (e) {
            Logger().e('Error parsing stop_list JSON: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error loading stop locations')),
            );
          }
        }
      } else {
        Logger().i('No stop_list found for oprId: $oprId, routeId: $routeId');
      }
      //open a  dialog and show the listed location in google map.
      // Parse stop_list data and show in dialog
      // if (stopListMap.isNotEmpty && stopListMap[0]['stop_list'] != null) {
      //   final stopListJson = stopListMap[0]['stop_list'];
      //   if (stopListJson is String && stopListJson.isNotEmpty) {
      //     try {
      //       final List<dynamic> stopsData = jsonDecode(stopListJson);
      //       final List<StopLocation> stopLocations = stopsData.map((stopData) {
      //         return StopLocation.fromJson(stopData as Map<String, dynamic>);
      //       }).toList();

      //       final routeName = routes.first.routeName ?? 'Route $routeId';

      //       // Show the stop locations dialog
      //       showDialog(
      //         context: context,
      //         builder: (context) => StopLocationsDialog(
      //           stopLocations: stopLocations,
      //           routeName: routeName,
      //         ),
      //       );
      //     } catch (e) {
      //       Logger().e('Error parsing stop_list JSON: $e');
      //       ScaffoldMessenger.of(context).showSnackBar(
      //         const SnackBar(content: Text('Error loading stop locations')),
      //       );
      //     }
      //   }
      // } else {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text('No stop locations available for this route'),
      //     ),
      //   );
      // }

      // final map = extractLocationAndRouteData(
      //   responseLocation,
      //   responseRouteDetail,
      // );
      // Logger().i(map);
      //now open a custom dialog to show location and route details
      // _showLocationAndRouteDialog(map);
    } catch (e) {
      Logger().e('Error fetching location and route details: $e');
    }
  }

  // void _showStopLocationsDialog(StopLocation stopLocations, String driverName, String contact1, String contact2) {
  //   // in this dialog show a map with all the stop locations marked and below the map show the driver name and contact details
  //   showDialog(
  //     context: context,
  //     builder: (context) => StopLocationsDialog(stopLocations, driverName, contact1, contact2),
  //   );
  // }

  Future<void> _onDeleteTap(
    String routeId,
    List<RouteInfo> routes,
    String studentId,
  ) async {
    //userId
    final userId = await SharedPreferenceHelper.getUserNumber();
    final sessonId = await SharedPreferenceHelper.getUserSessionId();
    final oprId = routes.first.oprId;
    // Show confirmation dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this route?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    Logger().i(
      'Delete tapped for route $routeId, userId: $userId, oprId: $oprId, sessonId: $sessonId',
    );
    // run api to delete/remove the route
    ApiService.deleteStudentRoute(
      studentId,
      oprId.toString(),
      sessonId!,
      userId!,
    ).then((response) async {
      if (response.statusCode == 200) {
        Logger().i(response.data);
        if (response.data[0]['result'] == 'ok') {
          if (response.data[1]['data'] == 'ok') {
            //Also remove from the database
            await _sqfliteHelper.deleteRouteInfoByStudentIdAndOprId(
              studentId,
              oprId.toString(),
            );
            // Refresh the children list to show updated data
            await Provider.of<ChildrenProvider>(
              context,
              listen: false,
            ).updateChildren();
            Provider.of<ChildrenProvider>(context, listen: false);
            // .removeChildOrRouteOprid("route", studentId);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Delete Success for route $routeId')),
            );
          }
        }
      }
    });
  }

  void _showLocationAndRouteDialog(Map<String, dynamic> map) {
    showDialog(
      context: context,
      builder: (context) => LocationAndRouteDialog(
        latitude: double.tryParse(map['latitude'] ?? '0') ?? 0.0,
        longitude: double.tryParse(map['longitude'] ?? '0') ?? 0.0,
        vehicleName: map['vehicle_name'] ?? '',
        regNo: map['reg_no'] ?? '',
        driverName: map['driver_name'] ?? '',
        contact1: map['contact1'] ?? '',
        contact2: map['contact2'] ?? '',
      ),
    );
  }

  //should be only after the children have been fetched
  Future<void> _fetchRouteStoapge() async {
    try {
      final userId = await SharedPreferenceHelper.getUserNumber();
      final sessionId = await SharedPreferenceHelper.getUserSessionId();
      final tspList = await _sqfliteHelper.getChildTspId();
      Logger().i('Child TSP List: $tspList');

      for (var tsp in tspList) {
        final String tspId = tsp['tsp_id'];
        Logger().i(tspId);

        /// Extract oprid + route_id pairs from local DB
        final routeIds = <String>{};
        final oprIds = <String>{};
        final stopName = <String>{};
        await _extractLocalRoutePairs(
          tsp['routes'],
          routeIds,
          oprIds,
          stopName,
        );
        Logger().i('$routeIds ');

        /// Fetch Remote Route List From API
        await _fetchAndProcessTspRoute(
          tspId: tspId,
          userId: userId,
          sessionId: sessionId,
          routeIds: routeIds,
          oprIds: oprIds,
          stopName: stopName,
        );
      }
    } catch (e) {
      Logger().e('Error fetching route storage: $e');
    }
  }

  //
  Future<void> _fetchAndProcessTspRoute({
    required String tspId,
    required String? userId,
    required String? sessionId,
    required Set<String> routeIds,
    required Set<String> oprIds,
    required Set<String> stopName,
  }) async {
    try {
      final response = await ApiManager().post(
        'kturoutelistbytsp',
        data: {'userid': userId, 'sessionid': sessionId, 'tsp_id': tspId},
      );

      if (response.statusCode != 200 || response.data[0]['result'] != 'ok') {
        Logger().w('Invalid response for tspId: $tspId');
        return;
      } else {
        final apiRoutes = response.data[1]['data'];
        Logger().i('API Routes: $apiRoutes');

        for (var route in apiRoutes) {
          final oprid = route['oprid'].toString().trim();
          final routeId = route['route_id'].toString().trim();

          Logger().i(
            "List of oprid and route_id from local DB → oprid: $oprIds | route_id: $routeIds | stop_name: $stopName",
          );
          Logger().i("API Route → oprid: $oprid | route_id: $routeId");

          /// Only insert & update matching oprid + route_id
          final isMatch = oprIds.contains(oprid) && routeIds.contains(routeId);
          Logger().i("Match result: $isMatch");
          if (isMatch) {
            Logger().i("MATCHED → Saving oprid: $oprid | route_id: $routeId");
            await _saveRouteToDatabase(route);
            Logger().i(
              "Updating children route_info for tspId: $tspId | route_id: $routeId",
            );
            await _updateChildrenRouteInfo(tspId, stopName, route);
          } else {
            Logger().i("SKIPPED → oprid: $oprid | route_id: $routeId");
          }
        }
      }
    } catch (e) {
      Logger().e(e);
    }
  }

  //
  Future<void> _updateChildrenRouteInfo(
    String tspId,
    Set<String> stopName,
    Map<String, dynamic> route,
  ) async {
    final childrenList = await _sqfliteHelper.getChildren();

    for (var child in childrenList) {
      try {
        final studentId = child['student_id'] as String?;
        final routeInfoRaw = child['route_info'] as String?;
        final tspIdRaw = child['tsp_id'] as String?;

        if (studentId == null || routeInfoRaw == null || tspIdRaw == null) {
          continue;
        }

        /// Ensure the child belongs to this oprid
        final tspIdList = List<String>.from(jsonDecode(tspIdRaw));
        if (!tspIdList.contains(tspId)) continue; // Match tspId directly

        String? lastStopLocation = _extractLastStopLocation(route['stop_list']);
        String? routeTimeByStopName = _getRouteTimeByStopName(
          route['stop_details'],
          stopName,
        );

        if (lastStopLocation != null && routeTimeByStopName != null) {
          //print last stop location and timing
          Logger().i(
            'Updating child $studentId route_info with school_location: $lastStopLocation and start_time: $routeTimeByStopName',
          );
          // Update only the fields we need: school_location and start_time
          await _sqfliteHelper.updateChildRouteInfo(
            studentId,
            tspId, // tspId
            route['route_id'], // route_id
            routeTimeByStopName, // start_time
            lastStopLocation, // school_location
          );
          Logger().i('Updated child route_info → studentId: $studentId');
        }
      } catch (e) {
        Logger().e('Error updating child route_info: $e');
      }
    }

    // refresh UI with new data
    if (mounted) {
      await Provider.of<ChildrenProvider>(
        context,
        listen: false,
      ).updateChildren();
      setState(() {
        _boardRefreshKey++;
      });
    }
  }

  //
  String? _extractLastStopLocation(String stopListJson) {
    try {
      final List<dynamic> stopsData = jsonDecode(stopListJson);
      if (stopsData.isNotEmpty) {
        final lastStop = stopsData.last as Map<String, dynamic>;
        return lastStop['location'] as String?;
      }
    } catch (e) {
      Logger().e('Error extracting last stop location: $e');
    }
    return null;
  }

  //
  Future<void> _saveRouteToDatabase(Map<String, dynamic> route) async {
    //add time inside route['stop_list'];
    //first match the name from route['stop_list'] to route['stop_details'] and if match then take
    try {
      List<dynamic> stopList = jsonDecode(route['stop_list']);
      List<dynamic> stopDetails = jsonDecode(route['stop_details']);

      // Create a map for quick lookup of stop details by name
      Map<String, Map<String, String>> stopDetailsMap = {};
      for (var detail in stopDetails) {
        if (detail is Map<String, dynamic>) {
          String key = detail.keys.first;
          List<dynamic> values = detail[key];
          if (values.length >= 3) {
            String stopName = values[0].toString().trim();
            String arrivalTime = values[1].toString();
            String departureTime = values[2].toString();
            stopDetailsMap[stopName] = {
              'arrival': arrivalTime,
              'departure': departureTime,
            };
          }
        }
      }

      // Update stop_list with time information
      for (var stop in stopList) {
        if (stop is Map<String, dynamic>) {
          String stopName = stop['stop_name'] ?? '';
          if (stopDetailsMap.containsKey(stopName)) {
            String arrival = stopDetailsMap[stopName]!['arrival']!;
            String departure = stopDetailsMap[stopName]!['departure']!;
            stop['time'] = '($arrival - $departure)';
          }
        }
      }

      // Update route['stop_list'] with the modified list
      route['stop_list'] = jsonEncode(stopList);
      // show ($arrival - $departure) time
      route['stop_arrival_time'] = stopDetailsMap.values
          .map((times) => '(${times['arrival']} - ${times['departure']})')
          .join(', ');
    } catch (e) {
      Logger().e('Error updating stop_list with times: $e');
    }

    await _sqfliteHelper.insertRoute(
      route['oprid'] ?? 0,
      route['route_id'] ?? '',
      route['start_time'] ?? '',
      route['vehicle_id'] ?? '',
      route['route_name'] ?? '',
      route['type'] ?? 0,
      route['stop_arrival_time'] ?? '',
      route['stop_list'] ?? '',
      route['stop_details'] ?? '',
    );

    Logger().i(
      'Inserted Route → ${route['route_id']} | oprid: ${route['oprid']}',
    );
  }

  //
  Future<void> _extractLocalRoutePairs(
    List<dynamic> routes,
    Set<String> routeIds,
    Set<String> oprIds,
    Set<String> stopName,
  ) async {
    for (var route in routes) {
      routeIds.add(route['route_id']);
      oprIds.add(route['oprid'].toString());
      stopName.add(route['stop_name']);
      Logger().i(
        'Local route → oprid: ${route['oprid'].toString()} | route_id: ${route['route_id']} | stop_name: ${route['stop_name']}',
      );
    }
  }

  // Function to call getNotification in a separate isolate
  Future<void> getNotificationInIsolate() async {
    Logger().i('Starting getNotificationInIsolate');
    final receivePort = ReceivePort();
    final children = Provider.of<ChildrenProvider>(
      context,
      listen: false,
    ).children;
    final List<Map<String, String>> routesList = [];
    final Set<String> uniqueRoutes = <String>{};
    for (var child in children) {
      for (var route in child.routeInfo) {
        final String key = '${route.routeId}_${route.oprId}';
        if (!uniqueRoutes.contains(key)) {
          uniqueRoutes.add(key);
          routesList.add({
            'routeId': route.routeId,
            'oprId': route.oprId.toString(),
          });
        }
      }
    }
    final userId = await SharedPreferenceHelper.getUserNumber();
    final sessionId = await SharedPreferenceHelper.getUserSessionId();
    final message = {
      'sendPort': receivePort.sendPort,
      'routes': routesList,
      'userId': userId,
      'sessionId': sessionId,
      'rootIsolateToken': RootIsolateToken.instance!,
    };
    Logger().i('$message here it is...');
    await Isolate.spawn(getNotificationIsolate, message);

    final result = await receivePort.first as Map<String, dynamic>;
    if (result['success'] == true) {
      Logger().i('Notifications fetched successfully: ${result['data']}');
      /*
      Notifications fetched successfully: [[{result: ok}, {data: [{notice_id: 5, type: 3, priority: 1, title: Route Operation Timing Updated, description: Route Operation "1"  stopage Timing changed. , validity: 2025-11-06T00:00:00.000Z, id: 1}, {notice_id: 7, type: 3, priority: 1, title: Route Operation Timing Updated, description: Route Operation "1"  stopage Timing changed. , validity: 2025-11-07T00:00:00.000Z, id: 1}, {notice_id: 10, type: 2, priority: 1, title: Stop List Updated, description: Stop List of Route ID "OD94689000001" is Modified. , validity: 2025-11-11T00:00:00.000Z, id: OD94689000001}, {notice_id: 11, type: 3, priority: 1, title: Route Operation Timing Updated, description: Route Operation "1"  stopage Timing changed. , validity: 2025-11-11T00:00:00.000Z, id: 1}]}]]
      */
      // count the data length from result['data'] and update the onNewMessage
      final notifications = result['data'] as List<dynamic>;
      int notificationCount = 0;
      int newNotificationCount = 0;
      //clear existing notifications from database before inserting new ones
      // await _sqfliteHelper.clearNotifications();
      //get existing unread notification count
      final int getUnreadNotice = await _sqfliteHelper
          .getUnreadNotificationCount();
      for (var notificationSet in notifications) {
        if (notificationSet is List &&
            notificationSet.length > 1 &&
            notificationSet[0]['result'] == 'ok') {
          final data = notificationSet[1]['data'] as List<dynamic>;
          notificationCount += data.length;
          //store the notifications in the database
          for (var notice in data) {
            //handle duplicate notification based on notice_id
            final bool existingNotice = await _sqfliteHelper
                .getNotificationByNoticeId(notice['notice_id'].toString());
            if (existingNotice == false) {
              newNotificationCount++;
              Logger().i("new notice${notice['notice_id']}");
              //insert into notification table
              await _sqfliteHelper.insertNotification({
                'notice_id': notice['notice_id'].toString(),
                'type': notice['type'].toString(),
                'priority': notice['priority'].toString(),
                'title': notice['title'].toString(),
                'description': notice['description'].toString(),
                'validity': notice['validity'].toString(),
                'route_id': notice['id'].toString(),
                'is_read': 0, // 0 for unread, 1 for read
              });
            } else {
              Logger().i("not bull${notice['notice_id']}");
            }
          }
        }
      }

      //show count of new notifications or unread notifications
      Logger().i('Total notifications from server: $notificationCount');
      Logger().i('New notifications added: $newNotificationCount');
      Logger().i('Total unread notifications in DB: $getUnreadNotice');
      // add newNotificationCount and getUnreadNotice
      final totalNotifications = newNotificationCount + getUnreadNotice;
      Logger().i('Total notifications to show: $totalNotifications');
      if (totalNotifications > 0) {
        // Fetch all unread notifications and push notifications in loop
        final unreadNotifications = await _sqfliteHelper
            .getUnreadNotifications();
        Logger().w(unreadNotifications);
        // Push all notifications concurrently
        final List<Future<void>> notificationFutures = [];
        for (var notice in unreadNotifications) {
          notificationFutures.add(_showNotificationForNotice(notice));
        }
        await Future.wait(notificationFutures);
        //update the onNewMessage
        widget.onNewMessage?.call(totalNotifications);
      }
    } else {
      Logger().e('Error fetching notifications: ${result['error']}');
    }
  }

  Future<void> _showNotificationForNotice(Map<String, dynamic> notice) async {
    Logger().w(notice['type']);
    //show base on type
    if (notice['type'].toString() == '1') {
      //for tsp notice
      NotificationService.showGeneralNotification(
        title: notice['title'].toString(),
        body: notice['description'].toString(),
      );
    } else if (notice['type'].toString() == '2') {
      //for route notice
      //get route name from route_id
      final String? routeName = await _sqfliteHelper.getRouteNameById(
        notice['route_id'].toString(),
      );
      NotificationService.showGeneralNotification(
        title: notice['title'].toString(),
        body:
            notice['description'].toString() +
            (routeName != null ? ' Update your stop for $routeName' : ''),
      );
    } else if (notice['type'].toString() == '3') {
      //for timing notice
      NotificationService.showGeneralNotification(
        title: notice['title'].toString(),
        body: notice['description'].toString(),
      );
    } else if (notice['type'].toString() == '4') {
      //for vehicle notice
      NotificationService.showGeneralNotification(
        title: notice['title'].toString(),
        body: notice['description'].toString(),
      );
    } else {
      //default
      NotificationService.showGeneralNotification(
        title: notice['title'].toString(),
        body: notice['description'].toString(),
      );
    }
  }

  String? _getRouteTimeByStopName(route, Set<String> stopName) {
    try {
      final List<dynamic> stopDetails = jsonDecode(route);
      for (var detail in stopDetails) {
        if (detail is Map<String, dynamic>) {
          String key = detail.keys.first;
          List<dynamic> values = detail[key];
          if (values.length >= 3) {
            String stopNameValue = values[0].toString().trim();
            // Case-insensitive and trimmed matching
            if (stopName.any(
              (name) =>
                  name.trim().toLowerCase() == stopNameValue.toLowerCase(),
            )) {
              String arrivalTime = values[1].toString();
              String departureTime = values[2].toString();
              return '($arrivalTime - $departureTime)';
            }
          }
        }
      }
    } catch (e) {
      Logger().e('Error extracting route time by stop name: $e');
    }
    return null;
  }
}
