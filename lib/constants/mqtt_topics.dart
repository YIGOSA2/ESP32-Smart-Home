// MQTT主题常量定义

class MqttTopics {
  // MQTT服务器默认配置
  static const String defaultBroker = '';
  static const int defaultPort = 1883;
  static const String clientIdPrefix = 'SmartHomeApp_';

  // 订阅主题 - 接收ESP32发送的数据
  static const String statusTopic = 'smarthome/status';      // 设备状态
  static const String alertTopic = 'smarthome/alert';        // 报警信息

  // 发布主题 - 向ESP32发送控制指令
  static const String controlTopic = 'smarthome/control';    // 设备控制
  // static const String wifiConfigTopic = 'smarthome/wifi';    // WiFi配置

  // QoS等级
  static const int qos0 = 0;  // 最多一次
  static const int qos1 = 1;  // 至少一次
  static const int qos2 = 2;  // 恰好一次
}
