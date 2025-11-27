import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';

@pragma('vm:entry-point')
void alarmCallback() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    // Initialize notification service for background tasks
    await NotificationService.initialize();

    print('Alarm triggered for daily data load');
    // final result = await ChildrenService().fetchChildren();
    // if (result['success'] == true) {
    await NotificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Children Data Updated',
      body: 'Children data has been fetched successfully in the background.',
    );
    // }
  } catch (e) {
    print('Error in alarm callback: $e');
  }
}

// Function to schedule daily data load at the stored time
Future<void> scheduleDailyDataLoad(int hour, int minute) async {
  print(
    'Scheduling daily data load at $hour:$minute using AndroidAlarmManager',
  );

  final now = DateTime.now();
  DateTime nextTrigger = DateTime(now.year, now.month, now.day, hour, minute);

  if (nextTrigger.isBefore(now)) {
    nextTrigger = nextTrigger.add(const Duration(days: 1));
  }

  await AndroidAlarmManager.oneShotAt(
    nextTrigger,
    0,
    alarmCallback,
    exact: true,
    wakeup: true,
  );
  print("Exact alarm scheduled for $nextTrigger");
}

@pragma('vm:entry-point')
void workmanagerDispatcher() {
  Workmanager().executeTask((task, input) async {
    print("🔄 Workmanager running — resetting tomorrow's alarm");

    // Retrieve the stored hour and minute from shared preferences
    final hour = await SharedPreferenceHelper.getEarliestRouteHour() ?? 6;
    final minute = await SharedPreferenceHelper.getEarliestRouteMinute() ?? 15;

    await scheduleDailyDataLoad(hour, minute);

    return Future.value(true);
  });
}
