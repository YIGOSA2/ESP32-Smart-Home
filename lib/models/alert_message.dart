// 报警消息数据模型

class AlertMessage {
  final String type;           // 报警类型
  final String message;        // 报警消息
  final String time;           // 时间戳
  final DateTime receivedAt;   // 接收时间

  AlertMessage({
    required this.type,
    required this.message,
    required this.time,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  // 从JSON解析
  factory AlertMessage.fromJson(Map<String, dynamic> json) {
    return AlertMessage(
      type: json['type'] ?? 'unknown',
      message: json['message'] ?? '',
      time: json['time']?.toString() ?? '',
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'message': message,
      'time': time,
      'receivedAt': receivedAt.toIso8601String(),
    };
  }

  // 判断是否为紧急报警
  bool get isUrgent {
    final lowerMsg = message.toLowerCase();
    return lowerMsg.contains('gas') ||
           lowerMsg.contains('flame') ||
           lowerMsg.contains('fire') ||
           lowerMsg.contains('燃气') ||
           lowerMsg.contains('火焰');
  }

  // 获取报警级别
  AlertLevel get level {
    if (isUrgent) return AlertLevel.critical;
    if (message.contains('Invalid') || message.contains('非法')) {
      return AlertLevel.warning;
    }
    return AlertLevel.info;
  }

  // 格式化显示时间
  String get formattedTime {
    try {
      // 尝试解析时间字符串
      if (time.contains('-') && time.contains(':')) {
        return time;
      } else {
        // 如果是毫秒时间戳
        return receivedAt.toString().substring(0, 19);
      }
    } catch (e) {
      return receivedAt.toString().substring(0, 19);
    }
  }
}

// 报警级别枚举
enum AlertLevel {
  info,      // 信息
  warning,   // 警告
  critical,  // 严重
}
