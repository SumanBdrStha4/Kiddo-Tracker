import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kiddo_tracker/mqtt/MQTTService.dart';
import 'package:kiddo_tracker/services/mqtt_message_handler.dart';
import 'package:kiddo_tracker/services/notification_service.dart';
import 'package:kiddo_tracker/services/permission_service.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:shared_preferences/shared_preferences.dart';

const notificationChannelId = 'mqtt_service_channel';
const notificationId = 888;

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize notification service for background
  await NotificationService.initialize();

  // Get subscribed topics from shared preferences
  final prefs = await SharedPreferences.getInstance();
  final subscribedTopics = prefs.getStringList('subscribed_topics') ?? [];

  if (subscribedTopics.isEmpty) {
    service.stopSelf();
    return;
  }

  // Initialize SqfliteHelper for background
  final sqfliteHelper = SqfliteHelper();

  // Initialize MQTT Service for background
  final mqttService = MQTTService(
    onMessageReceived: (message) async {
      await MQTTMessageHandler.handleMQTTMessage(message, sqfliteHelper);
    },
    onConnectionStatusChanged: (status) {
      // Update service notification with connection status
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'MQTT Background Service',
          content: 'Status: $status',
        );
      }
    },
    onLogMessage: (log) {
      // Log background service messages
      print('Background MQTT: $log');
    },
  );

  // Connect to MQTT
  await mqttService.connect();

  // Subscribe to topics
  mqttService.subscribeToTopics(subscribedTopics);

  // Set up foreground notification for Android
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    // service.setForegroundNotificationInfo(
    //   title: 'MQTT Background Service',
    //   content: 'Monitoring location updates',
    // );
  }

  // Listen for service stop commands
  service.on('stopService').listen((event) {
    mqttService.disconnect();
    service.stopSelf();
  });

  // Keep service alive
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    // Check if service should still be running
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Service is running in foreground
        await flutterLocalNotificationsPlugin.show(
          notificationId,
          'MQTT Background Service',
          'Service is running',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannelId,
              'MQTT Background Service',
              channelDescription: 'Handles MQTT messages in background',
              importance: Importance.low,
              priority: Priority.low,
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );
      }
    }
    final currentTopics = prefs.getStringList('subscribed_topics') ?? [];
    if (currentTopics.isEmpty) {
      timer.cancel();
      mqttService.disconnect();
      service.stopSelf();
    }
  });
}

// Helper functions for handling MQTT messages in background
// Future<void> _handleOnboardMessage(
//   Map<String, dynamic> data,
//   Map<String, dynamic> jsonMessage,
//   SqfliteHelper sqfliteHelper,
// ) async {
//   final String? studentId = data['studentid'] as String?;
//   final int status = data['status'] as int? ?? 1; // Default to onboard

//   if (studentId != null) {
//     final children = await sqfliteHelper.getChildren();
//     _updateChildStatus(studentId, status, jsonMessage, children, sqfliteHelper);
//   }
// }

// void _updateChildStatus(
//   String studentId,
//   int status,
//   Map<String, dynamic> jsonMessage,
//   List<Map<String, dynamic>> children,
//   SqfliteHelper sqfliteHelper,
// ) async {
//   // Fetch child name from DB

//   final child = children.cast<Map<String, dynamic>>().firstWhere(
//     (c) => c['student_id'] == studentId,
//     orElse: () => <String, dynamic>{},
//   );
//   if (child.isNotEmpty) {
//     final childName = child['name'] as String;
//     // Show notification
//     await NotificationService.notifyChildStatus(
//       childName: childName,
//       isOnboard: status == 1,
//     );
//     // Save to database
//     final onBoardLocation = status == 1 ? jsonMessage['data']['location'] : '';
//     final offBoardLocation = status == 2 ? jsonMessage['data']['location'] : '';
//     await sqfliteHelper.insertActivity({
//       'student_id': studentId,
//       'student_name': childName,
//       'status': status == 1 ? 'onboarded' : 'offboarded',
//       'on_location': onBoardLocation,
//       'off_location': offBoardLocation,
//       'route_id': jsonMessage['devid'].split('_')[0],
//       'oprid': jsonMessage['devid'].split('_')[1],
//     });
//     // Update child status in child
//   }
// }

// Future<void> _handleOffboardMessage(
//   Map<String, dynamic> data,
//   Map<String, dynamic> jsonMessage,
//   SqfliteHelper sqfliteHelper,
// ) async {
//   final List<dynamic>? offlist = data['offlist'] as List<dynamic>?;

//   if (offlist != null) {
//     final children = await sqfliteHelper.getChildren();
//     for (var id in offlist) {
//       if (id is String) {
//         _updateChildStatus(
//           id,
//           2,
//           jsonMessage,
//           children,
//           sqfliteHelper,
//         ); // Offboard status
//         // final child = children.cast<Map<String, dynamic>>().firstWhere(
//         //   (c) => c['student_id'] == id,
//         //   orElse: () => <String, dynamic>{},
//         // );
//         // if (child.isNotEmpty) {
//         //   final childName = child['name'] as String;
//         //   // Show notification
//         //   await NotificationService.notifyChildStatus(
//         //     childName: childName,
//         //     isOnboard: false,
//         //   );
//         //   // Save to database
//         //   await sqfliteHelper.insertActivity({
//         //     'student_id': id,
//         //     'student_name': childName,
//         //     'status': 'offboarded',
//         //     'on_location': '',
//         //     'off_location': jsonMessage['data']['location'],
//         //     'route_id': jsonMessage['devid'].split('_')[0],
//         //     'oprid': jsonMessage['devid'].split('_')[1],
//         //   });
//         // }
//       }
//     }
//   }
// }

// Future<void> _handleBusStatusMessage(
//   int? msgtype,
//   Map<String, dynamic> jsonMessage,
//   SqfliteHelper sqfliteHelper,
// ) async {
//   String devid = jsonMessage['devid'] ?? '';
//   if (devid.isNotEmpty) {
//     final parts = devid.split('_');
//     if (parts.length == 2) {
//       final routeId = parts[0];
//       final oprId = parts[1];
//       // Fetch route name from DB
//       final routes = await sqfliteHelper.getStopListByOprIdAndRouteId(
//         oprId,
//         routeId,
//       );
//       String routeName = 'Route $routeId';
//       if (routes.isNotEmpty) {
//         final stopListStr = routes.first['stop_list'] as String?;
//         if (stopListStr != null) {
//           try {
//             final stopList = jsonDecode(stopListStr) as List<dynamic>;
//             if (stopList.isNotEmpty) {
//               routeName = stopList.first['route_name'] ?? routeName;
//             }
//           } catch (e) {
//             print('Error parsing stop_list: $e');
//           }
//         }
//       }
//       // Show notification
//       await NotificationService.notifyBusStatus(
//         routeName: routeName,
//         isActivated: msgtype == 1,
//       );
//       // update the provider
//       // if (msgtype == 1) {
//       //   provider.updateActiveRoutes(key, true);
//       // } else if (msgtype == 4) {
//       //   provider.updateActiveRoutes(key, false);
//       // }
//     }
//   }
// }

class BackgroundService {
  static Future<void> initialize() async {
    // Request ignore battery optimizations permission
    await PermissionService.requestIgnoreBatteryOptimizations();

    // Initialize notification service first to create channels
    await NotificationService.initialize();

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'MQTT Background Service',
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId: notificationId,
        autoStartOnBoot: true,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  }

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
}
