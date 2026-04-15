// 设置管理Provider

import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../constants/mqtt_topics.dart';

class SettingsProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();

  // MQTT配置
  String _mqttBroker = MqttTopics.defaultBroker;
  int _mqttPort = MqttTopics.defaultPort;

  String get mqttBroker => _mqttBroker;
  int get mqttPort => _mqttPort;

  // 主题模式
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // 初始化
  Future<void> initialize() async {
    debugPrint('SettingsProvider initializing...');

    // 加载保存的MQTT配置
    final savedBroker = await _storageService.getMqttBroker();
    final savedPort = await _storageService.getMqttPort();

    if (savedBroker != null) {
      _mqttBroker = savedBroker;
    }
    if (savedPort != null) {
      _mqttPort = savedPort;
    }

    debugPrint('Loaded MQTT config: $_mqttBroker:$_mqttPort');
    notifyListeners();
  }

  // 更新MQTT服务器地址
  Future<void> updateMqttBroker(String broker) async {
    _mqttBroker = broker;
    await _storageService.saveMqttBroker(broker);
    notifyListeners();
  }

  // 更新MQTT端口
  Future<void> updateMqttPort(int port) async {
    _mqttPort = port;
    await _storageService.saveMqttPort(port);
    notifyListeners();
  }

  // 切换主题模式
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // 重置为默认配置
  Future<void> resetToDefaults() async {
    _mqttBroker = MqttTopics.defaultBroker;
    _mqttPort = MqttTopics.defaultPort;
    await _storageService.saveMqttBroker(_mqttBroker);
    await _storageService.saveMqttPort(_mqttPort);
    notifyListeners();
  }
}
