import 'package:flutter/material.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:logger/logger.dart';
import 'package:table_calendar/table_calendar.dart';

class RequestLeaveScreen extends StatefulWidget {
  final Map<String, dynamic> child;

  const RequestLeaveScreen({Key? key, required this.child}) : super(key: key);

  @override
  _RequestLeaveScreenState createState() => _RequestLeaveScreenState();
}

class _RequestLeaveScreenState extends State<RequestLeaveScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<DateTime> _holidays = {};

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
      // Get the list of routeInfo from child data
      final List<dynamic> routeInfo = widget.child['routeInfo'] ?? [];
      print('Route info: $routeInfo');
      if (userId != null && sessionId != null && routeInfo.isNotEmpty) {
        Set<DateTime> allHolidays = {};
        for (var route in routeInfo) {
          final String opId = route['oprid'] ?? '';
          final String routeId = route['route_id'] ?? '';
          print('Fetching holidays for opId: $opId, routeId: $routeId');
          if (opId.isNotEmpty && routeId.isNotEmpty) {
            final response = await ApiService.fetchHolidays(
              userId,
              opId,
              routeId,
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
                    allHolidays.add(DateTime(date.year, date.month, date.day));
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
                    allHolidays.add(DateTime(date.year, date.month, date.day));
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
                    allHolidays.add(DateTime(date.year, date.month, date.day));
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
                final Set<DateTime> weeklyOffs = _generateWeeklyOffDates(
                  offDays,
                );
                allHolidays.addAll(weeklyOffs);
              }
            }
          }
        }
        setState(() {
          _holidays = allHolidays;
        });
      }
    } catch (e) {
      Logger().e('Error fetching holidays: $e');
    }
  }

  Set<DateTime> _generateWeeklyOffDates(List<String> offDays) {
    Set<DateTime> weeklyOffs = {};
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
        weeklyOffs.add(DateTime(date.year, date.month, date.day));
      }
    }

    return weeklyOffs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Request Leave for ${widget.child['name']}')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
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
                if (_holidays.contains(
                  DateTime(day.year, day.month, day.day),
                )) {
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red,
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
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Selected Date: ${_selectedDay!.toLocal()}'.split(' ')[0],
                style: const TextStyle(fontSize: 18),
              ),
            ),
        ],
      ),
    );
  }
}
