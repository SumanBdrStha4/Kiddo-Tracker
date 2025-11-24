import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kiddo_tracker/api/apimanage.dart';
import 'package:kiddo_tracker/api/route_search_callback.dart';
import 'package:kiddo_tracker/model/route.dart';
import 'package:kiddo_tracker/model/routelist.dart';
import 'package:kiddo_tracker/services/children_provider.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

class AddChildRoutePage extends StatefulWidget {
  String? nickName;
  String? stdId;
  AddChildRoutePage({super.key, this.stdId, this.nickName});
  @override
  _AddChildRoutePageState createState() => _AddChildRoutePageState();
}

class _AddChildRoutePageState extends State<AddChildRoutePage> {
  int _selectedTripType = 1; // 1 for One Way, 2 for Round Way
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _instituteController = TextEditingController();
  IconData _searchIcon = Icons.search;

  String? _userId;
  String? _sessionId;
  List<dynamic>? _institutes = [];
  List<dynamic>? _tspList = [];
  String? _selectedInstitute;
  int? _selectedSchool;

  final List<RouteList> _routes = [];
  List<String> _times = [];
  List<Map<String, String?>> _stopages = [];

  String? _selectedRoute;
  String? _selectedRouteName;
  int? _selectedRouteType;
  String? _selectedRouteId;
  String? _selectedTime;
  String? _selectedorpId;
  String? _selectedStopage;
  String? _selectedStopageName;
  String? _selectedHomeGeo;
  String? _schoolStopGeo;
  String? _selectedStopAriveTime;
  String? _stopageId;
  String? _vehicleId;
  //for round way store multi routes
  final List<String> _selectedRoundRoutes = [];

  // Onward variables for round trip
  String? _onwardRoute;
  String? _onwardRouteName;
  int? _onwardRouteType = 1;
  String? _onwardRouteId;
  String? _onwardTime;
  String? _onwardorpId;
  String? _onwardStopage;
  String? _onwardStopageName;
  String? _onwardHomeGeo;
  String? _onwardSchoolStopGeo;
  String? _onwardStopAriveTime;
  String? _onwardStopageId;
  String? _onwardVehicleId;
  List<String> _onwardTimes = [];
  List<Map<String, String?>> _onwardStopages = [];

  // Return variables for round trip
  String? _returnRoute;
  String? _returnRouteName;
  int? _returnRouteType = 2;
  String? _returnRouteId;
  String? _returnTime;
  String? _returnorpId;
  String? _returnStopage;
  String? _returnStopageName;
  String? _returnHomeGeo;
  String? _returnSchoolStopGeo;
  String? _returnStopAriveTime;
  String? _returnStopageId;
  String? _returnVehicleId;
  List<String> _returnTimes = [];
  List<Map<String, String?>> _returnStopages = [];
  //callback
  RouteSearchCallback callback = RouteSearchCallback();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _instituteController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedTripType == 1) {
        // One Way
        Logger().i(
          'userid: $_userId, sessionid: $_sessionId, student_id: ${widget.stdId}, tsp_id: $_selectedInstitute, Route_id: $_selectedRouteId, route_name: $_selectedRouteName, stop_arrival_time: $_selectedTime, stop_name: $_selectedStopageName, oprid: $_selectedorpId, vehicle_id: $_vehicleId, stop_id: $_stopageId',
        );
        // call api to save the route
        ApiManager()
            .post(
              'ktuassignstdtoroute',
              data: {
                'userid': _userId,
                'sessionid': _sessionId,
                'student_id': widget.stdId,
                'route_id': _selectedRouteId,
                'route_name': _selectedRouteName,
                'oprid': _selectedorpId,
                'vehicle_id': _vehicleId,
                'stop_id': _stopageId,
                'location': _selectedHomeGeo,
                'stop_name': _selectedStopageName,
                'stop_arrival_time': _selectedTime,
                'tsp_id': _selectedInstitute,
              },
            )
            .then((response) async {
              if (response.statusCode == 200) {
                Logger().i(response.data);
                if (response.data[0]['result'] == 'ok') {
                  if (response.data[1]['data'] == 'ok') {
                    await _saveRouteToDb(
                      RouteInfo(
                        routeId: _selectedRouteId ?? '',
                        routeType: _selectedRouteType ?? 0,
                        routeName: _selectedRouteName ?? '',
                        startTime: _selectedStopAriveTime ?? '',
                        stopArrivalTime: _selectedTime ?? '',
                        stopName: _selectedStopageName ?? '',
                        stopLocation: _selectedHomeGeo ?? '',
                        schoolLocation: _schoolStopGeo ?? '',
                        oprId: _selectedorpId ?? '',
                        vehicleId: _vehicleId ?? '',
                        stopId: _stopageId ?? '',
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${response.data[1]['data']}'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Data not saved."),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            });
      } else {
        // Round Trip
        Logger().i(
          'Round Trip - Onward: userid: $_userId, sessionid: $_sessionId, student_id: ${widget.stdId}, tsp_id: $_selectedInstitute, Route_id: $_onwardRouteId, route_name: $_onwardRouteName, stop_arrival_time: $_onwardTime, stop_name: $_onwardStopageName, oprid: $_onwardorpId, vehicle_id: $_onwardVehicleId, stop_id: $_onwardStopageId',
        );
        Logger().i(
          'Round Trip - Return: userid: $_userId, sessionid: $_sessionId, student_id: ${widget.stdId}, tsp_id: $_selectedInstitute, Route_id: $_returnRouteId, route_name: $_returnRouteName, stop_arrival_time: $_returnTime, stop_name: $_returnStopageName, oprid: $_returnorpId, vehicle_id: $_returnVehicleId, stop_id: $_returnStopageId',
        );
        // Save onward route
        ApiManager()
            .post(
              'ktuassignstdtoroute',
              data: {
                'userid': _userId,
                'sessionid': _sessionId,
                'student_id': widget.stdId,
                'route_id': _onwardRouteId,
                'route_name': _onwardRouteName,
                'oprid': _onwardorpId,
                'vehicle_id': _onwardVehicleId,
                'stop_id': _onwardStopageId,
                'location': _onwardHomeGeo,
                'stop_name': _onwardStopageName,
                'stop_arrival_time': _onwardTime,
                'tsp_id': _selectedInstitute,
              },
            )
            .then((response) async {
              if (response.statusCode == 200) {
                Logger().i('Onward response: ${response.data}');
                if (response.data[0]['result'] == 'ok') {
                  if (response.data[1]['data'] == 'ok') {
                    await _saveRouteToDb(
                      RouteInfo(
                        routeId: _onwardRouteId ?? '',
                        routeType: _onwardRouteType ?? 0,
                        routeName: _onwardRouteName ?? '',
                        startTime: _onwardStopAriveTime ?? '',
                        stopArrivalTime: _onwardTime ?? '',
                        stopName: _onwardStopageName ?? '',
                        stopLocation: _onwardHomeGeo ?? '',
                        schoolLocation: _onwardSchoolStopGeo ?? '',
                        oprId: _onwardorpId ?? '',
                        vehicleId: _onwardVehicleId ?? '',
                        stopId: _onwardStopageId ?? '',
                      ),
                    );
                    // Now save return route
                    ApiManager()
                        .post(
                          'ktuassignstdtoroute',
                          data: {
                            'userid': _userId,
                            'sessionid': _sessionId,
                            'student_id': widget.stdId,
                            'route_id': _returnRouteId,
                            'route_name': _returnRouteName,
                            'oprid': _returnorpId,
                            'vehicle_id': _returnVehicleId,
                            'stop_id': _returnStopageId,
                            'location': _returnHomeGeo,
                            'stop_name': _returnStopageName,
                            'stop_arrival_time': _returnTime,
                            'tsp_id': _selectedInstitute,
                          },
                        )
                        .then((response2) async {
                          if (response2.statusCode == 200) {
                            Logger().i('Return response: ${response2.data}');
                            if (response2.data[0]['result'] == 'ok') {
                              if (response2.data[1]['data'] == 'ok') {
                                await _saveRouteToDb(
                                  RouteInfo(
                                    routeId: _returnRouteId ?? '',
                                    routeType: _returnRouteType ?? 0,
                                    routeName: _returnRouteName ?? '',
                                    startTime: _returnStopAriveTime ?? '',
                                    stopArrivalTime: _returnTime ?? '',
                                    stopName: _returnStopageName ?? '',
                                    stopLocation: _returnHomeGeo ?? '',
                                    schoolLocation: _returnSchoolStopGeo ?? '',
                                    oprId: _returnorpId ?? '',
                                    vehicleId: _returnVehicleId ?? '',
                                    stopId: _returnStopageId ?? '',
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error saving return route: ${response2.data[1]['data']}',
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Return route data not saved."),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error saving onward route: ${response.data[1]['data']}',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Onward route data not saved."),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fix the errors in red'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _saveRouteToDb(RouteInfo routeInfo) async {
    if (widget.stdId != null) {
      final sqfliteHelper = SqfliteHelper();
      // Get existing routes
      final existingRouteStr = await sqfliteHelper.getRouteInfoByStudentId(
        widget.stdId!,
      );
      List<RouteInfo> routeList = [];
      if (existingRouteStr != null && existingRouteStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(existingRouteStr);
          if (decoded is List) {
            routeList = decoded
                .map<RouteInfo>(
                  (e) => RouteInfo.fromJson(
                    e is String ? jsonDecode(e) : e as Map<String, dynamic>,
                  ),
                )
                .toList();
          }
        } catch (e) {
          Logger().e('Error decoding existing routes: $e');
        }
      }
      // Add new route to db
      routeList.add(routeInfo);
      // make the routeList inside String
      Logger().i(routeList.map((e) => e.toJson()).toList());
      final newRoute = jsonEncode(routeList.map((e) => e.toJson()).toList());
      Logger().i(newRoute);
      await sqfliteHelper.updateRouteInfoByStudentId(widget.stdId!, newRoute);
      final provider = Provider.of<ChildrenProvider>(context, listen: false);
      await provider.updateChildren();
      await provider.subscribeToTopics();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("New Route Added Successfully."),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Handle the case when widget.stdId is null
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: widget.stdId is null'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildRouteDropdown(
    ColorScheme colorScheme, [
    String type = 'single',
  ]) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Route Name',
        prefixIcon: Icon(Icons.route, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      value: type == 'single'
          ? _selectedRoute
          : (type == 'onward' ? _onwardRoute : _returnRoute),
      items: _routes
          //if type is single then show all routes
          //if type is onward then show only onward routes
          //if type is return then show only return routes
          .where(
            (r) => type == 'single'
                ? true
                : (type == 'onward' ? r.type == 1 : r.type == 2),
          )
          .map(
            (r) => DropdownMenuItem<String>(
              value:
                  "${r.routeName ?? r.routeId} ${r.type == 1 ? "OnWard" : "Return"}",
              child: Text(
                "${r.routeName ?? r.routeId} ${r.type == 1 ? "OnWard" : "Return"}",
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          if (type == 'single') {
            _selectedRoute = value;
            if (value != null) {
              try {
                var selectedRoute = _routes.firstWhere((r) {
                  String display =
                      "${r.routeName ?? r.routeId} ${r.type == 1 ? "OnWard" : "Return"}";
                  return display == value;
                });
                _selectedRouteName = selectedRoute.routeName;
                Logger().i(selectedRoute.toJson());
                _selectedRouteId = selectedRoute.routeId;
                _selectedRouteType = selectedRoute.type;
                _times = callback.getRouteTimings(
                  _selectedRouteId,
                  _selectedRouteType,
                );
                //use getStopList from callback to get stopages
                _stopages = callback.getStopList(_selectedRouteId!);
              } catch (e) {
                _selectedRouteId = null;
                _selectedRouteType = null;
                _times = [];
                _stopages = [];
              }
            } else {
              _selectedRouteId = null;
              _selectedRouteType = null;
              _times = [];
              _stopages = [];
            }
            _selectedTime = null;
            _selectedStopage = null;
            _selectedHomeGeo = null;
            _schoolStopGeo = null;
            _selectedStopAriveTime = null;
            _selectedStopageName = null;
          } else if (type == 'onward') {
            _onwardRoute = value;
            if (value != null) {
              try {
                var selectedRoute = _routes.firstWhere((r) {
                  String display =
                      "${r.routeName ?? r.routeId} ${r.type == 1 ? "OnWard" : "Return"}";
                  return display == value;
                });
                _onwardRouteName = selectedRoute.routeName;
                Logger().i(selectedRoute.toJson());
                _onwardRouteId = selectedRoute.routeId;
                _onwardRouteType = selectedRoute.type;
                _onwardTimes = callback.getRouteTimings(
                  _onwardRouteId,
                  _onwardRouteType,
                );
                //use getStopList from callback to get stopages
                _onwardStopages = callback.getStopList(_onwardRouteId!);
              } catch (e) {
                _onwardRouteId = null;
                _onwardRouteType = null;
                _onwardTimes = [];
                _onwardStopages = [];
              }
            } else {
              _onwardRouteId = null;
              _onwardRouteType = null;
              _onwardTimes = [];
              _onwardStopages = [];
            }
            _onwardTime = null;
            _onwardStopage = null;
            _onwardHomeGeo = null;
            _onwardSchoolStopGeo = null;
            _onwardStopAriveTime = null;
            _onwardStopageName = null;
          } else {
            _returnRoute = value;
            if (value != null) {
              try {
                var selectedRoute = _routes.firstWhere((r) {
                  String display =
                      "${r.routeName ?? r.routeId} ${r.type == 1 ? "OnWard" : "Return"}";
                  return display == value;
                });
                _returnRouteName = selectedRoute.routeName;
                Logger().i(selectedRoute.toJson());
                _returnRouteId = selectedRoute.routeId;
                _returnRouteType = selectedRoute.type;
                _returnTimes = callback.getRouteTimings(
                  _returnRouteId,
                  _returnRouteType,
                );
                //use getStopList from callback to get stopages
                _returnStopages = callback.getStopList(_returnRouteId!);
              } catch (e) {
                _returnRouteId = null;
                _returnRouteType = null;
                _returnTimes = [];
                _returnStopages = [];
              }
            } else {
              _returnRouteId = null;
              _returnRouteType = null;
              _returnTimes = [];
              _returnStopages = [];
            }
            _returnTime = null;
            _returnStopage = null;
            _returnHomeGeo = null;
            _returnSchoolStopGeo = null;
            _returnStopAriveTime = null;
            _returnStopageName = null;
          }
        });
      },
      validator: (value) => value == null ? 'Select a route' : null,
      dropdownColor: colorScheme.surface,
      style: TextStyle(color: colorScheme.onSurface),
    );
  }

  Widget _buildTimeDropdown(ColorScheme colorScheme, [String type = 'single']) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Timing',
        prefixIcon: Icon(Icons.access_time, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      value: type == 'single'
          ? _selectedTime
          : (type == 'onward' ? _onwardTime : _returnTime),
      items:
          (type == 'single'
                  ? _times
                  : (type == 'onward' ? _onwardTimes : _returnTimes))
              .map((time) => DropdownMenuItem(value: time, child: Text(time)))
              .toList(),
      onChanged: (value) {
        setState(() {
          if (type == 'single') {
            _selectedTime = value;
            _selectedorpId = callback
                .getOprIdbyTiming(value!, _selectedRouteId!)
                .toString();
            _vehicleId = callback
                .getVehicleIdbyTiming(value, _selectedRouteId!)
                .toString();
            // base on time selected get update time in stopages list
            //call getTimesbyStopId from callback
            List<String> times = callback.getRouteTimesbyOprId(
              int.parse(_selectedorpId!),
            );
            // update the _stopages time value based on times list
            //only in match case
            for (int i = 0; i < _stopages.length; i++) {
              String stopName = _stopages[i]['value'] ?? '';
              for (String timeEntry in times) {
                List<String> parts = timeEntry.split(', ');
                if (parts.length >= 3) {
                  String entryStopName = parts[0];
                  String arrivalPart = parts[1];
                  String departurePart = parts[2];
                  String arrivalTime = arrivalPart.split(': ')[1];
                  String departureTime = departurePart.split(': ')[1];
                  if (entryStopName == stopName) {
                    _stopages[i]['time'] = '($arrivalTime - $departureTime)';
                    break;
                  }
                }
              }
            }
          } else if (type == 'onward') {
            _onwardTime = value;
            _onwardorpId = callback
                .getOprIdbyTiming(value!, _onwardRouteId!)
                .toString();
            _onwardVehicleId = callback
                .getVehicleIdbyTiming(value, _onwardRouteId!)
                .toString();
            // base on time selected get update time in stopages list
            //call getTimesbyStopId from callback
            List<String> times = callback.getRouteTimesbyOprId(
              int.parse(_onwardorpId!),
            );
            // update the _onwardStopages time value based on times list
            //only in match case
            for (int i = 0; i < _onwardStopages.length; i++) {
              String stopName = _onwardStopages[i]['value'] ?? '';
              for (String timeEntry in times) {
                List<String> parts = timeEntry.split(', ');
                if (parts.length >= 3) {
                  String entryStopName = parts[0];
                  String arrivalPart = parts[1];
                  String departurePart = parts[2];
                  String arrivalTime = arrivalPart.split(': ')[1];
                  String departureTime = departurePart.split(': ')[1];
                  if (entryStopName == stopName) {
                    _onwardStopages[i]['time'] =
                        '($arrivalTime - $departureTime)';
                    break;
                  }
                }
              }
            }
          } else {
            _returnTime = value;
            _returnorpId = callback
                .getOprIdbyTiming(value!, _returnRouteId!)
                .toString();
            _returnVehicleId = callback
                .getVehicleIdbyTiming(value, _returnRouteId!)
                .toString();
            // base on time selected get update time in stopages list
            //call getTimesbyStopId from callback
            List<String> times = callback.getRouteTimesbyOprId(
              int.parse(_returnorpId!),
            );
            // update the _returnStopages time value based on times list
            //only in match case
            for (int i = 0; i < _returnStopages.length; i++) {
              String stopName = _returnStopages[i]['value'] ?? '';
              for (String timeEntry in times) {
                List<String> parts = timeEntry.split(', ');
                if (parts.length >= 3) {
                  String entryStopName = parts[0];
                  String arrivalPart = parts[1];
                  String departurePart = parts[2];
                  String arrivalTime = arrivalPart.split(': ')[1];
                  String departureTime = departurePart.split(': ')[1];
                  if (entryStopName == stopName) {
                    _returnStopages[i]['time'] =
                        '($arrivalTime - $departureTime)';
                    break;
                  }
                }
              }
            }
          }
        });
      },
      validator: (value) => value == null ? 'Select a time' : null,
      dropdownColor: colorScheme.surface,
      style: TextStyle(color: colorScheme.onSurface),
    );
  }

  Widget _buildStopageSelection(
    ColorScheme colorScheme, [
    String type = 'single',
  ]) {
    List<Map<String, String?>> filteredStopages = type == 'single'
        ? _stopages
        : (type == 'onward' ? _onwardStopages : _returnStopages);
    bool isOnWardRoute = type == 'single'
        ? _selectedTripType == 1
        : type == 'onward';
    if (isOnWardRoute) {
      // Disable the last stopage for OnWard routes
      filteredStopages = filteredStopages.asMap().entries.map((entry) {
        int index = entry.key;
        var stopage = entry.value;
        if (index == filteredStopages.length - 1) {
          // This is the last stopage - disable it
          setState(() {
            if (type == 'single') {
              _schoolStopGeo = stopage['location'];
            } else if (type == 'onward') {
              _onwardSchoolStopGeo = stopage['location'];
            } else {
              _returnSchoolStopGeo = stopage['location'];
            }
          });
          return {...stopage, 'disabled': 'true'};
        }
        return stopage;
      }).toList();
    } else {
      //reverse the stopages list
      filteredStopages = filteredStopages.reversed.toList();
      // Disable the first stopage for Return routes
      filteredStopages = filteredStopages.asMap().entries.map((entry) {
        int index = entry.key;
        var stopage = entry.value;
        if (index == 0) {
          // This is the first stopage - disable it
          setState(() {
            if (type == 'single') {
              _schoolStopGeo = stopage['location'];
            } else if (type == 'onward') {
              _onwardSchoolStopGeo = stopage['location'];
            } else {
              _returnSchoolStopGeo = stopage['location'];
            }
          });
          return {...stopage, 'disabled': 'true'};
        }
        return stopage;
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stoppages',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...filteredStopages.where((s) => s['disabled'] != 'true').map((
          stopage,
        ) {
          bool isSelected =
              (type == 'single'
                  ? _selectedStopage
                  : (type == 'onward' ? _onwardStopage : _returnStopage)) ==
              stopage['value'];
          return Card(
            color: isSelected ? colorScheme.primary.withOpacity(0.1) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: isSelected
                  ? BorderSide(color: colorScheme.primary, width: 2)
                  : BorderSide.none,
            ),
            child: ListTile(
              leading: Icon(
                Icons.location_on,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
              title: Text(
                '${stopage['value']} ${stopage['time'] ?? ''}',
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
              onTap: () {
                setState(() {
                  if (type == 'single') {
                    _selectedStopage = stopage['value'];
                    _selectedStopageName = stopage['value'];
                    _selectedHomeGeo = stopage['location'];
                    _selectedStopAriveTime = stopage['time'];
                    _stopageId = stopage['key'];
                  } else if (type == 'onward') {
                    _onwardStopage = stopage['value'];
                    _onwardStopageName = stopage['value'];
                    _onwardHomeGeo = stopage['location'];
                    _onwardStopAriveTime = stopage['time'];
                    _onwardStopageId = stopage['key'];
                  } else {
                    _returnStopage = stopage['value'];
                    _returnStopageName = stopage['value'];
                    _returnHomeGeo = stopage['location'];
                    _returnStopAriveTime = stopage['time'];
                    _returnStopageId = stopage['key'];
                  }
                });
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInstituteField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _instituteController,
      decoration: InputDecoration(
        labelText: 'School Name',
        prefixIcon: Icon(Icons.school, color: colorScheme.primary),
        suffixIcon: IconButton(
          //check icon is search or clear
          icon: Icon(_searchIcon),
          onPressed: () {
            if (_searchIcon == Icons.search) {
              searchSchool();
            } else {
              //clear all
              _instituteController.clear();
              _selectedSchool = null;
              _selectedInstitute = null;
              reset_all();
              _searchIcon = Icons.search;
              //set focus on institute field
              FocusScope.of(context).requestFocus(FocusNode());
            }
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Enter School Name' : null,
    );
  }

  Widget _buildTspDropdown(ColorScheme colorScheme) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'TSP',
        prefixIcon: Icon(Icons.list, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      value: _selectedInstitute,
      items: _tspList?.map((tsp) {
        return DropdownMenuItem<String>(
          value: tsp['tsp_id'],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tsp['name'] ?? ''),
              Text(
                tsp['city'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedInstitute = value;
          _getrouteListBytsp();
        });
      },
      validator: (value) => value == null ? 'Select a TSP' : null,
      dropdownColor: colorScheme.surface,
      style: TextStyle(color: colorScheme.onSurface),
    );
  }

  Widget _buildSubmitButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (_selectedTripType == 1) {
            if (_selectedStopage == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please select a stopage'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          } else {
            if (_onwardStopage == null || _returnStopage == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Please select stopages for both onward and return',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          }
          //show a conformation dialog and show the way selected, route name, time and stopage and ask for confirmation
          showDialog(
            context: context,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 16,
              backgroundColor: colorScheme.surface,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.confirmation_number,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Confirm Route Assignment',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(
                        color: colorScheme.outline.withOpacity(0.5),
                        thickness: 1,
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _selectedTripType == 1
                                ? [
                                    _buildTripCard(
                                      colorScheme,
                                      'One Way Trip',
                                      Icons.directions_car,
                                      [
                                        _buildDetailRow(
                                          colorScheme,
                                          Icons.route,
                                          'Route Name',
                                          _selectedRouteName ?? 'Not selected',
                                        ),
                                        _buildDetailRow(
                                          colorScheme,
                                          Icons.access_time,
                                          'Time',
                                          _selectedTime ?? 'Not selected',
                                        ),
                                        _buildDetailRow(
                                          colorScheme,
                                          Icons.location_on,
                                          'Stopage',
                                          _selectedStopageName ??
                                              'Not selected',
                                        ),
                                      ],
                                    ),
                                  ]
                                : [
                                    // Container(
                                    //   padding: const EdgeInsets.all(16),
                                    //   decoration: BoxDecoration(
                                    //     color: colorScheme.primary.withOpacity(0.1),
                                    //     borderRadius: BorderRadius.circular(12),
                                    //     border: Border.all(
                                    //       color: colorScheme.primary.withOpacity(0.3),
                                    //       width: 1,
                                    //     ),
                                    //   ),
                                    //   child: Row(
                                    //     children: [
                                    //       Icon(
                                    //         Icons.sync,
                                    //         color: colorScheme.primary,
                                    //       ),
                                    //       const SizedBox(width: 12),
                                    //       Text(
                                    //         'Round Trip',
                                    //         style: TextStyle(
                                    //           fontSize: 18,
                                    //           fontWeight: FontWeight.w600,
                                    //           color: colorScheme.primary,
                                    //         ),
                                    //       ),
                                    //     ],
                                    //   ),
                                    // ),
                                    // const SizedBox(height: 20),
                                    _buildTripCard(
                                      colorScheme,
                                      'Onward Route',
                                      Icons.arrow_forward,
                                      [
                                        _buildDetailRow(
                                          colorScheme,
                                          Icons.route,
                                          'Route Name',
                                          _onwardRouteName ?? 'Not selected',
                                        ),
                                        _buildDetailRow(
                                          colorScheme,
                                          Icons.access_time,
                                          'Time',
                                          _onwardTime ?? 'Not selected',
                                        ),
                                        _buildDetailRow(
                                          colorScheme,
                                          Icons.location_on,
                                          'Stopage',
                                          _onwardStopageName ?? 'Not selected',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTripCard(
                                      colorScheme,
                                      'Return Route',
                                      Icons.arrow_back,
                                      [
                                        _buildDetailRow(
                                          colorScheme,
                                          Icons.route,
                                          'Route Name',
                                          _returnRouteName ?? 'Not selected',
                                        ),
                                        _buildDetailRow(
                                          colorScheme,
                                          Icons.access_time,
                                          'Time',
                                          _returnTime ?? 'Not selected',
                                        ),
                                        _buildDetailRow(
                                          colorScheme,
                                          Icons.location_on,
                                          'Stopage',
                                          _returnStopageName ?? 'Not selected',
                                        ),
                                      ],
                                    ),
                                  ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _submit();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'Confirm',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          // _submit();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text('Save'),
      ),
    );
  }

  Widget _buildTripCard(
    ColorScheme colorScheme,
    String title,
    IconData icon,
    List<Widget> details,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...details,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    ColorScheme colorScheme,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Route',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildInstituteField(colorScheme),
              const SizedBox(height: 16),
              _buildTspDropdown(colorScheme),
              const SizedBox(height: 16),
              ToggleButtons(
                isSelected: [_selectedTripType == 1, _selectedTripType == 2],
                onPressed: (index) {
                  setState(() {
                    _selectedTripType = index + 1;
                    reset_all();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: colorScheme.onPrimary,
                fillColor: colorScheme.primary,
                color: colorScheme.primary,
                constraints: BoxConstraints(minHeight: 40, minWidth: 120),
                children: const [Text('One Way'), Text('Round Trip')],
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _selectedTripType == 1
                    ? _buildWaySection(colorScheme, 'one_way')
                    : _buildWaySection(colorScheme, 'round_trip'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaySection(ColorScheme colorScheme, String key) {
    if (key == 'round_trip') {
      return Column(
        key: ValueKey(key),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Onward section
          Text(
            'Onward Route',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          _buildRouteDropdown(colorScheme, 'onward'),
          const SizedBox(height: 16),
          _buildTimeDropdown(colorScheme, 'onward'),
          const SizedBox(height: 16),
          _buildStopageSelection(colorScheme, 'onward'),
          const SizedBox(height: 24),
          // Return section
          Text(
            'Return Route',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          _buildRouteDropdown(colorScheme, 'return'),
          const SizedBox(height: 16),
          _buildTimeDropdown(colorScheme, 'return'),
          const SizedBox(height: 16),
          _buildStopageSelection(colorScheme, 'return'),
          const SizedBox(height: 24),
          _buildSubmitButton(colorScheme),
        ],
      );
    } else {
      return Column(
        key: ValueKey(key),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRouteDropdown(colorScheme),
          const SizedBox(height: 16),
          _buildTimeDropdown(colorScheme),
          const SizedBox(height: 16),
          _buildStopageSelection(colorScheme),
          const SizedBox(height: 24),
          _buildSubmitButton(colorScheme),
        ],
      );
    }
  }

  void searchSchool() async {
    //print data
    final schoolName = _instituteController.text;
    _userId = await SharedPreferenceHelper.getUserNumber();
    _sessionId = await SharedPreferenceHelper.getUserSessionId();
    //run an api to get all institutes base on _instituteController
    ApiManager()
        .post(
          'ktuserschoolsearch/',
          data: {
            'schoolname': schoolName,
            'userid': _userId,
            'sessionid': _sessionId,
          },
        )
        .then((response) {
          if (response.statusCode == 200) {
            Logger().i(response.data);
            if (response.data[0]['result'] == 'ok') {
              //show list of schoolname and tsp_id
              if (!mounted) return;
              setState(() {
                _institutes = response.data[1]['data'] as List<dynamic>;
              });
              // show dialog
              _showInstituteDialog();
            } else {
              if (!mounted) return;
              setState(() {
                _institutes = [];
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${response.data[0]['message']}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        });
  }

  void _showInstituteDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Institute',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _institutes!.length,
                    itemBuilder: (context, index) {
                      var institute = _institutes![index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.school,
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(
                            //name and board
                            '${institute['schoolname']} (${institute['board']})',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            institute['city'],
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedSchool = institute['school_id'];
                              _instituteController.text =
                                  institute['schoolname'];
                              //after select change the search icon to clear icon
                              _searchIcon = Icons.clear;
                              _getTspBySchool();
                            });
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _getTspBySchool() {
    ApiManager()
        .post(
          'logapptspbyschool',
          data: {'passkey': "LogAp#KdTrac\$Skul", 'school_id': _selectedSchool},
        )
        .then((response) {
          if (response.statusCode == 200) {
            Logger().i(response.data);
            if (response.data[0]['result'] == 'ok') {
              callback.call(response.data);
              if (!mounted) return;
              setState(() {
                _tspList = response.data[1]['data'] as List<dynamic>?;
              });
            }
          }
        });
  }

  void _getrouteListBytsp() {
    ApiManager()
        .post(
          'kturoutelistbytsp',
          data: {
            'userid': _userId,
            'sessionid': _sessionId,
            'tsp_id': _selectedInstitute,
          },
        )
        .then((response) {
          if (response.statusCode == 200) {
            Logger().i(response.data);
            if (response.data[0]['result'] == 'ok') {
              callback.call(response.data);
              if (!mounted) return;
              setState(() {
                _routes.clear();
                _routes.addAll(callback.routeList);

                // Reset selections if they don't match the new route list
                List<String> availableRoutes = callback.getRouteNames();
                if (_selectedRoute != null &&
                    !availableRoutes.contains(_selectedRoute)) {
                  _selectedRoute = null;
                  _selectedRouteId = null;
                  _selectedRouteName = null;
                  _times = [];
                  _stopages = [];
                  _selectedTime = null;
                  _selectedorpId = null;
                  _selectedStopage = null;
                  _selectedHomeGeo = null;
                  _selectedStopAriveTime = null;
                  _schoolStopGeo = null;
                  _stopageId = null;
                  _vehicleId = null;
                }
              });
            }
          }
        });
  }

  void reset_all() {
    setState(() {
      _selectedRoute = null;
      _selectedRouteId = null;
      _selectedRouteName = null;
      _times = [];
      _stopages = [];
      _selectedTime = null;
      _selectedorpId = null;
      _selectedStopage = null;
      _selectedHomeGeo = null;
      _schoolStopGeo = null;
      _selectedStopAriveTime = null;
      _stopageId = null;
      _vehicleId = null;

      // Reset onward variables
      _onwardRoute = null;
      _onwardRouteName = null;
      _onwardRouteId = null;
      _onwardTime = null;
      _onwardorpId = null;
      _onwardStopage = null;
      _onwardStopageName = null;
      _onwardHomeGeo = null;
      _onwardSchoolStopGeo = null;
      _onwardStopAriveTime = null;
      _onwardStopageId = null;
      _onwardVehicleId = null;
      _onwardTimes = [];
      _onwardStopages = [];

      // Reset return variables
      _returnRoute = null;
      _returnRouteName = null;
      _returnRouteId = null;
      _returnTime = null;
      _returnorpId = null;
      _returnStopage = null;
      _returnStopageName = null;
      _returnHomeGeo = null;
      _returnSchoolStopGeo = null;
      _returnStopAriveTime = null;
      _returnStopageId = null;
      _returnVehicleId = null;
      _returnTimes = [];
      _returnStopages = [];
    });
  }
}
