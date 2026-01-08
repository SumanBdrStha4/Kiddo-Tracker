// import 'dart:async';
// import 'package:kiddo_tracker/mqtt/MQTTService.dart';
// import 'package:kiddo_tracker/routes/routes.dart';
// import 'package:kiddo_tracker/services/notification_service.dart';
// import 'package:logger/logger.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:mqtt_client/mqtt_client.dart';

// class MQTTTaskHandler extends TaskHandler {
//   MQTTService? _mqttService;
//   StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>?
//   _messageSubscription;
//   bool _isRunning = false;

//   @override
//   Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
//     Logger().i('MQTTTaskHandler onStart called at $timestamp');
//     // Initialize notification service for foreground task
//     // await NotificationService.initialize();

//     // Get subscribed topics from shared preferences
//     final prefs = await SharedPreferences.getInstance();
//     final topics = prefs.getStringList('subscribed_topics') ?? [];

//     if (topics.isNotEmpty) {
//       _initializeMQTT(topics);
//     }
//   }

//   @override
//   Future<void> onRepeatEvent(DateTime timestamp) async {
//     // Periodic event handling
//     // if (_mqttService != null && _mqttService!.connectionStatus != 'Connected') {
//     //   try {
//     //     await _mqttService!.connect();
//     //   } catch (e) {
//     //     print('Failed to reconnect MQTT in foreground: $e');
//     //   }
//     // }
//     //for not
//     Logger().d('MQTT Foreground Task repeating at $timestamp');
//     if (_mqttService == null || !_isRunning) {
//       // Get subscribed topics from shared preferences
//       final prefs = await SharedPreferences.getInstance();
//       final topics = prefs.getStringList('subscribed_topics') ?? [];

//       if (topics.isNotEmpty) {
//         _initializeMQTT(topics);
//       }
//     }
//   }

//   @override
//   Future<void> onDestroy(DateTime timestamp, bool isDestroyed) async {
//     Logger().i(
//       'MQTTTaskHandler onDestroy called at $timestamp, isDestroyed: $isDestroyed',
//     );
//     _isRunning = false;
//     await _messageSubscription?.cancel();
//     _mqttService?.disconnect();
//   }

//   @override
//   void onNotificationPressed() {
//     FlutterForegroundTask.launchApp();
//   }

//   void _initializeMQTT(List<String> topics) async {
//     // if (_isRunning) return;

//     // _isRunning = true;
//     try {
//       _mqttService ??= MQTTService(
//         onMessageReceived: (message) {
//           // Handle incoming MQTT messages
//           _handleMessage(message);
//         },
//         onConnectionStatusChanged: (status) {
//           _isRunning = status == 'Connected';
//           FlutterForegroundTask.updateService(
//             notificationTitle: 'Kiddo Tracker',
//             notificationText: 'Status: $status',
//           );
//         },
//         onLogMessage: (message) {
//           // Log messages for debugging
//           print('MQTT Foreground: $message');
//         },
//       );
//     } catch (e) {
//       print('Error initializing MQTTService: $e');
//       return;
//     }

//     try {
//       await _mqttService!.connect();
//       _mqttService!.subscribeToTopics(topics);

//       // Set up message subscription
//       _messageSubscription ??= _mqttService!.client.updates?.listen((updates) {
//         for (var update in updates) {
//           final message = update.payload as MqttPublishMessage;
//           final payload = MqttPublishPayload.bytesToStringAsString(
//             message.payload.message,
//           );
//           _handleMessage(payload);
//         }
//       });
//     } catch (e) {
//       print('Failed to initialize MQTT in foreground: $e');
//       _isRunning = false;
//     }
//   }

//   void _handleMessage(String message) {
//     // Process MQTT message and show notification if needed
//     try {
//       // Parse message and show appropriate notification
//       NotificationService.showNotification(
//         id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
//         title: 'Child Location Update',
//         body: message,
//       );
//     } catch (e) {
//       print('Error handling MQTT message: $e');
//     }
//   }

//   void updateSubscribedTopics(List<String> topics) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setStringList('subscribed_topics', topics);

//     if (_mqttService != null) {
//       _mqttService!.subscribeToTopics(topics);
//     }
//   }

//   void onNotificationButtonClick(String id) {
//     if (id == 'stop_service') {
//       FlutterForegroundTask.stopService();
//       Logger().i('MQTT foreground task stopped via notification button');
//     }
//   }
// }

// // Callback function for starting the foreground task
// @pragma('vm:entry-point')
// void startCallback(DateTime timestamp) {
//   // final handler = MQTTTaskHandler();
//   // handler.onStart(timestamp, TaskStarter.values.first);
//   FlutterForegroundTask.setTaskHandler(MQTTTaskHandler());
// }

// Future<void> updateSubscribedTopics(List<String> topics) async {
//   final prefs = await SharedPreferences.getInstance();
//   await prefs.setStringList('subscribed_topics', topics);
// }

// // Helper function to start foreground task
// Future<void> startMQTTForegroundTask(List<String> topics) async {
//   // if (await FlutterForegroundTask.isRunningService) {
//   //   // Update existing task
//   //   final handler = MQTTTaskHandler();
//   //   handler.updateSubscribedTopics(topics);
//   //   Logger().i('Updated MQTT foreground task with topics: $topics');
//   //   return;
//   // }

//   // Start new foreground task
//   await FlutterForegroundTask.startService(
//     notificationTitle: 'Kiddo Tracker',
//     notificationText: 'Monitoring child Status...',
//     notificationIcon: null,
//     notificationButtons: [
//       const NotificationButton(id: 'stop_service', text: 'Stop'),
//     ],
//     notificationInitialRoute: AppRoutes.main,
//     callback: startCallback,
//   );
//   Logger().i('Started MQTT foreground task with topics: $topics');
// }

// Future<void> requestBatteryOptimization() async {
//   try {
//     await FlutterForegroundTask.requestIgnoreBatteryOptimization();
//   } catch (e) {
//     print("Error while requesting ignore battery optimization: $e");
//   }
// }
