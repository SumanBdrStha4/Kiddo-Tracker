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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _instituteController = TextEditingController();
  IconData _searchIcon = Icons.search;

  String? _userId;
  String? _sessionId;
  List<dynamic>? _institutes = [];
  String? _selectedInstitute;

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
  String? _stopageId;
  String? _vehicleId;
  //callback
  RouteSearchCallback callback = RouteSearchCallback();

  @override
  void dispose() {
    _instituteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      //show all value of Institute, Route, Time, Stopage
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
                  if (widget.stdId != null) {
                    final sqfliteHelper = SqfliteHelper();
                    // Get existing routes
                    final existingRouteStr = await sqfliteHelper
                        .getRouteInfoByStudentId(widget.stdId!);
                    List<RouteInfo> routeList = [];
                    if (existingRouteStr != null &&
                        existingRouteStr.isNotEmpty) {
                      try {
                        final decoded = jsonDecode(existingRouteStr);
                        if (decoded is List) {
                          routeList = decoded
                              .map<RouteInfo>(
                                (e) => RouteInfo.fromJson(
                                  e is String
                                      ? jsonDecode(e)
                                      : e as Map<String, dynamic>,
                                ),
                              )
                              .toList();
                        }
                      } catch (e) {
                        Logger().e('Error decoding existing routes: $e');
                      }
                    }
                    // Add new route to db
                    routeList.add(
                      RouteInfo(
                        routeId: _selectedRouteId ?? '',
                        routeType: _selectedRouteType ?? 0,
                        routeName: _selectedRouteName ?? '',
                        stopArrivalTime: _selectedTime ?? '',
                        stopName: _selectedStopageName ?? '',
                        stopLocation: _selectedHomeGeo ?? '',
                        schoolLocation: _schoolStopGeo ?? '',
                        oprId: _selectedorpId ?? '',
                        vehicleId: _vehicleId ?? '',
                        stopId: _stopageId ?? '',
                      ),
                    );
                    // make the routeList inside String
                    Logger().i(routeList.map((e) => e.toJson()).toList());
                    final newRoute = jsonEncode(
                      routeList.map((e) => e.toJson()).toList(),
                    );
                    Logger().i(newRoute);
                    await sqfliteHelper.updateRouteInfoByStudentId(
                      widget.stdId!,
                      newRoute,
                    );
                    final provider = Provider.of<ChildrenProvider>(
                      context,
                      listen: false,
                    );
                    await provider.updateChildren();
                    await provider.subscribeToTopics();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("New Route Added Successfully.")),
                    );
                  } else {
                    // Handle the case when widget.stdId is null
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: widget.stdId is null')),
                    );
                  }
                  // Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${response.data[1]['data']}'),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Data not saved.")));
              }
            }
          });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please fix the errors in red')));
    }
  }

  Widget _buildInstituteField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _instituteController,
      decoration: InputDecoration(
        labelText: 'Institute',
        prefixIcon: Icon(Icons.school, color: colorScheme.primary),
        suffixIcon: IconButton(
          //check icon is search or clear
          icon: Icon(_searchIcon),
          onPressed: () {
            if (_searchIcon == Icons.search) {
              searchInstitite();
            } else {
              //clear all
              _instituteController.clear();
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
          value == null || value.isEmpty ? 'Enter institute' : null,
    );
  }

  Widget _buildRouteDropdown(ColorScheme colorScheme) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Route No',
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
      initialValue: _selectedRoute,
      items: callback
          .getRouteNames()
          .map(
            (route) =>
                DropdownMenuItem<String>(value: route, child: Text(route)),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
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
          _selectedStopageName = null;
        });
      },
      validator: (value) => value == null ? 'Select a route' : null,
      dropdownColor: colorScheme.surface,
      style: TextStyle(color: colorScheme.onSurface),
    );
  }

  Widget _buildTimeDropdown(ColorScheme colorScheme) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Time',
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
      initialValue: _selectedTime,
      items: _times
          .map((time) => DropdownMenuItem(value: time, child: Text(time)))
          .toList(),
      onChanged: (value) {
        setState(() {
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
        });
      },
      validator: (value) => value == null ? 'Select a time' : null,
      dropdownColor: colorScheme.surface,
      style: TextStyle(color: colorScheme.onSurface),
    );
  }

  Widget _buildStopageSelection(ColorScheme colorScheme) {
    // Check route type and filter stopages if route type is OnWard
    List<Map<String, String?>> filteredStopages = _stopages;
    bool isOnWardRoute = false;
    //making the last item disabled if route type is OnWard
    if (_selectedRouteId != null) {
      try {
        isOnWardRoute = _selectedRouteType == 1;
      } catch (e) {
        isOnWardRoute = false;
      }
    }
    if (isOnWardRoute) {
      // Disable the last stopage for OnWard routes
      filteredStopages = filteredStopages.asMap().entries.map((entry) {
        int index = entry.key;
        var stopage = entry.value;
        if (index == filteredStopages.length - 1) {
          // This is the last stopage - disable it
          setState(() {
            _schoolStopGeo = stopage['location'];
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
            _schoolStopGeo = stopage['location'];
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
          'Select Stopage:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        ...filteredStopages.map(
          (stopage) => RadioListTile<String>(
            title: Text(
              '${stopage['value']} ${stopage['time'] ?? ''}',
              style: TextStyle(
                color: stopage['disabled'] == 'true'
                    ? colorScheme.onSurface.withOpacity(0.5)
                    : colorScheme.onSurface,
              ),
            ),
            value: stopage['value']!,
            groupValue: _selectedStopage,
            onChanged: stopage['disabled'] == 'true'
                ? null
                : (value) {
                    setState(() {
                      _selectedStopage = value;
                      _selectedStopageName = value;
                      _selectedHomeGeo = stopage['location'];
                      _stopageId = stopage['key'];
                    });
                  },
            activeColor: colorScheme.primary,
          ),
        ),
        if (_selectedStopage == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Please select a stopage',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton(ColorScheme colorScheme) {
    return ElevatedButton(
      onPressed: () {
        if (_selectedStopage == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Please select a stopage')));
          return;
        }
        _submit();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text('Add Route'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'New Route for ${widget.nickName}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInstituteField(colorScheme),
                      SizedBox(height: 16),
                      _buildRouteDropdown(colorScheme),
                      SizedBox(height: 16),
                      _buildTimeDropdown(colorScheme),
                      SizedBox(height: 16),
                      _buildStopageSelection(colorScheme),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSubmitButton(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  void searchInstitite() async {
    //print data
    final tspName = _instituteController.text;
    _userId = await SharedPreferenceHelper.getUserNumber();
    _sessionId = await SharedPreferenceHelper.getUserSessionId();
    //run an api to get all institutes base on _instituteController
    ApiManager()
        .post(
          'ktusertspnamesearch',
          data: {
            'tsp_name': tspName,
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
                            institute['schoolname'],
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            institute['tsp_id'],
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedInstitute = institute['tsp_id'];
                              _instituteController.text =
                                  institute['schoolname'];
                              //after select change the search icon to clear icon
                              _searchIcon = Icons.clear;
                              _getrouteListBytsp();
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
      _stopageId = null;
      _vehicleId = null;
    });
  }
}
