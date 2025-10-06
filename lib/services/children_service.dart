import 'dart:convert';

import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/model/child.dart';
import 'package:kiddo_tracker/model/parent.dart';
import 'package:kiddo_tracker/model/route.dart';
import 'package:kiddo_tracker/model/subscribe.dart';
import 'package:kiddo_tracker/mqtt/MQTTService.dart';
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

  Future<Map<String, dynamic>> fetchChildren() async {
    Logger().i('Fetching children...');
    try {
      // Clear previous data in DB
      // _sqfliteHelper.clearAllData();

      // Get from shared preferences
      final String? userId = await SharedPreferenceHelper.getUserNumber();

      final response = await ApiService.fetchUserByMobile(userId!);
      final data = response.data;
      Logger().i(data);
      if (data[0]['result'] == 'ok') {
        final List userInfo = List.from(
          data[1]['userdata'] as List<dynamic>? ?? [],
        );
        final List studentInfo = List.from(
          data[2]['studentdata'] as List<dynamic>? ?? [],
        );
        Parent parent = Parent(
          userid: userInfo[0]['userid'],
          name: userInfo[0]['name'],
          city: userInfo[0]['city'],
          state: userInfo[0]['state'],
          address: userInfo[0]['address'],
          contact: userInfo[0]['contact'],
          email: userInfo[0]['email'],
          mobile: userInfo[0]['mobile'],
          wards: userInfo[0]['wards'],
          status: userInfo[0]['status'],
          sessionid: userInfo[0]['sessionid'],
        );
        Logger().i(parent.toJson().toString());
        // Store userInfo to sqflite
        await _sqfliteHelper.insertUser(parent);
        // Store session data
        SharedPreferenceHelper.setUserNumber(userInfo[0]['userid']);
        SharedPreferenceHelper.setUserSessionId(userInfo[0]['sessionid']);
        Logger().i(
          ' Mobile Number: ${userInfo[0]['userid']}, Session ID: ${userInfo[0]['sessionid']}',
        );
        // Fetch subscription data
        await _fetchAndSetSubscriptionPlans(
          userInfo[0]['userid'],
          studentInfo,
          userInfo[0]['sessionid'],
        );

        // Clear global children list before adding new children
        children.clear();
        List<RouteInfo> allParsedRouteInfo = [];
        for (var student in studentInfo) {
          Logger().i(student.toString());
          List<RouteInfo> parsedRouteInfo = [];
          if (student['route_info'] != null) {
            if (student['route_info'] is String &&
                (student['route_info'] as String).isNotEmpty) {
              try {
                var decoded = jsonDecode(student['route_info']);
                if (decoded is List) {
                  parsedRouteInfo = decoded
                      .map<RouteInfo>(
                        (e) {
                          var json = e is String
                              ? jsonDecode(e)
                              : e as Map<String, dynamic>;
                          json['school_location'] = student['school'];
                          return RouteInfo.fromJson(json);
                        },
                      )
                      .toList();
                }
              } catch (e) {
                Logger().e("Error parsing route_info: $e");
              }
            } else if (student['route_info'] is List) {
              parsedRouteInfo = (student['route_info'] as List)
                  .map<RouteInfo>(
                    (e) {
                      var json = e is String
                          ? jsonDecode(e)
                          : e as Map<String, dynamic>;
                      json['school_location'] = student['school'];
                      return RouteInfo.fromJson(json);
                    },
                  )
                  .toList();
            }
          }
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
            routeInfo: parsedRouteInfo,
            tsp_id: (student['tsp_id'] != null && student['tsp_id'].isNotEmpty) ? List<String>.from(jsonDecode(student['tsp_id'])) : [],
            status: student['status'],
            onboard_status: student['onboard_status'],
          );
          // Store children data
          children.add(child);
          // Store child data to sqflite
          await _sqfliteHelper.insertChild(child);
          // Store routeInfo data
          allParsedRouteInfo.addAll(parsedRouteInfo);
          Logger().i("${child.toJson()} $parsedRouteInfo");
        }

        // Store topics
        List<String> topics = children.map((child) => child.studentId).toList();
        topics.addAll(
          allParsedRouteInfo
              .map((route) => '${route.routeId}/${route.oprId}')
              .toList(),
        );
        _topics = topics;

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
          },
        };
      } else {
        return {'success': false, 'data': data};
      }
    } catch (e) {
      Logger().e('Error fetching children: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> _fetchAndSetSubscriptionPlans(
    String userId,
    List studentInfo,
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
            student_id: subscription['student_id'],
            plan_name: subscription['plan_name'],
            plan_details: subscription['plan_details'],
            validity: subscription['validity'],
            price: subscription['price'],
            startdate: subscription['startdate'],
            enddate: subscription['enddate'],
            status: subscription['status'],
            userid: subscription['userid'],
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

  // subscribe to multiple topics
  Future<void> subscribeToTopics({required MQTTService mqttService}) async {
    if (mqttService.subscribedTopics.isNotEmpty) {
      mqttService.unsubscribeFromAllTopics();
    }
    mqttService.subscribeToTopics(_topics);
  }

  // subscribe to newly added child
  Future<void> subscribeToNewlyAddedChild({
    required MQTTService mqttService,
  }) async {
    // Check current subscribed topics
    final currentTopics = mqttService.subscribedTopics;

    // Prepare new topics list based on current children and their routeInfo
    List<String> newTopics = children.map((child) => child.studentId).toList();
    for (var child in children) {
      newTopics.addAll(
        child.routeInfo.map((route) => '${route.routeId}/${route.oprId}'),
      );
    }
    final topicsToAdd = newTopics
        .where((topic) => !currentTopics.contains(topic))
        .toList();
    final topicsToRemove = currentTopics
        .where((topic) => !newTopics.contains(topic))
        .toList();

    // Unsubscribe from removed topics
    if (topicsToRemove.isNotEmpty) {
      mqttService.unsubscribeFromTopics(topicsToRemove);
    }

    // Subscribe to new topics
    if (topicsToAdd.isNotEmpty) {
      mqttService.subscribeToTopics(topicsToAdd);
    }
  }
}
