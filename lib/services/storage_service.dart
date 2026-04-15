// 本地存储服务

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/door_log.dart';
import '../models/alert_message.dart';

class StorageService {
  static const String _keyMqttBroker = 'mqtt_broker';
  static const String _keyMqttPort = 'mqtt_port';
  static const String _keyDoorLogs = 'door_logs';
  static const String _keyAlertHistory = 'alert_history';
  static const String _keyMaxLogs = 'max_logs';

  static const int maxLogsCount = 100; // 最多保存100条记录

  // 获取SharedPreferences实例
  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  // ==================== MQTT配置 ====================

  // 保存MQTT服务器地址
  Future<void> saveMqttBroker(String broker) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyMqttBroker, broker);
  }

  // 获取MQTT服务器地址
  Future<String?> getMqttBroker() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyMqttBroker);
  }

  // 保存MQTT端口
  Future<void> saveMqttPort(int port) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keyMqttPort, port);
  }

  // 获取MQTT端口
  Future<int?> getMqttPort() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keyMqttPort);
  }

  // ==================== 门禁记录 ====================

  // 保存门禁记录
  Future<void> saveDoorLog(DoorLog log) async {
    final prefs = await _getPrefs();
    List<DoorLog> logs = await getDoorLogs();

    // 添加新记录到列表开头
    logs.insert(0, log);

    // 限制记录数量
    if (logs.length > maxLogsCount) {
      logs = logs.sublist(0, maxLogsCount);
    }

    // 转换为JSON并保存
    final jsonList = logs.map((log) => log.toJson()).toList();
    await prefs.setString(_keyDoorLogs, jsonEncode(jsonList));
  }

  // 获取所有门禁记录
  Future<List<DoorLog>> getDoorLogs() async {
    final prefs = await _getPrefs();
    final jsonString = prefs.getString(_keyDoorLogs);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => DoorLog.fromJson(json)).toList();
    } catch (e) {
      print('Error parsing door logs: $e');
      return [];
    }
  }

  // 清除所有门禁记录
  Future<void> clearDoorLogs() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyDoorLogs);
  }

  // ==================== 报警历史 ====================

  // 保存报警消息
  Future<void> saveAlertMessage(AlertMessage alert) async {
    final prefs = await _getPrefs();
    List<AlertMessage> alerts = await getAlertHistory();

    // 添加新报警到列表开头
    alerts.insert(0, alert);

    // 限制记录数量
    if (alerts.length > maxLogsCount) {
      alerts = alerts.sublist(0, maxLogsCount);
    }

    // 转换为JSON并保存
    final jsonList = alerts.map((alert) => alert.toJson()).toList();
    await prefs.setString(_keyAlertHistory, jsonEncode(jsonList));
  }

  // 获取报警历史
  Future<List<AlertMessage>> getAlertHistory() async {
    final prefs = await _getPrefs();
    final jsonString = prefs.getString(_keyAlertHistory);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => AlertMessage.fromJson(json)).toList();
    } catch (e) {
      print('Error parsing alert history: $e');
      return [];
    }
  }

  // 清除报警历史
  Future<void> clearAlertHistory() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyAlertHistory);
  }

  // ==================== 通用方法 ====================

  // 清除所有数据
  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    await prefs.clear();
  }
}
