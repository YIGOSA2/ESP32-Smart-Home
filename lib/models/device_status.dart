// 设备状态数据模型

class DeviceStatus {
  final double temperature;      // 温度(°C)
  final double humidity;         // 湿度(%)
  final bool lightStatus;        // 灯光状态
  final bool fanStatus;          // 风扇状态
  final int gasValue;            // 燃气浓度值
  final int flameValue;          // 火焰传感器值
  final bool alarmStatus;        // 报警状态
  final String weatherTemp;      // 天气温度
  final String weatherText;      // 天气描述
  final DateTime timestamp;      // 时间戳

  DeviceStatus({
    required this.temperature,
    required this.humidity,
    required this.lightStatus,
    required this.fanStatus,
    required this.gasValue,
    required this.flameValue,
    required this.alarmStatus,
    this.weatherTemp = '--',
    this.weatherText = 'Unknown',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // 从JSON解析
  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      humidity: (json['humidity'] ?? 0.0).toDouble(),
      lightStatus: json['light'] ?? false,
      fanStatus: json['fan'] ?? false,
      gasValue: json['gas'] ?? 0,
      flameValue: json['flame'] ?? 0,
      alarmStatus: json['alarm'] ?? false,
      weatherTemp: json['weather_temp']?.toString() ?? '--',
      weatherText: json['weather_text']?.toString() ?? 'Unknown',
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'light': lightStatus,
      'fan': fanStatus,
      'gas': gasValue,
      'flame': flameValue,
      'alarm': alarmStatus,
      'weather_temp': weatherTemp,
      'weather_text': weatherText,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // 判断是否需要报警
  bool get needsAlert {
    // 只根据ESP32发送的alarm_status判断，不再自己判断阈值
    // 这样可以确保与ESP32的报警状态完全同步
    return alarmStatus;
  }

  // 获取报警原因
  String get alertReason {
    List<String> reasons = [];
    if (gasValue > 550) reasons.add('燃气浓度过高');
    if (flameValue < 1000) reasons.add('检测到火焰');
    if (alarmStatus) reasons.add('系统报警');
    return reasons.isEmpty ? '正常' : reasons.join(', ');
  }

  // 复制并修改部分字段
  DeviceStatus copyWith({
    double? temperature,
    double? humidity,
    bool? lightStatus,
    bool? fanStatus,
    int? gasValue,
    int? flameValue,
    bool? alarmStatus,
    String? weatherTemp,
    String? weatherText,
    DateTime? timestamp,
  }) {
    return DeviceStatus(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      lightStatus: lightStatus ?? this.lightStatus,
      fanStatus: fanStatus ?? this.fanStatus,
      gasValue: gasValue ?? this.gasValue,
      flameValue: flameValue ?? this.flameValue,
      alarmStatus: alarmStatus ?? this.alarmStatus,
      weatherTemp: weatherTemp ?? this.weatherTemp,
      weatherText: weatherText ?? this.weatherText,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
