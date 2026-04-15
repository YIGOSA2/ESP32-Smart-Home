// 本地通知服务

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // 初始化通知服务
  Future<void> initialize() async {
    if (_initialized) return;

    // Android初始化设置
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS初始化设置
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 组合初始化设置
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 初始化插件
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 请求Android 13+的通知权限
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  // 通知点击回调
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // 这里可以添加导航逻辑
  }

  // 显示普通通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'smart_home_channel',
      'Smart Home Notifications',
      channelDescription: 'Notifications for smart home events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  // 显示紧急报警通知(带声音和震动)
  Future<void> showAlertNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'smart_home_alert_channel',
      'Smart Home Alerts',
      channelDescription: 'Critical alerts for smart home safety',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alert'),
      // 使用默认声音,如果需要自定义声音,需要添加音频文件
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'alert.aiff', // iOS自定义声音
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 使用时间戳作为ID,确保每个报警都能显示
    final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _notifications.show(id, title, body, details, payload: payload);
  }

  // 显示燃气报警
  Future<void> showGasAlert(int gasValue) async {
    await showAlertNotification(
      title: '⚠️ 燃气浓度警告',
      body: '检测到燃气浓度过高! 当前值: $gasValue',
      payload: 'gas_alert',
    );
  }

  // 显示火焰报警
  Future<void> showFlameAlert(int flameValue) async {
    await showAlertNotification(
      title: '🔥 火焰检测警告',
      body: '检测到火焰信号! 当前值: $flameValue',
      payload: 'flame_alert',
    );
  }

  // 显示门禁报警
  Future<void> showDoorAlert(String message) async {
    await showAlertNotification(
      title: '🚪 门禁警告',
      body: message,
      payload: 'door_alert',
    );
  }

  // 显示系统通知
  Future<void> showSystemNotification(String message) async {
    await showNotification(
      id: 0,
      title: '智能家居系统',
      body: message,
      payload: 'system',
    );
  }

  // 取消指定通知
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  // 取消所有通知
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
