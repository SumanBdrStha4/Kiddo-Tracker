import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/api/apimanage.dart';
import 'package:kiddo_tracker/model/child.dart';
import 'package:kiddo_tracker/model/route.dart';
import 'package:kiddo_tracker/mqtt/MQTTService.dart';
import 'package:kiddo_tracker/routes/routes.dart';
import 'package:kiddo_tracker/services/children_provider.dart';
import 'package:kiddo_tracker/services/notification_service.dart';
import 'package:kiddo_tracker/services/permission_service.dart';
import 'package:kiddo_tracker/widget/child_card_widget.dart';
import 'package:kiddo_tracker/widget/location_and_route_dialog.dart';
import 'package:kiddo_tracker/widget/mqtt_widget.dart';
import 'package:kiddo_tracker/widget/stop_locations_dialog.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNewMessage;

  const HomeScreen({super.key, this.onNewMessage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  bool _isLoading = true;
  final SqfliteHelper _sqfliteHelper = SqfliteHelper();

  bool _hasInitialized = false;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  late MQTTService _mqttService;
  final Completer<MQTTService> _mqttCompleter = Completer<MQTTService>();

  Map<String, bool> activeRoutes = {};
  int _boardRefreshKey = 0;
  late StreamSubscription<String> _streamSubscription;

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
    await _mqttCompleter.future;
    await _subscribeToTopics();
    await _fetchRouteStoapge();
    // await Workmanager().registerPeriodicTask("fetchChildrenTask", "fetchChildren", frequency: Duration(minutes: 15));
    // // Register a one-off task to test the callback immediately
    // await Workmanager().registerOneOffTask("fetchChildrenOneOff", "fetchChildren", initialDelay: Duration(seconds: 30));
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
    _streamSubscription.cancel();
    _controller.dispose();
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
                                  return ChildCardWidget(
                                        child: child,
                                        subscription:
                                            studentSubscriptions[child
                                                .studentId],
                                        onSubscribeTap: () =>
                                            _onSubscribe(child),
                                        onBusTap: (routeId, routes) =>
                                            _onBusTap(routeId, routes),
                                        onLocationTap: (routeId, routes) =>
                                            _onLocationTap(routeId, routes),
                                        onDeleteTap: (routeId, routes) =>
                                            _onDeleteTap(
                                              routeId,
                                              routes,
                                              child.studentId,
                                            ),
                                        onOnboardTap: (routeId, routes) =>
                                            _onOnboard(routeId, routes),
                                        onOffboardTap: (routeId, routes) =>
                                            _onOffboard(routeId, routes),
                                        onAddRouteTap: () => _onAddRoute(child),
                                        activeRoutes: activeRoutes,
                                        boardRefreshKey: _boardRefreshKey,
                                      )
                                      .animate()
                                      .fade(duration: 600.ms)
                                      .slide(begin: const Offset(0, 0.1));
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

  void _onMQTTMessageReceived(String message) {
    try {
      final Map<String, dynamic> jsonMessage = jsonDecode(message);
      final Map<String, dynamic> data =
          jsonMessage['data'] as Map<String, dynamic>;
      final int? msgtype = data['msgtype'] as int?;

      if (msgtype == 2) {
        _handleOnboardMessage(data, jsonMessage);
      } else if (msgtype == 3) {
        _handleOffboardMessage(data, jsonMessage);
      } else if (msgtype == 1 || msgtype == 4) {
        _handleBusStatusMessage(msgtype, jsonMessage);
      } else {
        Logger().w('Unknown msgtype: $msgtype');
      }
    } catch (e) {
      Logger().e('Error parsing MQTT message: $e');
    }
    //on every notificaion it will be called
    widget.onNewMessage?.call();
  }

  void _handleOnboardMessage(
    Map<String, dynamic> data,
    Map<String, dynamic> jsonMessage,
  ) {
    final String? studentId = data['studentid'] as String?;
    final int status = data['status'] as int? ?? 1; // Default to onboard

    if (studentId != null) {
      _updateChildStatus(studentId, status, jsonMessage);
    } else {
      Logger().w('Missing studentid in onboard message');
    }
  }

  void _handleOffboardMessage(
    Map<String, dynamic> data,
    Map<String, dynamic> jsonMessage,
  ) {
    final List<dynamic>? offlist = data['offlist'] as List<dynamic>?;

    if (offlist != null) {
      for (var id in offlist) {
        if (id is String) {
          _updateChildStatus(id, 2, jsonMessage); // Offboard status
        }
      }
    } else {
      Logger().w('Missing offlist in offboard message');
    }
  }

  void _handleBusStatusMessage(int? msgtype, Map<String, dynamic> jsonMessage) {
    String devid = jsonMessage['devid'] ?? '';
    if (devid.isNotEmpty) {
      final provider = Provider.of<ChildrenProvider>(context, listen: false);
      final children = provider.children;
      setState(() {
        for (var child in children) {
          for (var route in child.routeInfo) {
            String key = '${route.routeId}_${route.oprId}';
            if (key == devid) {
              NotificationService.showNotification(
                id: 0,
                title: 'KT Status Update',
                body:
                    'Bus ${route.routeName} has been ${msgtype == 1 ? 'activated' : 'deactivated'}.',
              );
              if (msgtype == 1) {
                activeRoutes[key] = true;
              } else if (msgtype == 4) {
                activeRoutes[key] = false;
              }
            }
          }
        }
      });
    } else {
      Logger().w('Missing devid in bus active/inactive message');
    }
  }

  void _updateChildStatus(
    String studentId,
    int status,
    Map<String, dynamic> jsonMessage,
  ) {
    final provider = Provider.of<ChildrenProvider>(context, listen: false);
    final children = provider.children;
    final childIndex = children.indexWhere(
      (child) => child.studentId == studentId,
    );
    String onBoardLocation = "";
    String offBoardLocation = "";

    if (childIndex != -1) {
      // Show a notification
      NotificationService.showNotification(
        id: 0,
        title: 'KT Status Update',
        body:
            'Child ${children[childIndex].name} has been ${status == 1 ? 'onboarded' : 'offboarded'}.',
      );
      //set location base on jsonMessage['data']['msgtype']
      if (status == 1) {
        onBoardLocation = jsonMessage['data']['location'];
      } else if (status == 2) {
        offBoardLocation = jsonMessage['data']['location'];
      }
      //save to database
      _sqfliteHelper.insertActivity({
        'student_id': studentId,
        'student_name': children[childIndex].name,
        'status': status == 1 ? 'onboarded' : 'offboarded',
        'on_location': onBoardLocation,
        'off_location': offBoardLocation,
        'route_id': jsonMessage['devid'].split('_')[0],
        'oprid': jsonMessage['devid'].split('_')[1],
      });

      // Update the status of the child
      Logger().i('Updating status for child $studentId to $status');
      provider.updateChildOnboardStatus(studentId, status);
      //update the ActivityScreen after data insert in database
      provider.updateActivity();
      if (status == 1 || status == 2) {
        setState(() {
          _boardRefreshKey++;
        });
      }
      Logger().i('Updated status for child $studentId to $status');
    } else {
      Logger().w('Child with studentId $studentId not found');
    }
  }

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
  void _onSubscribe(Child child) async {
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

  void _onAddRoute(Child child) async {
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

  _onBusTap(String routeId, List<RouteInfo> routes) {
    // Implement bus tap action
    Logger().i('Bus tapped for route $routeId');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Bus tapped for route $routeId')));
    // Add your bus tap logic here
  }

  _onLocationTap(String routeId, List<RouteInfo> routes) async {
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

      final responseLocation = await ApiService.fetchOperationStatus(
        userId,
        oprId,
        sessionId,
      );
      Logger().i(responseLocation);

      //get stop_list from database
      final sqliteStopList = await _sqfliteHelper.getStopListByOprIdAndRouteId(
        oprId,
        routeId,
      );
      Logger().i('sqliteStopList: $sqliteStopList');

      final stopList = await _sqfliteHelper.getStopListByOprIdAndRouteId(
        oprId,
        routeId,
      );
      Logger().i('oprId: $oprId, routeId: $routeId, stopList: $stopList');
      //data of stop_list
      //use stopList and show the stop_name and location in a list
      final stopListMap = stopList.toList();
      Logger().i('stopListMap: $stopListMap');

      //open a  dialog and show the listed location in google map.
      // Parse stop_list data and show in dialog
      if (stopListMap.isNotEmpty && stopListMap[0]['stop_list'] != null) {
        final stopListJson = stopListMap[0]['stop_list'];
        if (stopListJson is String && stopListJson.isNotEmpty) {
          try {
            final List<dynamic> stopsData = jsonDecode(stopListJson);
            final List<StopLocation> stopLocations = stopsData.map((stopData) {
              return StopLocation.fromJson(stopData as Map<String, dynamic>);
            }).toList();

            final routeName = routes.first.routeName ?? 'Route $routeId';

            // Show the stop locations dialog
            showDialog(
              context: context,
              builder: (context) => StopLocationsDialog(
                stopLocations: stopLocations,
                routeName: routeName,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No stop locations available for this route'),
          ),
        );
      }

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

  _onDeleteTap(String routeId, List<RouteInfo> routes, String studentId) async {
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
    ApiService.deleteStudentRoute(studentId, oprId, sessonId!, userId!).then((
      response,
    ) async {
      if (response.statusCode == 200) {
        Logger().i(response.data);
        if (response.data[0]['result'] == 'ok') {
          if (response.data[1]['data'] == 'ok') {
            //Also remove from the database
            await _sqfliteHelper.deleteRouteInfoByStudentIdAndOprId(
              studentId,
              oprId,
            );
            // Refresh the children list to show updated data
            await Provider.of<ChildrenProvider>(
              context,
              listen: false,
            ).updateChildren();
            Provider.of<ChildrenProvider>(context, listen: false);
            // .removeChildOrRouteOprid("route", studentId);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Delete tapped for route $routeId')),
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
    final userId = await SharedPreferenceHelper.getUserNumber();
    final sessionId = await SharedPreferenceHelper.getUserSessionId();
    //get tsp id from database
    final kkmklk = await _sqfliteHelper.getChildTspId();
    Logger().i('kkmklk: $kkmklk');
    List<String> kkmklk2 = [];
    for (var item in kkmklk) {
      if (item.isNotEmpty) {
        try {
          List<dynamic> decoded = jsonDecode(item);
          kkmklk2.addAll(decoded.map((e) => e.toString()));
        } catch (e) {
          kkmklk2.add(item);
        }
      }
    }
    Logger().i('kkmklk2: $kkmklk2');
    for (var tspId in kkmklk2) {
      Logger().i('tspId: $tspId, userId: $userId, sessionId: $sessionId');
      ApiManager()
          .post(
            'kturoutelistbytsp',
            data: {'userid': userId, 'sessionid': sessionId, 'tsp_id': tspId},
          )
          .then((response) {
            Logger().i(response.data);
            if (response.data[0]['result'] == 'ok') {
              if (response.data[1]['data'] != null) {
                //save to database insertRoute
                for (var route in response.data[1]['data']) {
                  _sqfliteHelper.insertRoute(
                    route['oprid'],
                    route['route_id'],
                    route['timing'],
                    route['vehicle_id'],
                    route['route_name'],
                    route['type'],
                    route['stop_list'],
                    route['stop_details'],
                  );
                }
              }
            }
          });
    }
  }
}
