import 'package:logger/logger.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  late MqttServerClient client;
  String connectionStatus = 'Disconnected';
  List<String> messages = [];
  final Function(String) onMessageReceived;
  final Function(String) onConnectionStatusChanged;
  final Function(String) onLogMessage;

  List<String> subscribedTopics = [];

  MQTTService({
    required this.onMessageReceived,
    required this.onConnectionStatusChanged,
    required this.onLogMessage,
  });

  Future<void> connect() async {
    client = MqttServerClient.withPort(
      '172.235.25.172',
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
      1883,
    );

    client.logging(on: true);
    client.keepAlivePeriod = 60;
    client.autoReconnect = true;
    client.onAutoReconnect = onAutoReconnect;
    client.onAutoReconnected = onAutoReconnected;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onUnsubscribed = onUnsubscribed;
    client.onSubscribed = onSubscribed;
    client.onSubscribeFail = onSubscribeFail;
    client.pongCallback = pong;

    final connMess = MqttConnectMessage()
        .authenticateAs("", "")
        .withWillTopic('willtopic')
        .withWillMessage('My Will message')
        .startClean()
        .withWillQos(MqttQos.exactlyOnce);
    client.connectionMessage = connMess;

    try {
      onConnectionStatusChanged('Connecting...');
      await client.connect();
    } catch (e) {
      onConnectionStatusChanged('Connection failed: $e');
      client.disconnect();
      return;
    }

    // Subscribe to all topics after successful connection
    for (var topic in subscribedTopics) {
      Logger().i("/kiddotrac/$topic");
      client.subscribe("/kiddotrac/$topic", MqttQos.exactlyOnce);
    }
    onConnectionStatusChanged('Connected');

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final MqttPublishMessage recMessage = c![0].payload as MqttPublishMessage;
      final String payload = MqttPublishPayload.bytesToStringAsString(
        recMessage.payload.message,
      );

      onMessageReceived(payload);
      onLogMessage('Received message: $payload from topic: ${c[0].topic}');
    });
  }

  void onConnected() {
    // Subscribe to all topics on connection
    for (var topic in subscribedTopics) {
      client.subscribe("/kiddotrac/$topic", MqttQos.exactlyOnce);
    }
    onConnectionStatusChanged('Connected');
  }

  void onDisconnected() {
    onConnectionStatusChanged('Disconnected');
  }

  void onAutoReconnect() {
    onLogMessage('Client auto reconnection sequence will start');
  }

  void onAutoReconnected() {
    onLogMessage('Client auto reconnection sequence has completed');
    onConnectionStatusChanged('Auto Connected');
  }

  void onSubscribed(String topic) {
    onLogMessage('Subscribed topic: $topic');
  }

  void onSubscribeFail(String topic) {
    onLogMessage('Failed to subscribe $topic');
  }

  void onUnsubscribed(String? topic) {
    onLogMessage('Unsubscribed topic: $topic');
  }

  void pong() {
    // onLogMessage('Ping response client callback invoked');
  }

  void disconnect() {
    client.disconnect();
  }

  //subscribe to multiple topics
  void subscribeToTopics(List<String> topics) {
    subscribedTopics = topics;
    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      for (var topic in topics) {
        client.subscribe("/kiddotrac/$topic", MqttQos.exactlyOnce);
        onLogMessage('Subscribed to topic: $topic');
      }
    }
  }

  //subscribe to single topic
  void subscribeToTopic(String topic) {
    subscribedTopics.add(topic);
    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      client.subscribe("/kiddotrac/$topic", MqttQos.exactlyOnce);
      onLogMessage('Subscribed to topic: $topic');
    }
  }

  //unsubscribe to all it has
  // void unsubscribeFromAllTopics() {
  //   for (var topic in subscribedTopics) {
  //     client.unsubscribe("/kiddotrac/$topic");
  //     onLogMessage('Unsubscribed from topic: $topic');
  //   }
  // }

  //unsubscribe from specific topics
  void unsubscribeFromTopics(List<String> topics) {
    for (var topic in topics) {
      client.unsubscribe("/kiddotrac/$topic");
      onLogMessage('Unsubscribed from topic: $topic');
    }
  }
}
