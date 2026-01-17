import 'dart:convert';

import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/model/child.dart';
import 'package:kiddo_tracker/model/parent.dart';
import 'package:kiddo_tracker/model/route.dart';
import 'package:kiddo_tracker/model/subscribe.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/logger.dart';

class ChildrenService {
  List<Child> children = [];
  List<SubscriptionPlan> subscriptionPlans = [];
  Map<String, SubscriptionPlan> studentSubscriptions = {};
  final SqfliteHelper _sqfliteHelper = SqfliteHelper();
  Map<String, bool> activeRoutes = {};
  List<String> _topics = [];
  List<dynamic> studentInfo = [];
  List<dynamic> absentDays = [];

  Future<Map<String, dynamic>> fetchChildren() async {
    Logger().i('Fetching children...');
    try {
      // Clear previous data in DB
      _sqfliteHelper.clearAllData();

      // Get from shared preferences
      final String? userId = await SharedPreferenceHelper.getUserNumber();

      final response = await ApiService.fetchUserByMobile(userId!);
      final data = response.data;
      Logger().i(data);
      //if result is error then return success false
      if (data is List && data.isNotEmpty && data[0]['result'] == 'error') {
        return {'success': false, 'error': data[1]['data']};
      } else {
        return await processChildrenData(data);
      }
    } catch (e) {
      Logger().e('Error fetching children: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> processChildrenData(dynamic data) async {
    // Clear previous data in DB
    _sqfliteHelper.clearAllData();

    if (data is List && data.isNotEmpty && data[0]['result'] == 'ok') {
      final List userInfo = List.from(
        data[1]['userdata'] as List<dynamic>? ?? [],
      );
      //handle if there are no students in data[2]['studentdata'] then response = "ktuserstudentlist Data not found"
      if (data[2]['studentdata'] is String) {
        studentInfo = [];
        // return {'success': false, 'error': 'ktuserstudentlist Data not found'};
      } else {
        studentInfo = List.from(data[2]['studentdata'] as List<dynamic>? ?? []);
      }

      Parent parent = Parent(
        userid: userInfo[0]['userid'].toString(),
        name: userInfo[0]['name'].toString(),
        city: userInfo[0]['city'].toString(),
        state: userInfo[0]['state'].toString(),
        address: userInfo[0]['address'].toString(),
        contact: userInfo[0]['contact'].toString(),
        email: userInfo[0]['email'].toString(),
        mobile: userInfo[0]['mobile'].toString(),
        wards: int.tryParse(userInfo[0]['wards'].toString()) ?? 0,
        status: int.tryParse(userInfo[0]['status'].toString()) ?? 0,
        pin: int.tryParse(userInfo[0]['pin'].toString()) ?? 0,
      );
      Logger().i(parent.toJson().toString());
      // Store userInfo to sqflite
      await _sqfliteHelper.insertUser(parent);
      // Store session data
      SharedPreferenceHelper.setUserNumber(userInfo[0]['userid'].toString());
      SharedPreferenceHelper.setUserSessionId(
        userInfo[0]['sessionid'].toString(),
      );
      Logger().i(
        ' Mobile Number: ${userInfo[0]['userid']}, Session ID: ${userInfo[0]['sessionid']}',
      );
      // Fetch subscription data
      await _fetchAndSetSubscriptionPlans(
        userInfo[0]['userid'],
        userInfo[0]['sessionid'],
      );

      // Clear global children list before adding new children
      children.clear();
      List<RouteInfo> allParsedRouteInfo = [];
      if (studentInfo.isNotEmpty) {
        for (var student in studentInfo) {
          Logger().i(student);
          Logger().i(student['route_info']);
          List<RouteInfo> studentRouteInfo = [];
          //handle the [] case
          if (student['route_info'] == "") {
            studentRouteInfo = [];
          } else if (student['route_info'] != "") {
            String routeInfoString = student['route_info'];
            Logger().i(routeInfoString);
            // Parse route_info string to List<dynamic>
            List<dynamic> routeInfo = jsonDecode(routeInfoString);
            // List<dynamic> routeInfo = parseRouteInfo(routeInfoString);
            Logger().i(routeInfo);
            // Convert each dynamic map to RouteInfo object
            studentRouteInfo = routeInfo.map((route) {
              route['school_location'] = "";
              route['start_time'] = "";
              return RouteInfo.fromJson(route);
            }).toList();
            //cnvert the studentRouteInfo to string
          }
          //set in Child
          Child child = Child(
            studentId: student['student_id'],
            name: student['name'],
            nickname: student['nickname'],
            school: student['school'],
            class_name: student['class'],
            rollno: student['rollno'],
            age: student['age'],
            gender: student['gender'],
            tagId: student['tag_id'],
            routeInfo: studentRouteInfo,
            tsp_id: (student['tsp_id'] != null && student['tsp_id'].isNotEmpty)
                ? List<String>.from(jsonDecode(student['tsp_id']))
                : [],
            status: student['status'],
            onboard_status: student['onboard_status'],
          );
          Logger().i(child.toJson().toString());
          // Store children data
          children.add(child);
          // Store child data to sqflite
          await _sqfliteHelper.insertChild(child);
          // Store routeInfo data
          allParsedRouteInfo.addAll(studentRouteInfo);
          Logger().i("${child.toJson()} $studentRouteInfo");
        }
      }

      // Store topics only for children with active subscriptions
      List<String> topics = [];
      for (var child in children) {
        final subscription = studentSubscriptions[child.studentId];
        if (subscription != null && subscription.status == 1) {
          topics.add(child.studentId);
          // Add route topics for active subscriptions
          topics.addAll(
            child.routeInfo
                .map((route) => '${route.routeId}/${route.oprId}')
                .toList(),
          );
        }
      }
      _topics = topics;
      //fetch the student absent days from server and store in sqflite base on tsp_id
      //get the usernumber and sesion
      String userId = userInfo[0]['userid'].toString();
      String sessionId = userInfo[0]['sessionid'].toString();
      for (var child in children) {
        Logger().i('Fetching absent days for child: ${child.tsp_id}');
        for (var tspId in child.tsp_id) {
          Logger().i('Fetching absent days for tspId: $tspId');
          final response = await ApiService.fetchStudentAbsentDays(
            userId,
            sessionId,
            tspId,
            child.studentId,
          );
          final data = response.data;
          Logger().i(data);
          // Store absent days data in absentDays list
          if (data[0]['result'] == 'ok') {
            if (data[1]['data'] is String || data[1]['data'].isEmpty) {
              Logger().i('No absent days found for tspId: $tspId');
              continue;
            } else {
              Logger().i('Absent days data: ${data[1]['data']}');
              absentDays.addAll(data[1]['data'] as List<dynamic>? ?? []);
              final List absentDaysData = List.from(
                data[1]['data'] as List<dynamic>? ?? [],
              );
              for (var absentDay in absentDaysData) {
                await _sqfliteHelper.insertAbsentDay(
                  absentDay['student_id'].toString(),
                  absentDay['start_date'].toString(),
                  absentDay['end_date'].toString(),
                  tspId,
                );
              }
            }
          }
        }
      }

      // Clear and assign activeRoutes global variable
      activeRoutes.clear();

      return {
        'success': true,
        'result': {
          'children': children,
          'subscriptionPlans': subscriptionPlans,
          'studentSubscriptions': studentSubscriptions,
          'activeRoutes': activeRoutes,
          'parent': parent,
          'topics': _topics,
          'studentInfo': studentInfo,
          'allRouteInfo': allParsedRouteInfo,
          'userInfo': userInfo,
          'absentDays': absentDays,
        },
      };
    } else {
      return {'success': false, 'data': data};
    }
  }

  Future<void> _fetchAndSetSubscriptionPlans(
    String userId,
    String sessionid,
  ) async {
    try {
      final response = await ApiService.fetchSubscriptionPlans(
        userId,
        sessionid,
      );
      final data = response.data;
      Logger().i(data);
      if (data[0]['result'] == 'ok') {
        final List subscriptionData = List.from(
          data[1]['data'] as List<dynamic>? ?? [],
        );
        // Clear global lists before adding new data
        subscriptionPlans.clear();
        studentSubscriptions.clear();
        for (var subscription in subscriptionData) {
          SubscriptionPlan subscriptionPlan = SubscriptionPlan(
            student_id: subscription['student_id'].toString(),
            plan_name: subscription['plan_name'].toString(),
            plan_details: subscription['plan_details'].toString(),
            validity: int.tryParse(subscription['validity'].toString()) ?? 0,
            price: int.tryParse(subscription['price'].toString()) ?? 0,
            startdate: subscription['startdate'].toString(),
            enddate: subscription['enddate'].toString(),
            status: int.tryParse(subscription['status'].toString()) ?? 0,
            userid: subscription['userid'].toString(),
          );
          // Store subscription data
          subscriptionPlans.add(subscriptionPlan);
          // Store subscription plan data
          studentSubscriptions[subscriptionPlan.student_id] = subscriptionPlan;
          // Store subscription plan to sqflite
          await _sqfliteHelper.insertStudentSubscription(subscriptionPlan);
          Logger().i(subscriptionPlan.toJson().toString());
        }
      }
    } catch (e) {
      Logger().e('Error fetching subscription plans: $e');
      rethrow;
    }
  }

  List<dynamic> parseRouteInfo(String routeInfoString) {
    String content = routeInfoString.trim();
    if (content.startsWith('[')) content = content.substring(1);
    if (content.endsWith(']')) {
      content = content.substring(0, content.length - 1);
    }
    if (content.startsWith('{')) content = content.substring(1);
    if (content.endsWith('}')) {
      content = content.substring(0, content.length - 1);
    }
    List<String> keys = [
      'route_id',
      'route_name',
      'oprid',
      'type',
      'vehicle_id',
      'stop_id',
      'stop_name',
      'location',
      'stop_arrival_time',
    ];

    Map<String, dynamic> result = {};

    for (int i = 0; i < keys.length; i++) {
      String currentKey = keys[i];
      String? nextKey = (i + 1 < keys.length) ? keys[i + 1] : null;

      // Find the value between current key and next key
      RegExp regex;
      if (nextKey != null) {
        regex = RegExp('$currentKey:\\s*(.+?)(?=,\\s*$nextKey:)');
      } else {
        regex = RegExp('$currentKey:\\s*(.+)\$');
      }

      Match? match = regex.firstMatch(content);
      if (match != null) {
        String value = match.group(1)?.trim() ?? '';

        // Try to parse as int, otherwise keep as string
        if (int.tryParse(value) != null) {
          result[currentKey] = int.parse(value);
        } else {
          result[currentKey] = value;
        }
      }
    }
    result['school_location'] = "";
    result['start_time'] = "";
    return [result];
  }
}
