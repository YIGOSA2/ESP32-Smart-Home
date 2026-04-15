# 智能家居APP(Smart Home APP)
## 项目简介
这是一个基于Flutter开发的ESP32智能家居控制APP，可以远程控制灯光、风扇等设备，实时监控温湿度、燃气、火焰等传感器数据，并在异常情况下发送本地推送通知。
## 核心功能
**设备控制**

- 灯光开关远程控制
- 风扇开关远程控制
- 实时状态同步显示

**环境监测**

- 温度实时监控
- 湿度实时监控
- 燃气浓度检测（超阈值报警）
- 火焰检测（超阈值报警）

**智能报警**

- 燃气/火焰超标本地通知
- 报警历史记录

**门禁管理**

- RFID刷卡记录
- 有效/无效卡片识别
- 门禁日志查看

**天气显示**

- 同步ESP32获取的天气信息
- 实时温度和天气状况

**场景模式**

- 全部关闭
- 离家模式
- 回家模式
- 睡眠模式
- 阅读模式
- 通风模式
## 快速开始（Quick Start）
**环境要求**
- Flutter SDK 3.0.0+
- Dart SDK 3.0.0+
- Android Studio / VS Code
- Android设备或模拟器（Android 5.0+）<br>
**使用步骤**<br>
1.克隆项目后进入项目
```
git clone -b software --single-branch git@github.com:YIGOSA2/ESP32-Smart-Home.git
cd smart_home_app
```
2.下载flutter后进入其文件夹并执行
```
pub get
```
3.运行APP
```
run
```
4.构建APK
```
build apk --release
```
## 项目结构（Structure）
```
lib/
├── main.dart                    # 入口文件
├── models/                      # 数据模型
│   ├── device_status.dart
│   ├── alert_message.dart
│   └── door_log.dart
├── services/                    # 服务层
│   ├── mqtt_service.dart
│   ├── notification_service.dart
│   └── storage_service.dart
├── providers/                   # 状态管理
│   ├── device_provider.dart
│   └── settings_provider.dart
├── screens/                     # 界面
│   ├── home_screen.dart
│   ├── door_log_screen.dart
│   ├── scene_screen.dart
│   └── settings_screen.dart
├── widgets/                     # 组件
│   ├── sensor_card.dart
│   ├── control_switch.dart
│   ├── alert_banner.dart
│   └── weather_widget.dart
└── constants/                   # 常量
    ├── colors.dart
    └── mqtt_topics.dart
```
