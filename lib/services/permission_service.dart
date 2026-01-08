import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestNotificationPermission() async {
    if (await Permission.notification.isGranted) {
      return;
    }

    final status = await Permission.notification.request();
    if (status.isGranted) {
      // Permission granted
    } else if (status.isDenied) {
      // Permission denied
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied
    }
  }

  static Future<void> requestLocationPermission() async {
    if (await Permission.location.isGranted) {
      return;
    }

    final status = await Permission.location.request();
    if (status.isGranted) {
      // Permission granted
    } else if (status.isDenied) {
      // Permission denied
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied
    }
  }

  static Future<void> requestExactAlarmPermission() async {
    if (await Permission.scheduleExactAlarm.isGranted) {
      return;
    }

    final status = await Permission.scheduleExactAlarm.request();
    if (status.isGranted) {
      // Permission granted
    } else if (status.isDenied) {
      // Permission denied
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (await Permission.ignoreBatteryOptimizations.isGranted) {
      return;
    }

    final status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isGranted) {
      // Permission granted
    } else if (status.isDenied) {
      // Permission denied
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied
    }
  }
}
