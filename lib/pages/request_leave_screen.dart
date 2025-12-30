import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:logger/logger.dart';
import 'package:table_calendar/table_calendar.dart';

class RequestLeaveScreen extends StatefulWidget {
  final Map<String, dynamic>? child;
  final String? oprId;
  final String? routeId;
  final String? childId;

  const RequestLeaveScreen({
    super.key,
    required this.child,
    this.oprId,
    this.routeId,
    this.childId,
  });

  @override
  _RequestLeaveScreenState createState() => _RequestLeaveScreenState();
}

class _RequestLeaveScreenState extends State<RequestLeaveScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  String? child_id;
  Map<DateTime, String> _holidayTypes = {};
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchHolidays();
  }

  Future<void> _fetchHolidays() async {
    try {
      final String? userId = await SharedPreferenceHelper.getUserNumber();
      final String? sessionId = await SharedPreferenceHelper.getUserSessionId();
      print('Fetching holidays for userId: $userId, sessionId: $sessionId');
      //check if routeId and oprId are passed from previous screen
      final String? oprId = widget.oprId;
      final String? routeId = widget.routeId;
      print('Using oprId: $oprId, routeId: $routeId');
      Map<DateTime, String> allHolidayTypes = {};
      if (oprId != null &&
          routeId != null &&
          userId != null &&
          sessionId != null) {
        child_id = widget.childId;
        await callAPItoFetch(
          oprId,
          routeId,
          userId,
          sessionId,
          allHolidayTypes,
        );
      } else if (userId != null && sessionId != null) {
        child_id = widget.child?['name'];
        // Get the list of routes route_id and oprid from child route_info and print the output
        final routeInfoJson = widget.child?['route_info'] ?? '[]';
        final List<dynamic> routeInfo = json.decode(routeInfoJson);

        for (var route in routeInfo) {
          print('Route ID: ${route['route_id']}, OPR ID: ${route['oprid']}');
        }
        print('Route info: $routeInfo');
        for (var route in routeInfo) {
          final String opId = route['oprid'].toString();
          final String routeId = route['route_id'].toString();
          print('Fetching holidays for opId: $opId, routeId: $routeId');
          await callAPItoFetch(
            opId,
            routeId,
            userId,
            sessionId,
            allHolidayTypes,
          );
        }
      }
      setState(() {
        _holidayTypes = allHolidayTypes;
      });
    } catch (e) {
      Logger().e('Error fetching holidays: $e');
    }
  }

  Map<DateTime, String> _generateWeeklyOffDates(List<String> offDays) {
    Map<DateTime, String> weeklyOffs = {};
    DateTime startDate = DateTime.utc(2020, 1, 1);
    DateTime endDate = DateTime.utc(2030, 12, 31);

    Map<String, int> dayMap = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    List<int> offWeekdays = offDays
        .map((day) => dayMap[day])
        .where((wd) => wd != null)
        .cast<int>()
        .toList();

    for (
      DateTime date = startDate;
      date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
      date = date.add(const Duration(days: 1))
    ) {
      if (offWeekdays.contains(date.weekday)) {
        weeklyOffs[DateTime(date.year, date.month, date.day)] = 'weekoff';
      }
    }

    return weeklyOffs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Request Leave for ${child_id ?? "Child"}')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            rangeStartDay: _rangeStart,
            rangeEndDay: _rangeEnd,
            rangeSelectionMode: RangeSelectionMode.toggledOn,
            onRangeSelected: (start, end, focusedDay) {
              setState(() {
                _rangeStart = start;
                _rangeEnd = end ?? start; // Allow single day selection
                _focusedDay = focusedDay ?? DateTime.now();
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final dateKey = DateTime(day.year, day.month, day.day);
                final holidayType = _holidayTypes[dateKey];
                final isToday = isSameDay(day, DateTime.now());

                if (isToday) {
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                } else if (holidayType != null) {
                  Color color;
                  switch (holidayType) {
                    case 'tsp':
                      color = Colors.yellow.shade100;
                      break;
                    case 'route':
                      color = Colors.brown.shade100;
                      break;
                    case 'opr':
                      color = Colors.green.shade100;
                      break;
                    case 'weekoff':
                      color = Colors.red.shade100;
                      break;
                    case 'defultHoliday':
                      color = Colors.purple.shade100;
                      break;
                    default:
                      color = Colors.grey.shade100;
                  }
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
          //show what color represents which holiday type
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLegendItem('TSP Holiday', Colors.yellow.shade100),
                _buildLegendItem('Route Holiday', Colors.brown.shade100),
                _buildLegendItem('OPR Holiday', Colors.green.shade100),
                _buildLegendItem('Weekly Off', Colors.red.shade100),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '*Please select a date or date range from the calendar above to request leave.',
                        style: TextStyle(fontSize: 14, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 16),
                      if (_rangeStart != null && _rangeEnd != null)
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            _rangeStart == _rangeEnd
                                ? 'Selected Date: ${_rangeStart!.day}-${_rangeStart!.month}-${_rangeStart!.year}'
                                : 'Selected Range: ${_rangeStart!.day}-${_rangeStart!.month}-${_rangeStart!.year} to ${_rangeEnd!.day}-${_rangeEnd!.month}-${_rangeEnd!.year}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      if (_rangeStart != null && _rangeEnd != null)
                        const SizedBox(height: 20),
                      TextFormField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Reason for Leave',
                          border: OutlineInputBorder(),
                          hintText: 'Enter the reason for the leave request',
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a reason';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitLeaveRequest,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: const Text(
                            'Submit Leave Request',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitLeaveRequest() async {
    if (_rangeStart == null || _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date range and provide a reason.'),
        ),
      );
      return;
    }

    try {
      _rangeStart == _rangeEnd
          ? _rangeEnd = _rangeStart
          : _rangeEnd = _rangeEnd;

      final String? userId = await SharedPreferenceHelper.getUserNumber();
      final String? sessionId = await SharedPreferenceHelper.getUserSessionId();

      if (userId != null && sessionId != null) {
        String startDate = _rangeStart!.toIso8601String().split('T').first;
        String endDate = _rangeEnd!.toIso8601String().split('T').first;
        //convert tsp_id string to list
        String StringTSP = widget.child?['tsp_id'] ?? '';
        List<String> tspId = List<String>.from(jsonDecode(StringTSP));
        Logger().d('TSP ID raw value: ${widget.child?['tsp_id']}');

        //check the length of tspId and run the loop.
        for (int i = 0; i < tspId.length; i++) {
          String singleTSP = tspId[i];
          Logger().d('Submitting leave request from $startDate to $endDate');
          Logger().d(
            'Child ID: ${widget.child?['student_id']}, TSP ID: $singleTSP',
          );
          Logger().d('User ID: $userId, Session ID: $sessionId');

          final response = await ApiService.sendAbsentDays(
            startDate,
            endDate,
            singleTSP,
            widget.child?['student_id'] ?? '',
            sessionId,
            userId,
          );
          final data = response.data;
          Logger().d('Leave request response: $data');
          if (data[0]['result'] == 'ok') {
            // For now, just show a success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Leave request submitted successfully to $singleTSP!',
                ),
              ),
            );

            // Clear the form
            setState(() {
              _rangeStart = null;
              _rangeEnd = null;
              _reasonController.clear();
            });
          } else {
            String errorData = data[1]['data'];
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $errorData')));
          }
        }
      }
    } catch (e) {
      Logger().e('Error submitting leave request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit leave request. Please try again.'),
        ),
      );
    }
  }

  _buildLegendItem(String s, Color shade100) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: shade100,
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
        const SizedBox(width: 8),
        Text(s),
      ],
    );
  }

  Future<void> callAPItoFetch(
    String opId,
    String routeId,
    String userId,
    String sessionId,
    Map<DateTime, String> allHolidayTypes,
  ) async {
    if (opId.isNotEmpty && routeId.isNotEmpty) {
      final response = await ApiService.fetchHolidays(
        userId,
        opId,
        routeId,
        // "6",
        // "OD36895900001",
        sessionId,
      );
      final data = response.data;
      print('Fetched holidays for opId $opId: $data');
      if (data[0]['result'] == 'ok') {
        // tsp_offdata
        final tspOffData = data[1]['tsp_offdata'];
        if (tspOffData is List && tspOffData.isNotEmpty) {
          for (var holiday in tspOffData) {
            DateTime start = DateTime.parse(holiday['start_date']);
            DateTime end = DateTime.parse(holiday['end_date']);
            // String tspId = holiday['tsp_id'];
            for (
              DateTime date = start;
              date.isBefore(end.add(Duration(days: 1)));
              date = date.add(Duration(days: 1))
            ) {
              allHolidayTypes[DateTime(date.year, date.month, date.day)] =
                  'tsp';
            }
          }
        }

        // route_offdata
        final routeOffData = data[2]['route_offdata'];
        if (routeOffData is List && routeOffData.isNotEmpty) {
          for (var holiday in routeOffData) {
            DateTime start = DateTime.parse(holiday['start_date']);
            DateTime end = DateTime.parse(holiday['end_date']);
            for (
              DateTime date = start;
              date.isBefore(end.add(Duration(days: 1)));
              date = date.add(Duration(days: 1))
            ) {
              allHolidayTypes[DateTime(date.year, date.month, date.day)] =
                  'route';
            }
          }
        }

        // opr_offdata
        final oprOffData = data[3]['opr_offdata'];
        if (oprOffData is List && oprOffData.isNotEmpty) {
          for (var holiday in oprOffData) {
            DateTime start = DateTime.parse(holiday['start_date']);
            DateTime end = DateTime.parse(holiday['end_date']);
            for (
              DateTime date = start;
              date.isBefore(end.add(Duration(days: 1)));
              date = date.add(Duration(days: 1))
            ) {
              allHolidayTypes[DateTime(date.year, date.month, date.day)] =
                  'opr';
            }
          }
        }

        // weekoff
        final weekOffData = data[4]['weekoff'];
        if (weekOffData is List && weekOffData.isNotEmpty) {
          final String offDaysString = weekOffData[0]['off_data'] ?? '';
          final List<String> offDays = offDaysString
              .split(', ')
              .map((day) => day.trim())
              .toList();
          final Map<DateTime, String> weeklyOffs = _generateWeeklyOffDates(
            offDays,
          );
          allHolidayTypes.addAll(weeklyOffs);
        }

        // defultHoliday
        //make each sunday as default holiday
        DateTime startDate = DateTime.utc(2020, 1, 1);
        DateTime endDate = DateTime.utc(2030, 12, 31);
        for (
          DateTime date = startDate;
          date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
          date = date.add(const Duration(days: 1))
        ) {
          if (date.weekday == DateTime.sunday) {
            allHolidayTypes.addAll({
              DateTime(date.year, date.month, date.day): 'defultHoliday',
            });
          }
        }
      }
    }
  }
}
