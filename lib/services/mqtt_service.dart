// MQTT通信服务

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/foundation.dart';
import '../constants/mqtt_topics.dart';
import '../models/device_status.dart';
import '../models/alert_message.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  bool _isConnected = false;

  // 状态流控制器
  final StreamController<DeviceStatus> _statusController =
      StreamController<DeviceStatus>.broadcast();
  final StreamController<AlertMessage> _alertController =
      StreamController<AlertMessage>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  // 公开的流
  Stream<DeviceStatus> get statusStream => _statusController.stream;
  Stream<AlertMessage> get alertStream => _alertController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  // 连接状态
  bool get isConnected => _isConnected;

  // 连接到MQTT服务器
  Future<bool> connect({
    required String broker,
    required int port,
    String? clientId,
  }) async {
    try {
      // 如果已连接,先断开
      if (_client != null && _isConnected) {
        await disconnect();
      }

      // 生成客户端ID
      final String finalClientId = clientId ??
          '${MqttTopics.clientIdPrefix}${DateTime.now().millisecondsSinceEpoch}';

      debugPrint('Connecting to MQTT broker: $broker:$port');
      debugPrint('Client ID: $finalClientId');

      // 创建客户端
      _client = MqttServerClient.withPort(broker, finalClientId, port);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 60;
      _client!.connectTimeoutPeriod = 5000; // 5秒超时
      _client!.autoReconnect = true;
      _client!.onAutoReconnect = _onAutoReconnect;
      _client!.onAutoReconnected = _onAutoReconnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;

      // 设置遗嘱消息(可选)
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(finalClientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      _client!.connectionMessage = connMessage;

      // 尝试连接
      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        debugPrint('MQTT connected successfully!');
        _isConnected = true;
        _connectionController.add(true);

        // 订阅主题
        _subscribeToTopics();

        // 设置消息监听
        _client!.updates!.listen(_onMessage);

        return true;
      } else {
        debugPrint('MQTT connection failed: ${_client!.connectionStatus}');
        _isConnected = false;
        _connectionController.add(false);
        return false;
      }
    } catch (e) {
      debugPrint('MQTT connection error: $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  // 订阅主题
  void _subscribeToTopics() {
    if (_client == null || !_isConnected) return;

    debugPrint('Subscribing to topics...');
    _client!.subscribe(MqttTopics.statusTopic, MqttQos.atLeastOnce);
    _client!.subscribe(MqttTopics.alertTopic, MqttQos.atLeastOnce);
    debugPrint('Subscribed to: ${MqttTopics.statusTopic}, ${MqttTopics.alertTopic}');
  }

  // 消息接收处理
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final topic = message.topic;
      final payload = message.payload as MqttPublishMessage;
      final payloadString = MqttPublishPayload.bytesToStringAsString(
        payload.payload.message,
      );

      debugPrint('Received message on topic: $topic');
      debugPrint('Payload: $payloadString');

      try {
        final Map<String, dynamic> json = jsonDecode(payloadString);

        // 根据主题分发消息
        if (topic == MqttTopics.statusTopic) {
          final status = DeviceStatus.fromJson(json);
          _statusController.add(status);
        } else if (topic == MqttTopics.alertTopic) {
          final alert = AlertMessage.fromJson(json);
          _alertController.add(alert);
        }
      } catch (e) {
        debugPrint('Error parsing message: $e');
      }
    }
  }

  // 发送控制指令
  Future<bool> sendControl({
    bool? light,
    bool? fan,
  }) async {
    if (_client == null || !_isConnected) {
      debugPrint('Cannot send control: not connected');
      return false;
    }

    try {
      final Map<String, dynamic> payload = {};
      if (light != null) payload['light'] = light;
      if (fan != null) payload['fan'] = fan;

      final String jsonPayload = jsonEncode(payload);
      debugPrint('Sending control: $jsonPayload');

      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonPayload);

      _client!.publishMessage(
        MqttTopics.controlTopic,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      return true;
    } catch (e) {
      debugPrint('Error sending control: $e');
      return false;
    }
  }

  // 发送WiFi配置指令
  Future<bool> sendWifiConfig({
    required String ssid,
    required String password,
  }) async {
    if (_client == null || !_isConnected) {
      debugPrint('Cannot send WiFi config: not connected');
      return false;
    }

    try {
      final Map<String, dynamic> payload = {
        'ssid': ssid,
        'password': password,
      };

      final String jsonPayload = jsonEncode(payload);
      debugPrint('Sending WiFi config: $jsonPayload');

      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonPayload);

      _client!.publishMessage(
        MqttTopics.wifiConfigTopic,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      return true;
    } catch (e) {
      debugPrint('Error sending WiFi config: $e');
      return false;
    }
  }

  // 连接成功回调
  void _onConnected() {
    debugPrint('MQTT connected callback');
    _isConnected = true;
    _connectionController.add(true);
  }

  // 断开连接回调
  void _onDisconnected() {
    debugPrint('MQTT disconnected callback');
    _isConnected = false;
    _connectionController.add(false);
  }

  // 自动重连回调
  void _onAutoReconnect() {
    debugPrint('MQTT auto reconnecting...');
    _isConnected = false;
    _connectionController.add(false);
  }

  // 自动重连成功回调
  void _onAutoReconnected() {
    debugPrint('MQTT auto reconnected!');
    _isConnected = true;
    _connectionController.add(true);
    _subscribeToTopics();
  }

  // 断开连接
  Future<void> disconnect() async {
    if (_client != null) {
      debugPrint('Disconnecting from MQTT...');
      _client!.disconnect();
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  // 清理资源
  void dispose() {
    disconnect();
    _statusController.close();
    _alertController.close();
    _connectionController.close();
  }
}
