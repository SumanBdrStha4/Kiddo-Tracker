import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:kiddo_tracker/mqtt/MQTTService.dart';
import 'package:kiddo_tracker/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mqtt_client/mqtt_client.dart';

class MQTTTaskHandler extends TaskHandler {
  MQTTService? _mqttService;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>?
  _messageSubscription;
  Timer? _reconnectTimer;
  bool _isRunning = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Initialize notification service for foreground task
    await NotificationService.initialize();

    // Get subscribed topics from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final topics = prefs.getStringList('subscribed_topics') ?? [];

    if (topics.isNotEmpty) {
      _initializeMQTT(topics);
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Periodic event handling
    if (_mqttService != null && _mqttService!.connectionStatus != 'Connected') {
      try {
        await _mqttService!.connect();
      } catch (e) {
        print('Failed to reconnect MQTT in foreground: $e');
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isDestroyed) async {
    _isRunning = false;
    _reconnectTimer?.cancel();
    _messageSubscription?.cancel();
    _mqttService?.disconnect();
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  void _initializeMQTT(List<String> topics) async {
    if (_isRunning) return;

    _isRunning = true;

    _mqttService = MQTTService(
      onMessageReceived: (message) {
        // Handle incoming MQTT messages
        _handleMessage(message);
      },
      onConnectionStatusChanged: (status) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'Kiddo Tracker',
          notificationText: 'Status: $status',
        );
      },
      onLogMessage: (message) {
        // Log messages for debugging
        print('MQTT Foreground: $message');
      },
    );

    try {
      await _mqttService!.connect();
      _mqttService!.subscribeToTopics(topics);

      // Set up message subscription
      _messageSubscription = _mqttService!.client.updates?.listen((updates) {
        for (var update in updates) {
          final message = update.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(
            message.payload.message,
          );
          _handleMessage(payload);
        }
      });
    } catch (e) {
      print('Failed to initialize MQTT in foreground: $e');
      _isRunning = false;
    }
  }

  void _handleMessage(String message) {
    // Process MQTT message and show notification if needed
    try {
      // Parse message and show appropriate notification
      NotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        title: 'Child Location Update',
        body: 'Location data received',
      );
    } catch (e) {
      print('Error handling MQTT message: $e');
    }
  }

  void updateSubscribedTopics(List<String> topics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('subscribed_topics', topics);

    if (_mqttService != null) {
      _mqttService!.subscribeToTopics(topics);
    }
  }
}

// Callback function for starting the foreground task
void startCallback(DateTime timestamp) {
  final handler = MQTTTaskHandler();
  handler.onStart(timestamp, TaskStarter.values.first);
}

// Helper function to start foreground task
Future<void> startMQTTForegroundTask(List<String> topics) async {
  if (await FlutterForegroundTask.isRunningService) {
    // Update existing task
    final handler = MQTTTaskHandler();
    handler.updateSubscribedTopics(topics);
    return;
  }

  // Start new foreground task
  await FlutterForegroundTask.startService(
    notificationTitle: 'Kiddo Tracker',
    notificationText: 'Monitoring child locations...',
    notificationIcon: null,
    notificationButtons: [
      const NotificationButton(id: 'stop_service', text: 'Stop'),
    ],
    callback: startCallback,
  );
}

// Helper function to stop foreground task
Future<void> stopMQTTForegroundTask() async {
  await FlutterForegroundTask.stopService();
}
