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
    try {
      final userId = await SharedPreferenceHelper.getUserNumber();
      final sessionId = await SharedPreferenceHelper.getUserSessionId();
      final tspList = await _sqfliteHelper.getChildTspId();
      Logger().i('Child TSP List: $tspList');

      for (var tsp in tspList) {
        final tspId = tsp['tsp_id'];

        /// Extract oprid + route_id pairs from local DB
        final routeIds = <String>{};
        final oprIds = <String>{};
        _extractLocalRoutePairs(tsp['routes'], routeIds, oprIds);

        /// Fetch Remote Route List From API
        await _fetchAndProcessTspRoute(
          tspId: tspId,
          userId: userId,
          sessionId: sessionId,
          routeIds: routeIds,
          oprIds: oprIds,
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
  }) async {
    try {
      final response = await ApiManager().post(
        'kturoutelistbytsp',
        data: {'userid': userId, 'sessionid': sessionId, 'tsp_id': tspId},
      );

      if (response.statusCode != 200 || response.data[0]['result'] != 'ok') {
        Logger().w('Invalid response for tspId: $tspId');
        return;
      }

      final apiRoutes = response.data[1]['data'];

      for (var route in apiRoutes) {
        final oprid = route['oprid'];
        final routeId = route['route_id'];

        Logger().i("API Route → oprid: $oprid | route_id: $routeId");

        /// Only insert & update matching oprid + route_id
        final isMatch = oprIds.contains(oprid) && routeIds.contains(routeId);

        if (isMatch) {
          Logger().i("MATCHED → Saving oprid: $oprid | route_id: $routeId");
          await _saveRouteToDatabase(route);
          await _updateChildrenRouteInfo(route);
        } else {
          Logger().i("SKIPPED → oprid: $oprid | route_id: $routeId");
        }
      }
    } catch (e) {
      Logger().e('Error fetching route storage for tspId $tspId: $e');
    }
  }
  //
  Future<void> _updateChildrenRouteInfo(Map<String, dynamic> route) async {
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
        if (!tspIdList.contains(route['oprid'].toString())) continue;

        /// Decode route info
        final decoded = jsonDecode(routeInfoRaw);
        final List<RouteInfo> routeInfos = decoded
            .map<RouteInfo>((e) => RouteInfo.fromJson(e is String ? jsonDecode(e) : e))
            .toList();

        bool updated = false;

        for (var info in routeInfos) {
          if (info.oprId == route['oprid'].toString() &&
              info.routeId == route['route_id'].toString()) {
                String? lastStopLocation = _extractLastStopLocation(route['stop_list']);
            final updatedInfo = RouteInfo(
              routeId: info.routeId,
              routeName: info.routeName,
              routeType: info.routeType,
              startTime: route['timing'],
              stopArrivalTime: info.stopArrivalTime,
              stopName: info.stopName,
              stopLocation: info.stopLocation,
              //"stop_list": "[{\"stop_id\":\"1\",\"stop_name\":\"Mumbai\",\"location\":\"18.9581934,72.8320729\",\"stop_type\":1},{\"stop_id\":\"2\",\"stop_name\":\"Goa\",\"location\":\"15.30106506,74.13523982\",\"stop_type\":3}]"
              //get the last stop location from stop_list
              schoolLocation: lastStopLocation ?? '',
              oprId: info.oprId,
              vehicleId: info.vehicleId,
              stopId: info.stopId,
            );

            routeInfos[routeInfos.indexOf(info)] = updatedInfo;
            updated = true;
            break;
          }
        }

        if (updated) {
          final updatedJson = jsonEncode(routeInfos.map((e) => e.toJson()).toList());
          await _sqfliteHelper.updateRouteInfoByStudentId(studentId, updatedJson);

          Logger().i('Updated child route_info → studentId: $studentId');
        }
      } catch (e) {
        Logger().e('Error updating child route_info: $e');
      }
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
    await _sqfliteHelper.insertRoute(
      route['oprid'],
      route['route_id'],
      route['timing'],
      route['vehicle_id'],
      route['route_name'],
      route['type'],
      route['stop_list'],
      route['stop_details'],
    );

    Logger().i('Inserted Route → ${route['route_id']} | oprid: ${route['oprid']}');
  }
  //
  void _extractLocalRoutePairs(List<dynamic> routes, Set<String> routeIds, Set<String> oprIds) {
    for (var route in routes) {
      routeIds.add(route['route_id']);
      oprIds.add(route['oprid']);
      Logger().i('Local route → oprid: ${route['oprid']} | route_id: ${route['route_id']}');
    }
  }

  //     //run loop for i['routes'] to get oprid and route_id
  //     for (var route in i['routes']) {
  //       Logger().i('oprid: ${route['oprid']}, route_id: ${route['route_id']}');
  //       //store the route_id and oprid
  //       listRouteId.add(route['route_id']);
  //       listOprid.add(route['oprid']);
  //     }
  //     //fetch route storage from api
  //     ApiManager()
  //         .post(
  //           'kturoutelistbytsp',
  //           data: {'userid': userId, 'sessionid': sessionId, 'tsp_id': tspId},
  //         )
  //         .then((response) {
  //           if (response.statusCode == 200) {
  //             Logger().i(response.data);
  //             if (response.data[0]['result'] == 'ok') {
  //               //my oprid and route_id
  //               for (var j = 0; j < listOprid.length; j++) {
  //                 Logger().i(
  //                   'Matching oprid: ${listOprid[j]}, route_id: ${listRouteId[j]}',
  //                   /* output
  //                   Matching oprid: 1, route_id: OD94689000001
  //                   */
  //                 );
  //               }
  //               // for loop the response.data[1]['data'] to match oprid and route_id
  //               for (var route in response.data[1]['data']) {
  //                 Logger().i('djgbdssdfdsdfg: ${route['oprid']} xdgxdfgdxfgdx ${route['route_id']}');

  //                 //now match my oprid and route_id with the route['oprid'] and route['route_id']
  //                  if (listOprid.contains(route['oprid']) &&
  //                     listRouteId.contains(route['route_id'])) {
  //                   Logger().i(
  //                     'Load the Data oprid: ${route['oprid']}, route_id: ${route['route_id']}',
  //                   );
  //                   //save to database insertRoute
  //                   _sqfliteHelper.insertRoute(
  //                     route['oprid'],
  //                     route['route_id'],
  //                     route['timing'],
  //                     route['vehicle_id'],
  //                     route['route_name'],
  //                     route['type'],
  //                     route['stop_list'],
  //                     route['stop_details'],
  //                   );

  //                   // Update route_info's school_location and start_time fields from route data for matching children
  //                   final childrenList = await _sqfliteHelper.getChildren();
  //                   for (var childMap in childrenList) {
  //                     try {
  //                       final studentId = childMap['student_id'] as String?;
  //                       final tspIdRaw = childMap['tsp_id'] as String?;
  //                       final routeInfoRaw = childMap['route_info'] as String?;
  //                       if (studentId == null || tspIdRaw == null || routeInfoRaw == null) {
  //                         continue;
  //                       }
  //                       final List<dynamic> tspIdList = jsonDecode(tspIdRaw);
  //                       if (!tspIdList.contains(route['oprid'].toString())) {
  //                         continue; // skip if child's tsp_id list does not contain this oprid
  //                       }
  //                       // Decode routeInfo list
  //                       List<dynamic> routeInfoListRaw = jsonDecode(routeInfoRaw);
  //                       List<RouteInfo> routeInfoList = routeInfoListRaw
  //                           .map<RouteInfo>((e) => RouteInfo.fromJson(e is String ? jsonDecode(e) : e))
  //                           .toList();

  //                       bool updated = false;
  //                       for (var routeInfo in routeInfoList) {
  //                         if (routeInfo.oprId == route['oprid'].toString() &&
  //                             routeInfo.routeId == route['route_id'].toString()) {
  //                           routeInfoList[routeInfoList.indexOf(routeInfo)] = RouteInfo(
  //                             routeId: routeInfo.routeId,
  //                             routeName: routeInfo.routeName,
  //                             routeType: routeInfo.routeType,
  //                             startTime: route['timing'].toString(),
  //                             stopArrivalTime: routeInfo.stopArrivalTime,
  //                             stopName: routeInfo.stopName,
  //                             stopLocation: routeInfo.stopLocation,
  //                             schoolLocation: route['stop_details'].toString(),
  //                             oprId: routeInfo.oprId,
  //                             vehicleId: routeInfo.vehicleId,
  //                             stopId: routeInfo.stopId,
  //                           );
  //                           updated = true;
  //                           break;
  //                         }
  //                       }
  //                       if (updated) {
  //                         final String updatedRouteInfoStr =
  //                             jsonEncode(routeInfoList.map((e) => e.toJson()).toList());
  //                         await _sqfliteHelper.updateRouteInfoByStudentId(studentId, updatedRouteInfoStr);
  //                         Logger().i('Updated route_info school_location and start_time for studentId: $studentId');
  //                       }
  //                     } catch (e) {
  //                       Logger().e('Error updating route_info fields for route ${route['route_id']}: $e');
  //                     }
  //                   }


  //                 } else {
  //                   Logger().i(
  //                     'Skip the Data oprid: ${route['oprid']}, route_id: ${route['route_id']}',
  //                   );
  //                 }

  //                 // _sqfliteHelper.insertRoute(
  //                 //   route['oprid'],
  //                 //   route['route_id'],
  //                 //   route['timing'],
  //                 //   route['vehicle_id'],
  //                 //   route['route_name'],
  //                 //   route['type'],
  //                 //   route['stop_list'],
  //                 //   route['stop_details'],
  //                 // );
  //                 // //print to console
  //                 // Logger().i(
  //                 //   'Inserted route: oprid=${route['oprid']}, route_id=${route['route_id']}, route_name=${route['route_name']}, type=${route['type']}, timing=${route['timing']}, vehicle_id=${route['vehicle_id']}, stop_list=${route['stop_list']}, stop_details=${route['stop_details']}',
  //                 // );
  //               }
  //               // if (response.data[1]['data'] != null) {
  //               //   //save to database insertRoute
  //               //   for (var routes in response.data[1]['data']) {
  //               //     //match oprid and route_id before insert
  //               //     if (routes['oprid'] != route['oprid'] ||
  //               //         routes['route_id'] != route['route_id']) {
  //               //       continue;
  //               //     }
  //               //     _sqfliteHelper.insertRoute(
  //               //       routes['oprid'],
  //               //       routes['route_id'],
  //               //       routes['timing'],
  //               //       routes['vehicle_id'],
  //               //       routes['route_name'],
  //               //       routes['type'],
  //               //       routes['stop_list'],
  //               //       routes['stop_details'],
  //               //     );
  //               //     //print to console
  //               //     Logger().i(
  //               //       'Inserted route: oprid=${routes['oprid']}, route_id=${routes['route_id']}, route_name=${routes['route_name']}, type=${routes['type']}, timing=${routes['timing']}, vehicle_id=${routes['vehicle_id']}, stop_list=${routes['stop_list']}, stop_details=${routes['stop_details']}',
  //               //     );
  //               //   }
  //               // }
  //             }
  //           }
  //         })
  //         .catchError((error) {
  //           Logger().e('Error fetching route storage for tspId $tspId: $error');
  //         });
  //   }
  // }
}
