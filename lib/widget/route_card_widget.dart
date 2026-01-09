import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/model/route.dart';
import 'package:kiddo_tracker/routes/routes.dart';
import 'package:kiddo_tracker/services/children_provider.dart';
import 'package:kiddo_tracker/utils/in_range.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/web.dart';
import 'package:provider/provider.dart';

class RouteCardWidget extends StatefulWidget {
  final String childId;
  final String routeId;
  final List<RouteInfo> routes;
  final Function(String routeId, List<RouteInfo> routes)? onBusTap;
  final Function(String routeId, List<RouteInfo> routes)? onLocationTap;
  final Function(String routeId, List<RouteInfo> routes)? onDeleteTap;
  final Function(String routeId, List<RouteInfo> routes)? onOnboardTap;
  final Function(String routeId, List<RouteInfo> routes)? onOffboardTap;
  final int boardRefreshKey;

  const RouteCardWidget({
    super.key,
    required this.childId,
    required this.routeId,
    required this.routes,
    required this.onBusTap,
    required this.onLocationTap,
    required this.onDeleteTap,
    this.onOnboardTap,
    this.onOffboardTap,
    required this.boardRefreshKey,
  });

  @override
  State<RouteCardWidget> createState() => _RouteCardWidgetState();
}

class _RouteCardWidgetState extends State<RouteCardWidget> {
  String onboardTime = '_';
  String offboardTime = '_';
  String onLocation = '_';
  String offLocation = '_';
  String distanceToStop = '_';
  String distanceToSchool = '_';
  final SqfliteHelper _sqfliteHelper = SqfliteHelper();
  late ChildrenProvider _childrenProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _childrenProvider = Provider.of<ChildrenProvider>(context, listen: false);
      _childrenProvider.boardRefreshNotifier.addListener(_fetchActivityTimes);
    });
    _fetchActivityTimes();
  }

  @override
  void dispose() {
    _childrenProvider.boardRefreshNotifier.removeListener(_fetchActivityTimes);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RouteCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardRefreshKey != widget.boardRefreshKey) {
      _fetchActivityTimes();
    }
  }

  Future<void> _fetchActivityTimes() async {
    if (widget.routes.isNotEmpty) {
      final route = widget.routes.first;
      final times = await _sqfliteHelper.getActivityTimesForRoute(
        route.routeId,
        route.oprId.toString(),
        widget.childId,
      );
      Logger().d('Fetched activity times: $times');
      setState(() {
        final String? onboardMsg = times['onboard']?['message_time']
            ?.toString();
        final String? offboardMsg = times['offboard']?['message_time']
            ?.toString();

        onboardTime = onboardMsg != null ? _formatTime(onboardMsg) : '_';
        offboardTime = offboardMsg != null ? _formatTime(offboardMsg) : '_';
        onLocation = times['onboard']?['on_location']?.toString() ?? '_';
        offLocation = times['offboard']?['off_location']?.toString() ?? '_';
      });
      await _calculateDistances();
    }
  }

  double _bearingBetween(double lat1, double lng1, double lat2, double lng2) {
    final lat1Rad = lat1 * pi / 180;
    final lat2Rad = lat2 * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;

    final y = sin(dLng) * cos(lat2Rad);
    final x =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLng);

    double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  String _directionLabel({
    required double routeBearing,
    required double userBearing,
    required double distanceKm,
  }) {
    const double closeThresholdKm = 0.2; // 200 meters
    const double tolerance = 45; // degrees

    if (distanceKm <= closeThresholdKm) {
      return 'Close to';
    }

    double diff = (userBearing - routeBearing).abs();
    diff = diff > 180 ? 360 - diff : diff;

    if (diff <= tolerance) {
      return 'Forward';
    } else if (diff >= 180 - tolerance) {
      return 'Backward';
    } else {
      return 'Side';
    }
  }

  Future<void> _calculateDistances() async {
    if (widget.routes.isEmpty) return;

    final route = widget.routes.first;
    String stopLoc = route.stopLocation;
    String schoolLoc = route.schoolLocation;

    // Parse onLocation and offLocation as lat,lng
    double? onLat, onLng, offLat, offLng;
    if (onLocation != '_') {
      List<String> parts = onLocation.split(',');
      if (parts.length == 2) {
        onLat = double.tryParse(parts[0]);
        onLng = double.tryParse(parts[1]);
      }
    }
    if (offLocation != '_') {
      List<String> parts = offLocation.split(',');
      if (parts.length == 2) {
        offLat = double.tryParse(parts[0]);
        offLng = double.tryParse(parts[1]);
      }
    }

    // Geocode stopLocation and schoolLocation
    double? stopLat, stopLng, schoolLat, schoolLng;
    try {
      List<Location> stopLocations = await locationFromAddress(stopLoc);
      if (stopLocations.isNotEmpty) {
        stopLat = stopLocations.first.latitude;
        stopLng = stopLocations.first.longitude;
      }
    } catch (e) {
      Logger().e('Error geocoding stopLocation: $e');
    }
    try {
      List<Location> schoolLocations = await locationFromAddress(schoolLoc);
      if (schoolLocations.isNotEmpty) {
        schoolLat = schoolLocations.first.latitude;
        schoolLng = schoolLocations.first.longitude;
      }
    } catch (e) {
      Logger().e('Error geocoding schoolLocation: $e');
    }

    // Calculate distances
    String distToStop = '_';
    String distToSchool = '_';
    if (stopLat != null &&
        stopLng != null &&
        schoolLat != null &&
        schoolLng != null) {
      // Route direction: Stop -> School
      final routeBearing = _bearingBetween(
        stopLat,
        stopLng,
        schoolLat,
        schoolLng,
      );

      // Distance + direction to STOP (onLocation)
      if (onLat != null && onLng != null) {
        final distanceKm =
            Geolocator.distanceBetween(stopLat, stopLng, onLat, onLng) / 1000;

        final userBearing = _bearingBetween(stopLat, stopLng, onLat, onLng);

        final relation = _directionLabel(
          routeBearing: routeBearing,
          userBearing: userBearing,
          distanceKm: distanceKm,
        );
        distToStop = '${distanceKm.toStringAsFixed(2)} km ($relation)';
      }
      if (offLat != null && offLng != null) {
        final distanceKm =
            Geolocator.distanceBetween(schoolLat, schoolLng, offLat, offLng) /
            1000;

        final userBearing = _bearingBetween(stopLat, stopLng, offLat, offLng);

        final relation = _directionLabel(
          routeBearing: routeBearing,
          userBearing: userBearing,
          distanceKm: distanceKm,
        );

        distToSchool = '${distanceKm.toStringAsFixed(2)} km ($relation)';
      }
    }
    // if (stopLat != null && stopLng != null && onLat != null && onLng != null) {
    //   double distance =
    //       Geolocator.distanceBetween(stopLat, stopLng, onLat, onLng) /
    //       1000; // km
    //   distToStop = '${distance.toStringAsFixed(2)} km';
    // }
    // if (schoolLat != null &&
    //     schoolLng != null &&
    //     offLat != null &&
    //     offLng != null) {
    //   double distance =
    //       Geolocator.distanceBetween(schoolLat, schoolLng, offLat, offLng) /
    //       1000; // km
    //   distToSchool = '${distance.toStringAsFixed(2)} km';
    // }
    setState(() {
      distanceToStop = distToStop;
      distanceToSchool = distToSchool;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Find earliest stopArrivalTime for route start time
    String startTime = '';
    if (widget.routes.isNotEmpty) {
      widget.routes.sort(
        (a, b) => a.stopArrivalTime.compareTo(b.stopArrivalTime),
      );
      startTime = widget.routes.first.startTime;
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ValueListenableBuilder<Map<String, bool>>(
                        valueListenable: Provider.of<ChildrenProvider>(
                          context,
                          listen: false,
                        ).activeRoutesNotifier,
                        builder: (context, activeRoutes, child) {
                          final color = _getBusIconColor(activeRoutes);
                          return InkWell(
                            onTap:
                                // color == Colors.green &&
                                widget.onBusTap != null
                                ? () => widget.onBusTap!(
                                    widget.routeId,
                                    widget.routes,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              margin: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Icon(
                                Icons.directions_bus_outlined,
                                size: 25,
                                color: color,
                              ),
                            ),
                          );
                        },
                      ),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Column(
                          children: [
                            Text(
                              '${widget.routes.first.routeName} starts at ${widget.routes.first.stopArrivalTime}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            //display stop location arrival time
                            Text(
                              'Stop Arrival Time: $startTime',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey,
                              ),
                            ),
                            // const SizedBox(height: 4),
                            // Text(
                            //   'Home: ${widget.routes.first.stopLocation}',
                            //   style: const TextStyle(
                            //     fontSize: 12,
                            //     fontWeight: FontWeight.w400,
                            //     color: Colors.grey,
                            //   ),
                            // ),
                            // Text(
                            //   'School: ${widget.routes.first.schoolLocation}',
                            //   style: const TextStyle(
                            //     fontSize: 12,
                            //     fontWeight: FontWeight.w400,
                            //     color: Colors.grey,
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () =>
                        widget.onOnboardTap!(widget.routeId, widget.routes),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.login,
                                size: 18,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                onboardTime == '_'
                                    ? " "
                                    : '(At $onboardTime, \n$distanceToStop)',
                                // '(At $onboardTime, \n$distanceToStop)',
                                // '($onLocation at $onboardTime, \n$distanceToStop)',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: widget.onOffboardTap != null
                        ? () => widget.onOffboardTap!(
                            widget.routeId,
                            widget.routes,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout,
                            size: 18,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            offboardTime == '_'
                                ? " "
                                : '(At $offboardTime, \n$distanceToSchool)',
                            // '($offLocation at $offboardTime, \n$distanceToSchool)',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Column(
              children: [
                //onTap show stopage by routeId and oprId
                //show the list in dialog box and show previous selected stopage and on change change the stopage and a save button
                //on save update the stopage in database
                InkWell(
                  onTap: _showStopageDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        87,
                        68,
                        255,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.route_outlined,
                      size: 15,
                      color: const Color.fromARGB(255, 87, 68, 255),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                InkWell(
                  onTap: widget.onLocationTap != null
                      ? () =>
                            widget.onLocationTap!(widget.routeId, widget.routes)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.share_location_outlined,
                      size: 15,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                InkWell(
                  onTap: widget.onDeleteTap != null
                      ? () => widget.onDeleteTap!(widget.routeId, widget.routes)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete,
                      size: 15,
                      color: Color.fromARGB(255, 255, 136, 127),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                //title holiday icon and on click show holiday details of current route id.
                InkWell(
                  onTap: () {
                    //get oprid and route id
                    String oprId = widget.routes.first.oprId.toString();
                    String routeId = widget.routes.first.routeId;
                    Logger().d(
                      'Holiday icon tapped for oprId: $oprId, routeId: $routeId',
                    );
                    //navigate to RequestLeaveScreen and pass oprId and routeId
                    Navigator.push(
                      context,
                      AppRoutes.generateRoute(
                        RouteSettings(
                          name: AppRoutes.requestLeave,
                          arguments: {
                            'oprId': oprId,
                            'routeId': routeId,
                            'childId': widget.childId,
                            'childName': Provider.of<ChildrenProvider>(
                              context,
                              listen: false,
                            ).getChildNameById(widget.childId),
                          },
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.holiday_village,
                      size: 15,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 600.ms).slide(begin: const Offset(0, 0.1));
  }

  String _formatTime(String createdAt) {
    //convert the timestamp to local time
    try {
      int millis = int.parse(createdAt);
      DateTime localDateTime = DateTime.fromMillisecondsSinceEpoch(
        millis,
        isUtc: true,
      ).toLocal();
      return DateFormat("hh:mm a").format(localDateTime);
      // return DateFormat("MMM dd, yyyy 'at' hh:mm a").format(localDateTime);
    } catch (e) {
      return createdAt;
    }
  }

  Future<void> _showStopageDialog() async {
    if (widget.routes.isEmpty) return;

    final route = widget.routes.first;
    //print the data of route
    Logger().d('Selected Route: ${route.toJson()}');
    String? selectedStopId = route.stopId.toString();
    String? selectedGeoLocation;
    String? selectedStopName;
    String? selectedTime;
    Logger().d(
      'Fetching stopages for oprId: ${route.oprId}, routeId: ${route.routeId}, stopId: ${route.stopId}',
    );
    final stopagesData = await _sqfliteHelper.getStopDetailsByOprIdAndRouteId(
      route.oprId.toString(),
      route.routeId,
    );
    Logger().d('Stopages Data: ${stopagesData.toString()}');
    final stopListStr = stopagesData['stopListStr'] as String?;
    List<Map<String, dynamic>> stopages = [];
    if (stopListStr != null) {
      final decoded = jsonDecode(stopListStr);
      if (decoded is List) {
        stopages = List<Map<String, dynamic>>.from(decoded);
        Logger().d('Decoded Stopages: $stopages');
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Select Stopage for ${route.routeName}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: stopages.length,
              itemBuilder: (context, index) {
                final stopage = stopages[index];
                //print all the stopage details
                Logger().d('Stopage: $stopage');
                // final isSelected = stopage['stop_id'] == selectedStopId;
                Logger().d('Comparing route stopId: ${stopage['key']}');
                //compare with stopage['key'] or stopage['stop_id']
                final isSelected =
                    (stopage['stop_id'] ?? stopage['key'] ?? '') ==
                    selectedStopId;
                Logger().d('isSelected: $isSelected');
                return Card(
                  color: isSelected ? Colors.blue.shade100 : null,
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on,
                      color: isSelected ? Colors.blue : Colors.grey,
                    ),
                    title: Text(stopage['value'] ?? stopage['stop_name'] ?? ''),
                    // title: Text(stopage['value'] ?? ''),
                    subtitle: Text(stopage['location'] ?? ''),
                    trailing: Text(stopage['time'] ?? ''),
                    onTap: () {
                      setState(() {
                        selectedStopId =
                            stopage['stop_id'] ?? stopage['key'] ?? '';
                        selectedGeoLocation = stopage['location'] ?? '';
                        selectedStopName =
                            stopage['value'] ?? stopage['stop_name'] ?? '';
                        selectedTime = stopage['time'] ?? '';
                        Logger().d('Selected StopId: $selectedStopId');
                        Logger().d('Selected StopId: $selectedGeoLocation');
                        Logger().d('Selected StopId: $selectedTime');
                      });
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  selectedStopId != null && selectedStopId != route.stopId
                  ? () async {
                      //use array of object and show list of stopages with stop_id, stop_name, location, time
                      List<Map<String, String>> routeData = [
                        {
                          'route_id': route.routeId,
                          'route_name': route.routeName,
                          'oprid': route.oprId.toString(),
                          'type': route.routeType.toString(),
                          'vehicle_id': route.vehicleId,
                          'stop_id': selectedStopId!,
                          'stop_name': selectedStopName ?? '',
                          'location': selectedGeoLocation ?? '',
                          'stop_arrival_time': selectedTime ?? '',
                        },
                      ];
                      Logger().d('Route Data for Update: $routeData');
                      String studentId = widget.childId;
                      String userId =
                          (await SharedPreferenceHelper.getUserNumber())!;
                      String sessionId =
                          (await SharedPreferenceHelper.getUserSessionId())!;
                      Logger().d(
                        'Updating stopage for StudentId: $studentId, UserId: $userId, SessionId: $sessionId',
                      );
                      // Update the stopage in database
                      await _updateStopage(
                        selectedStopId!,
                        selectedTime!,
                        userId,
                        sessionId,
                        routeData,
                        route,
                      );
                      Navigator.of(context).pop();
                      // Refresh the widget
                      setState(() {});
                    }
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStopage(
    String newStopId,
    String newStopTime,
    String userId,
    String sessionId,
    List<Map<String, String>> routeData,
    RouteInfo route,
  ) async {
    try {
      //call the api to update the stopage
      Logger().d('Updating stopage with data: $routeData');
      Logger().d(
        'API Call with userid: $userId, sessionid: $sessionId, student_id: ${widget.childId}, route_info: ${routeData.toString()}',
      );
      ApiService.updateStudentRoute(
        userId,
        sessionId,
        widget.childId,
        routeData.toString(),
      ).then((response) async {
        if (response.statusCode == 200) {
          Logger().d('API Response: $response');
          if ((response.data[0]['result'] == 'ok')) {
            Logger().d('Stopage updated successfully on server.');
            // Update the stopage in local database
            await _sqfliteHelper.updateChildRouteStopage(
              widget.childId,
              route.routeId,
              routeData[0],
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Stopage updated successfully')),
            );
          } else {
            Logger().e(
              'Failed to update stopage. Server response: ${response.data}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to update stopage: ${response.data[0]['result']}',
                ),
              ),
            );
          }
        } else {
          Logger().e(
            'Failed to update stopage. Status code: ${response.statusCode}, Response data: ${response.data}',
          );
        }
      });
      // final response = await ApiManager().post(
      //   'ktuserupdateroute',
      //   data: {
      //     'userid': userId,
      //     'sessionid': sessionId,
      //     'student_id': widget.childId.toString(),
      //     'route_info': routeData,
      //   },
      // );
      //if ok update the stopage in local database
    } catch (e) {
      Logger().e('Error updating stopage: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating stopage: $e')));
    }
  }

  Color _getBusIconColor(Map<String, bool> activeRoutes) {
    // Check if any route in the list is active
    for (var route in widget.routes) {
      String key = '${route.routeId}_${route.oprId}';
      if (activeRoutes[key] == true) {
        return Colors.green; // Active
      }
    }
    return Colors.red; // Inactive or default
  }
}
