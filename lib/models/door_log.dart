// 门禁记录数据模型

class DoorLog {
  final String cardUid;        // 卡片UID
  final bool isValid;          // 是否为有效卡片
  final DateTime timestamp;    // 时间戳
  final String action;         // 操作类型(opened/denied)

  DoorLog({
    required this.cardUid,
    required this.isValid,
    required this.timestamp,
    required this.action,
  });

  // 从报警消息解析门禁记录
  factory DoorLog.fromAlertMessage(String message, DateTime timestamp) {
    bool isValid = false;
    String action = 'denied';
    String cardUid = 'Unknown';

    // 解析消息提取卡片UID
    if (message.contains('opened by card:')) {
      isValid = true;
      action = 'opened';
      final parts = message.split('opened by card:');
      if (parts.length > 1) {
        cardUid = parts[1].trim();
      }
    } else if (message.contains('Invalid RFID card! UID:')) {
      isValid = false;
      action = 'denied';
      final parts = message.split('UID:');
      if (parts.length > 1) {
        cardUid = parts[1].trim();
      }
    } else if (message.contains('Door')) {
      // 其他门相关消息
      action = message.contains('locked') ? 'locked' : 'opened';
      isValid = true;
      cardUid = 'System';
    }

    return DoorLog(
      cardUid: cardUid,
      isValid: isValid,
      timestamp: timestamp,
      action: action,
    );
  }

  // 从JSON解析
  factory DoorLog.fromJson(Map<String, dynamic> json) {
    return DoorLog(
      cardUid: json['cardUid'] ?? 'Unknown',
      isValid: json['isValid'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
      action: json['action'] ?? 'unknown',
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'cardUid': cardUid,
      'isValid': isValid,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
    };
  }

  // 格式化显示时间
  String get formattedTime {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-'
           '${timestamp.day.toString().padLeft(2, '0')} '
           '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}:'
           '${timestamp.second.toString().padLeft(2, '0')}';
  }

  // 获取操作描述
  String get actionDescription {
    switch (action) {
      case 'opened':
        return '开门成功';
      case 'denied':
        return '拒绝访问';
      case 'locked':
        return '自动上锁';
      default:
        return '未知操作';
    }
  }

  // 获取状态图标
  String get statusIcon {
    if (isValid) {
      return action == 'opened' ? '✓' : '🔒';
    } else {
      return '✗';
    }
  }
}
