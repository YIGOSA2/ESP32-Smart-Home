# ESP32智能家居系统（The System of Smart Home Based on ESP32）
[![Language](https://img.shields.io/badge/Language-C++-blue?style=flat-square)](https://isocpp.org/)
![GitHub license](https://img.shields.io/github/license/YIGOSA2/ESP32-Smart-Home?style=flat-square)
![Status](https://img.shields.io/badge/Status-building-orange?style=flat-square)
## 简介（Introduction）
本设计基于ESP32-32D开发，集成了环境监测以及远程控制的功能，通过温湿度传感器、火焰以及烟雾传感器将数据传输到本地屏幕以及通过MQTT服务传输到手机APP，
并且能通过MQTT服务实现远程控制舵机（模拟门锁）旋转。
## 目录结构（Structure）
```
smart_home_esp32/            
  ├── LICENSE                     # MIT 开源许可证                      
  ├── platformio.ini              # PlatformIO 构建配置（核心配置文件）
  │                                                                   
  ├── src/                        # 源代码目录   
  │   └── main.cpp                # 主程序
  ├── .pio/                       # PlatformIO 自动生成 
  │   └── libdeps/esp32dev/       # 自动下载的库依赖
  │       ├── Adafruit Unified Sensor/   # Adafruit 统一传感器库
  │       ├── ArduinoJson/               # JSON 解析/生成
  │       ├── DHT sensor library/        # DHT22 温湿度传感器驱动
  │       ├── ESP32Servo/                # 舵机控制
  │       ├── MFRC522/                   # RFID 读卡器驱动
  │       ├── PubSubClient/              # MQTT 客户端
  │       └── TFT_eSPI/                  # ST7735 TFT 彩屏驱动
  │
  └── .vscode/                    # VS Code 编辑器配置
      ├── c_cpp_properties.json   # C++ 智能提示配置
      ├── extensions.json         # 推荐扩展（PlatformIO IDE）
      └── launch.json             # 调试配置
```
## 器件清单（Device List）
|硬件名称|型号|备注|
|--------|---|-----|
|ESP开发板|ESP32-DevkitCv4|主控芯片以及联网|
|TF彩色屏幕|ST3375驱动    |128*160  |
|RFID读卡模块|RC522|用于门禁控制|
|燃气传感器|MQ-4|监测环境燃气浓度|
|火焰传感器|3/4线皆可|监测环境火焰|
|继电器模块|5v|控制灯光和风扇，数量：2或者使用双路继电器|
|蜂鸣器|有源或无源|报警警示|
|LED|任意|报警警示|
|舵机|SG90|模拟门锁|
## 引脚配置（Pin Configuration）
|模块|功能|引脚|
|----|----|----|
|TFT |SDA |GPIO23（共用）|
|    |SCL|GPIO18（共用）|
|    |CS |GPIO15|
|    |DC |GPIO2 |
|    |RST|GPIO4 |
|    |VCC|3.3V  |
|DHT22|DATA|GPIO27|
|    |VCC| 3.3V |
|RC522 RFID|SDA|GPIO5|
|    |SCK|GPIO18（共用）|
|    |MOSI|GPIO23（共用）|
|    |MISO|GPIO19|
|    |RST |GPIO22|
|    |VCC |3.3V  |
|蜂鸣器|I/O|GPIO12|
|报警LED|正极|GPIO13|
|MQ-4燃气|AO|GPIO34|
|     |VCC|5V|
|火焰传感器|AO|GPIO35|
|灯光继电器|IN|GPIO25|
|风扇继电器|IN|GPIO26|
|舵机|信号线|GPIO14|
## 软件环境（Software Setup）
1.**Vs code**：使用vs code进行程序编写；
2.**PlatformIO**：在vs code上安装platformio插件，使用platformio烧录以及调试。
## 快速开始（Quick Start）
```
#安装必要依赖
sudo pacman -Syu --needed code python3 python-pip git udev
```
```
#安装platformio
code --install-extension platformio.platformio-ide
```
```
source ~/.bashrc
```
```
#克隆本项目
git clone git@github.com:YIGOSA2/ESP32-Smart-Home.git
#进入项目
cd ESP32-Smart-Home
#在vscode打开项目
code .
```
编译并烧录。
注意：烧录前打开src/main.cpp填写wifi ssid 密码以及你的mqtt服务器ip地址。
## 感谢阅读
1.联系方式<br>
如果您在使用本项目时遇到了任何问题可以通过yigosa@duck.com联系我。<br>
2.反馈<br>
欢迎提交issue或者Pull Request.
