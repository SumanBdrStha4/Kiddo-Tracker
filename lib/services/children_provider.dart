import 'package:flutter/material.dart';
import 'package:kiddo_tracker/model/child.dart';
import 'package:kiddo_tracker/model/subscribe.dart';
import 'package:kiddo_tracker/mqtt/MQTTService.dart';
import 'package:kiddo_tracker/services/mqtt_task_handler.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChildrenProvider with ChangeNotifier {
  List<Child> _children = [];
  Map<String, SubscriptionPlan> _studentSubscriptions = {};
  List<Map<String, dynamic>> activities = [];
  final SqfliteHelper _sqfliteHelper = SqfliteHelper();
  MQTTService? _mqttService;
  final List<String> _subscribedTopics = [];

  // Granular notifiers for efficient UI updates
  final Map<String, ValueNotifier<Child>> _childNotifiers = {};
  final Map<String, ValueNotifier<SubscriptionPlan?>> _subscriptionNotifiers =
      {};
  final ValueNotifier<Map<String, bool>> _activeRoutesNotifier = ValueNotifier(
    {},
  );
  final ValueNotifier<List<Map<String, dynamic>>> _activitiesNotifier =
      ValueNotifier([]);

  List<Child> get children => _children;
  Map<String, SubscriptionPlan> get studentSubscriptions =>
      _studentSubscriptions;
  List<Map<String, dynamic>> get activitiesList => activities;
  MQTTService? get mqttService => _mqttService;

  Map<String, ValueNotifier<Child>> get childNotifiers => _childNotifiers;
  Map<String, ValueNotifier<SubscriptionPlan?>> get subscriptionNotifiers =>
      _subscriptionNotifiers;
  ValueNotifier<Map<String, bool>> get activeRoutesNotifier =>
      _activeRoutesNotifier;
  ValueNotifier<List<Map<String, dynamic>>> get activitiesNotifier =>
      _activitiesNotifier;

  void setMqttService(MQTTService service) {
    _mqttService = service;
  }

  Future<void> updateChildren() async {
    try {
      final childrenMaps = await _sqfliteHelper.getChildren();
      final subscriptionsMaps = await _sqfliteHelper.getStudentSubscriptions();

      _children = childrenMaps.map((map) => Child.fromJson(map)).toList();
      Logger().i('Children fetched: $_children');
      _studentSubscriptions = {
        for (var map in subscriptionsMaps)
          map['student_id'] as String: SubscriptionPlan.fromJson(map),
      };
      Logger().i('Subscriptions fetched: $_studentSubscriptions');

      // Initialize granular notifiers
      for (var child in _children) {
        _childNotifiers[child.studentId] = ValueNotifier(child);
        _subscriptionNotifiers[child.studentId] = ValueNotifier(
          _studentSubscriptions[child.studentId],
        );
      }

      notifyListeners();
    } catch (e) {
      Logger().e('Error updating children: $e');
    }
  }

  void updateChildOnboardStatus(String studentId, int status) {
    final childIndex = _children.indexWhere(
      (child) => child.studentId == studentId,
    );
    if (childIndex != -1) {
      _children[childIndex] = Child(
        studentId: _children[childIndex].studentId,
        name: _children[childIndex].name,
        nickname: _children[childIndex].nickname,
        school: _children[childIndex].school,
        class_name: _children[childIndex].class_name,
        rollno: _children[childIndex].rollno,
        age: _children[childIndex].age,
        gender: _children[childIndex].gender,
        tagId: _children[childIndex].tagId,
        routeInfo: _children[childIndex].routeInfo,
        tsp_id: _children[childIndex].tsp_id,
        status: _children[childIndex].status,
        onboard_status: status,
      );
      notifyListeners();
    }
  }

  //for first time subscription of topics
  Future<void> subscribeToTopics({MQTTService? mqttService}) async {
    final service = mqttService ?? _mqttService;
    if (service == null) return;

    Set<String> currentTopics = {};
    currentTopics.addAll(_children.map((child) => child.studentId));
    for (var child in _children) {
      currentTopics.addAll(
        child.routeInfo.map((route) => '${route.routeId}/${route.oprId}'),
      );
    }
    service.subscribeToTopics(currentTopics.toList());
    _subscribedTopics.addAll(currentTopics.toList());

    // Save topics to shared preferences and start foreground task
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('subscribed_topics', currentTopics.toList());
    await startMQTTForegroundTask(currentTopics.toList());
  }

  //for newly added child
  Future<void> subscribeToNewStudentTopics(studentId) async {
    final service = _mqttService;
    if (service == null) return;

    _subscribedTopics.add(studentId);
    service.subscribeToTopic(studentId);
  }

  //for newly added route
  Future<void> subscribeToNewRouteTopics(String routeId, int oprId) async {
    final service = _mqttService;
    if (service == null) return;

    final topic = '$routeId/$oprId';
    _subscribedTopics.add(topic);
    service.subscribeToTopic(topic);
  }

  //remove child Route unsubscribe topics
  Future<void> removeChildOrRouteOprid(
    String type,
    String studentId, {
    MQTTService? mqttService,
  }) async {
    final service = mqttService ?? _mqttService;
    if (service == null) return;

    // Find the child to remove
    final childIndex = _children.indexWhere(
      (child) => child.studentId == studentId,
    );
    if (childIndex == -1) return;

    final childToRemove = _children[childIndex];
    Set<String> topicsToUnsubscribe = {};
    // Calculate topics to unsubscribe
    if (type == 'child') {
      topicsToUnsubscribe = {childToRemove.studentId};
    } else {
      topicsToUnsubscribe.addAll(
        childToRemove.routeInfo.map(
          (route) => '${route.routeId}/${route.oprId}',
        ),
      );
    }
    // Remove child from list
    // _children.removeAt(childIndex);

    // Unsubscribe from removed topics
    service.unsubscribeFromTopics(topicsToUnsubscribe.toList());

    // Re-subscribe to remaining topics

    // Update database if needed (assuming SqfliteHelper has a delete method)
    // await _sqfliteHelper.deleteChild(studentId);

    notifyListeners();
  }

  void updateActiveRoutes(String key, bool isActive) {
    _activeRoutesNotifier.value = Map.from(_activeRoutesNotifier.value)
      ..[key] = isActive;
  }

  Future<void> updateActivity() async {
    try {
      final activityMaps = await _sqfliteHelper.getActivities();
      activities = activityMaps.map((map) => map).toList();
      _activitiesNotifier.value = activities;
      notifyListeners();
    } catch (e) {
      Logger().e('Error updating children: $e');
    }
  }
}
