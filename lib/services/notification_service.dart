import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String serviceChannelId = 'mqtt_service_channel';
  static const String messageChannelId = 'mqtt_message_channel';
  static const String criticalChannelId = 'mqtt_critical_channel';

  // Map to track recent notifications to prevent duplicates
  static final Map<String, DateTime> _recentNotifications = {};

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  static Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel serviceChannel =
        AndroidNotificationChannel(
          serviceChannelId,
          'MQTT Background Service',
          description: 'Notifications for background MQTT service status',
          importance: Importance.low,
        );

    const AndroidNotificationChannel messageChannel =
        AndroidNotificationChannel(
          messageChannelId,
          'MQTT Messages',
          description: 'Notifications for received MQTT messages',
          importance: Importance.high,
        );

    const AndroidNotificationChannel criticalChannel =
        AndroidNotificationChannel(
          criticalChannelId,
          'Critical MQTT Notifications',
          description: 'Critical notifications requiring immediate attention',
          importance: Importance.max,
        );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(serviceChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(messageChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(criticalChannel);
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String channelId = messageChannelId,
  }) async {
    // Check for duplicate notifications within a short time window (e.g., 5 seconds)
    final key = '$title:$body';
    final now = DateTime.now();
    final lastSent = _recentNotifications[key];
    if (lastSent != null && now.difference(lastSent).inSeconds < 5) {
      return; // Skip duplicate notification
    }
    _recentNotifications[key] = now;

    // Clean up old entries to prevent memory leaks
    _recentNotifications.removeWhere((k, v) => now.difference(v).inMinutes > 1);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelId == serviceChannelId
              ? 'MQTT Background Service'
              : channelId == criticalChannelId
              ? 'Critical MQTT Notifications'
              : 'MQTT Messages',
          importance: channelId == criticalChannelId
              ? Importance.max
              : channelId == messageChannelId
              ? Importance.high
              : Importance.low,
          priority: channelId == criticalChannelId
              ? Priority.max
              : channelId == messageChannelId
              ? Priority.high
              : Priority.low,
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  // Specific method for onboard/offboard notifications
  static Future<void> notifyChildStatus({
    required String childName,
    required bool isOnboard,
  }) async {
    final status = isOnboard ? 'onboarded' : 'offboarded';
    await showNotification(
      id: 0,
      title: 'KT Status Update',
      body: 'Child $childName has been $status.',
    );
  }

  // Specific method for bus activation/deactivation notifications
  static Future<void> notifyBusStatus({
    required String routeName,
    required bool isActivated,
  }) async {
    final status = isActivated ? 'activated' : 'deactivated';
    await showNotification(
      id: 0,
      title: 'KT Status Update',
      body: 'Bus $routeName has been $status.',
    );
  }

  static void showGeneralNotification({required String title, required String body}) {}

  // Consider FCM for critical wake-up scenarios in future implementation
  // TODO: Integrate Firebase Cloud Messaging for push notifications when device is asleep
}
