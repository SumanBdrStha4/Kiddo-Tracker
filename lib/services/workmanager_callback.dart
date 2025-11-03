import 'package:workmanager/workmanager.dart';
import 'children_service.dart';
import 'notification_service.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('Background task triggered: $task');
      if (task == 'fetchChildren') {
        print('Executing fetchChildren task in background');
        // final result = await ChildrenService().fetchChildren();
        // if (result['success'] == true) {
        await NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Children Data Updated',
          body:
              'Children data has been fetched successfully in the background.',
        );
        // }
      }
      return Future.value(true);
    } catch (e) {
      print('Error in background fetch: $e');
      return Future.value(false);
    }
  });
}

// Function to schedule daily data load at the stored time
Future<void> scheduleDailyDataLoad() async {
  //the working
  final hour = await SharedPreferenceHelper.getEarliestRouteHour();
  final minute = await SharedPreferenceHelper.getEarliestRouteMinute();
  if (hour != null && minute != null) {
    print('Scheduling daily data load at $hour:$minute');
    await Workmanager().registerPeriodicTask(
      'dailyDataLoad',
      'fetchChildren',
      frequency: const Duration(days: 1),
      initialDelay: _calculateInitialDelay(hour, minute),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  // For testing: Schedule one-off task at the stored time or default 13:18
  final triggerHour = 14;
  final triggerMinute = 37;

  final now = DateTime.now();
  DateTime firstTrigger = DateTime(
    now.year,
    now.month,
    now.day,
    triggerHour,
    triggerMinute,
  );

  if (firstTrigger.isBefore(now)) {
    firstTrigger = firstTrigger.add(const Duration(days: 1));
  }

  final delay = firstTrigger.difference(now);

  await Workmanager().registerOneOffTask(
    "fetchChildrenOneOff",
    "fetchChildren",
    initialDelay: delay,
    existingWorkPolicy: ExistingWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.connected),
  );

  // For production: Uncomment the daily periodic task above and remove this 15-minute test task
  // print('One-off task scheduled successfully');
}

Duration _calculateInitialDelay(int hour, int minute) {
  final now = DateTime.now();
  final scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
  if (scheduledTime.isBefore(now)) {
    // If the time has passed today, schedule for tomorrow
    return scheduledTime.add(const Duration(days: 1)).difference(now);
  } else {
    return scheduledTime.difference(now);
  }
}
