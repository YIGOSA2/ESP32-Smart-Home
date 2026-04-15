// 设备状态管理Provider

import 'package:flutter/foundation.dart';
import '../models/device_status.dart';
import '../models/alert_message.dart';
import '../models/door_log.dart';
import '../services/mqtt_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class DeviceProvider with ChangeNotifier {
  final MqttService _mqttService = MqttService();
  final NotificationService _notificationService = NotificationService();
  final StorageService _storageService = StorageService();

  // 设备状态
  DeviceStatus? _currentStatus;
  DeviceStatus? get currentStatus => _currentStatus;

  // 连接状态
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // 报警历史
  List<AlertMessage> _alertHistory = [];
  List<AlertMessage> get alertHistory => _alertHistory;

  // 门禁记录
  List<DoorLog> _doorLogs = [];
  List<DoorLog> get doorLogs => _doorLogs;

  // 天气信息(从ESP32同步)
  String _weatherTemp = '--';
  String _weatherText = 'Unknown';
  String get weatherTemp => _weatherTemp;
  String get weatherText => _weatherText;

  // 初始化
  Future<void> initialize() async {
    debugPrint('DeviceProvider initializing...');

    // 初始化通知服务
    await _notificationService.initialize();

    // 加载本地存储的历史数据
    _alertHistory = await _storageService.getAlertHistory();
    _doorLogs = await _storageService.getDoorLogs();

    // 监听MQTT消息流
    _mqttService.statusStream.listen(_onStatusUpdate);
    _mqttService.alertStream.listen(_onAlertReceived);
    _mqttService.connectionStream.listen(_onConnectionChanged);

    debugPrint('DeviceProvider initialized');
  }

  // 连接到MQTT服务器
  Future<bool> connect(String broker, int port) async {
    debugPrint('Connecting to MQTT: $broker:$port');
    final success = await _mqttService.connect(
      broker: broker,
      port: port,
    );

    if (success) {
      debugPrint('MQTT connected successfully');
    } else {
      debugPrint('MQTT connection failed');
    }

    return success;
  }

  // 断开MQTT连接
  Future<void> disconnect() async {
    await _mqttService.disconnect();
  }

  // 状态更新回调
  void _onStatusUpdate(DeviceStatus status) {
    debugPrint('Status update received');
    _currentStatus = status;

    // 更新天气信息
    _weatherTemp = status.weatherTemp;
    _weatherText = status.weatherText;

    // 检查是否需要报警通知
    if (status.needsAlert) {
      _handleAlert(status);
    }

    notifyListeners();
  }

  // 报警消息回调
  void _onAlertReceived(AlertMessage alert) {
    debugPrint('Alert received: ${alert.message}');

    // 添加到历史记录
    _alertHistory.insert(0, alert);
    if (_alertHistory.length > 100) {
      _alertHistory = _alertHistory.sublist(0, 100);
    }

    // 保存到本地存储
    _storageService.saveAlertMessage(alert);

    // 显示通知
    _showAlertNotification(alert);

    // 检查是否为门禁相关报警
    if (alert.message.contains('Door') || alert.message.contains('card')) {
      _handleDoorLog(alert);
    }

    notifyListeners();
  }

  // 连接状态变化回调
  void _onConnectionChanged(bool connected) {
    debugPrint('Connection status changed: $connected');
    _isConnected = connected;

    if (connected) {
      _notificationService.showSystemNotification('已连接到智能家居系统');
    } else {
      _notificationService.showSystemNotification('与智能家居系统断开连接');
    }

    notifyListeners();
  }

  // 处理报警
  void _handleAlert(DeviceStatus status) {
    if (status.gasValue > 550) {
      _notificationService.showGasAlert(status.gasValue);
    }
    if (status.flameValue < 1000) {
      _notificationService.showFlameAlert(status.flameValue);
    }
  }

  // 显示报警通知
  void _showAlertNotification(AlertMessage alert) {
    if (alert.isUrgent) {
      _notificationService.showAlertNotification(
        title: '⚠️ 紧急报警',
        body: alert.message,
      );
    } else if (alert.message.contains('Invalid') || alert.message.contains('非法')) {
      _notificationService.showDoorAlert(alert.message);
    } else {
      _notificationService.showSystemNotification(alert.message);
    }
  }

  // 处理门禁记录
  void _handleDoorLog(AlertMessage alert) {
    final doorLog = DoorLog.fromAlertMessage(
      alert.message,
      alert.receivedAt,
    );

    _doorLogs.insert(0, doorLog);
    if (_doorLogs.length > 100) {
      _doorLogs = _doorLogs.sublist(0, 100);
    }

    _storageService.saveDoorLog(doorLog);
  }

  // 控制灯光
  Future<bool> controlLight(bool on) async {
    debugPrint('Controlling light: $on');
    return await _mqttService.sendControl(light: on);
  }

  // 控制风扇
  Future<bool> controlFan(bool on) async {
    debugPrint('Controlling fan: $on');
    return await _mqttService.sendControl(fan: on);
  }

  // 场景模式：全部关闭
  Future<void> sceneAllOff() async {
    debugPrint('Scene: All Off');
    await _mqttService.sendControl(light: false, fan: false);
  }

  // 场景模式：离家模式
  Future<void> sceneLeaveHome() async {
    debugPrint('Scene: Leave Home');
    await _mqttService.sendControl(light: false, fan: false);
    _notificationService.showSystemNotification('已启动离家模式');
  }

  // 场景模式：回家模式
  Future<void> sceneArriveHome() async {
    debugPrint('Scene: Arrive Home');
    await _mqttService.sendControl(light: true, fan: false);
    _notificationService.showSystemNotification('欢迎回家！');
  }

  // 发送WiFi配置
  Future<bool> sendWifiConfig(String ssid, String password) async {
    debugPrint('Sending WiFi config: $ssid');
    return await _mqttService.sendWifiConfig(
      ssid: ssid,
      password: password,
    );
  }

  // 清除报警历史
  Future<void> clearAlertHistory() async {
    _alertHistory.clear();
    await _storageService.clearAlertHistory();
    notifyListeners();
  }

  // 清除门禁记录
  Future<void> clearDoorLogs() async {
    _doorLogs.clear();
    await _storageService.clearDoorLogs();
    notifyListeners();
  }

  @override
  void dispose() {
    _mqttService.dispose();
    super.dispose();
  }
}
