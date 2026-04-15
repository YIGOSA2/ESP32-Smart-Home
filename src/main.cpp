#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <MFRC522.h>
#include <ArduinoJson.h>
#include <TFT_eSPI.h>
#include <SPI.h>
#include <time.h>       // NTP时间同步
#include <HTTPClient.h> // HTTP请求
#include <ESP32Servo.h>

// ====================== 硬件配置 ======================
// GPIO定义
#define DHT_PIN 27 // DHT22数据引脚
#define DHT_TYPE DHT22
#define RFID_SS_PIN 5    // RC522 SS
#define RFID_RST_PIN 22  // RC522 RST
#define BUZZER_PIN 12    // 蜂鸣器
#define LED_ALARM_PIN 13 // 报警LED
#define GAS_PIN 34       // 燃气传感器
#define FLAME_PIN 35     // 火焰传感器
#define RELAY_LIGHT 25   // 灯光继电器
#define RELAY_FAN 26     // 风扇继电器
#define SERVO_PIN 14     // 舵机信号引脚
Servo doorServo;
// OLED配置
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 160

TFT_eSPI tft = TFT_eSPI(); // 使用platformio.ini中的配置

// DHT传感器
DHT dht(DHT_PIN, DHT_TYPE);

// RFID模块
MFRC522 mfrc522(RFID_SS_PIN, RFID_RST_PIN);

// ====================== 网络配置 ======================
const char *ssid = "";
const char *password = "";
const char *mqtt_server = ""; // 服务器
const int mqtt_port = 1883;
const char *mqtt_client_id = "ESP32_SmartHome";
const char *mqtt_topic_control = "smarthome/control"; // 接收APP控制指令
const char *mqtt_topic_status = "smarthome/status";   // 发送设备状态
const char *mqtt_topic_alert = "smarthome/alert";     // 发送报警信息

WiFiClient espClient;
PubSubClient client(espClient);

// ====================== NTP时间配置 ======================
const char *ntpServer = "ntp.aliyun.com"; // 阿里云NTP服务器
const long gmtOffset_sec = 8 * 3600;      // 东八区(北京时间)
const int daylightOffset_sec = 0;         // 不使用夏令时

// 时间变量
struct tm timeinfo;
bool timeValid = false;

// ====================== 心知天气配置 ======================
const char *weather_api_key = ""; // API
const char *weather_location = "";          
String weather_temp = "--";
String weather_text = "Unknown";
unsigned long lastWeatherUpdate = 0;
const unsigned long WEATHER_UPDATE_INTERVAL = 600000; // 10分钟更新一次天气
// ====================== 系统参数 ======================
// RFID白名单
String whitelist[] = {"61AF2A7", "87654321"};
const int whitelist_size = 2;

// 设备状态
bool light_status = false;
bool fan_status = false;
bool alarm_status = false;
bool rfid_alarm_status = false;
float temperature = 25.0;
float humidity = 0.0;
int gas_value = 0;
int flame_value = 0;
// 舵机角度定义
const int SERVO_LOCKED = 0;    // 锁定位置（0度）
const int SERVO_UNLOCKED = 90; // 解锁位置（90度）
// 舵机状态控制
bool doorUnlocked = false;
unsigned long doorUnlockTime = 0;
const unsigned long DOOR_LOCK_DELAY = 10000; // 10秒后自动上锁

// 新参数（屏幕初始化参数）
float last_temperature = -999;
float last_humidity = -999;
int last_gas_value = -1;
int last_flame_value = -1;
bool last_alarm_status = false;
String last_weather_temp = "";
String last_weather_text = "";
unsigned long last_time_update = 0;
bool display_initialized = false;

// ====================== 非阻塞控制变量 ======================
// MQTT重连控制
unsigned long lastReconnectAttempt = 0;
const unsigned long RECONNECT_INTERVAL = 5000;

// 报警控制
bool alarmActive = false;
unsigned long alarmStartTime = 0;
bool buzzerState = false;
unsigned long lastBuzzerToggle = 0;
const unsigned long BUZZER_TOGGLE_INTERVAL = 200;
const unsigned long ALARM_DURATION = 5000;

// 传感器滤波
const int FILTER_SAMPLES = 10;
int gas_readings[FILTER_SAMPLES] = {0};
int gas_index = 0;
bool gas_filter_initialized = false;

// 报警迟滞阈值
const int GAS_THRESHOLD_HIGH = 550; // 触发阈值
const int GAS_THRESHOLD_LOW = 450;  // 恢复阈值
const int FLAME_THRESHOLD_HIGH = 1000;
const int FLAME_THRESHOLD_LOW = 1200;

// 状态发送控制
unsigned long lastStatusTime = 0;
const unsigned long STATUS_INTERVAL = 5000;

// ====================== 函数声明 ======================
void setup_wifi();
void reconnect();
void callback(char *topic, byte *payload, unsigned int length);
void read_sensors();
void init_display();
void check_rfid();
void check_alarm();
void update_alarm();
void control_device(bool light, bool fan);
void display_info();
void send_status();
void send_alert(String alert_msg);
void update_weather();
bool check_rfid_whitelist(String uid);
//=======================初始化函數======================
void setup()
{
  Serial.begin(115200);
  // TFT初始化
  tft.init();
  tft.setRotation(3);        // 横屏显示（0=竖屏，1=横屏，2=倒竖屏，3=倒横屏）
  tft.fillScreen(TFT_BLACK); // 清屏
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextSize(1);

  // 显示启动信息
  tft.setCursor(10, 10);
  tft.setTextSize(2);
  tft.println("Smart Home");
  tft.setTextSize(1);
  tft.setCursor(10, 40);
  tft.println("Initializing...");

  // 传感器初始化
  dht.begin();
  SPI.begin();
  mfrc522.PCD_Init();

  // GPIO初始化
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_ALARM_PIN, OUTPUT);
  pinMode(RELAY_LIGHT, OUTPUT);
  pinMode(RELAY_FAN, OUTPUT);
  pinMode(GAS_PIN, INPUT);
  pinMode(FLAME_PIN, INPUT);

  digitalWrite(BUZZER_PIN, HIGH);
  digitalWrite(LED_ALARM_PIN, LOW);
  digitalWrite(RELAY_LIGHT, HIGH); // 假设高电平关闭（根据继电器类型调整）
  digitalWrite(RELAY_FAN, HIGH);
  // 舵机初始化
  doorServo.attach(SERVO_PIN);
  doorServo.write(SERVO_LOCKED); // 初始状态：锁定
  Serial.println("Servo initialized at locked position");

  // WiFi和MQTT初始化
  tft.setCursor(10, 80);
  tft.println("Connecting WiFi...");
  setup_wifi();

  // NTP时间同步
  Serial.println("Syncing time with NTP...");
  tft.setCursor(10, 100);
  tft.println("Syncing time...");
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);

  // 等待时间同步（最多等待5秒）
  int retry = 0;
  while (!getLocalTime(&timeinfo) && retry < 10)
  {
    delay(500);
    Serial.print(".");
    retry++;
  }

  if (retry < 10)
  {
    Serial.println("\nTime synced!");
    timeValid = true;
    tft.setCursor(10, 100);
    tft.setTextColor(TFT_GREEN, TFT_BLACK);
    tft.println("Time synced!   ");
  }
  else
  {
    Serial.println("\nTime sync failed!");
    timeValid = false;
    tft.setCursor(10, 100);
    tft.setTextColor(TFT_YELLOW, TFT_BLACK);
    tft.println("Time sync fail");
  }
  delay(1000);

  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);

  Serial.println("Connecting MQTT...");
  lastReconnectAttempt = 0; // 重置计时器
  reconnect();              // 立即尝试连接

  // 等待连接成功
  int retry_count = 0;
  while (!client.connected() && retry_count < 3)
  {
    delay(2000);
    reconnect();
    retry_count++;
  }

  if (client.connected())
  {
    Serial.println("MQTT Connected!");
  }
  else
  {
    Serial.println("MQTT Connect failed!");
  }

  init_display();
  delay(500);

  Serial.println("System initialized!");
  send_alert("ESP32 开机测试");
}

void loop()
{
  // MQTT连接管理（非阻塞）
  reconnect();
  if (client.connected())
  {
    client.loop();
  }

  unsigned long now = millis();
  if (now - lastWeatherUpdate >= WEATHER_UPDATE_INTERVAL)
  {
    update_weather();
    lastWeatherUpdate = now;
  }

  // 读取传感器
  read_sensors();

  // 检查RFID
  check_rfid();

  // 检查报警条件
  check_alarm();

  // 更新报警状态（非阻塞）
  update_alarm();

  // 更新显示
  display_info();

  // 定时发送状态
  if (now - lastStatusTime >= STATUS_INTERVAL)
  {
    send_status();
    lastStatusTime = now;
  }

  delay(100);

  // 检查舵机自动复原
  if (doorUnlocked && (millis() - doorUnlockTime >= DOOR_LOCK_DELAY))
  {
    doorServo.write(SERVO_LOCKED);
    doorUnlocked = false;
    Serial.println("Door auto-locked");
    send_alert("Door auto-locked");
  }
}

// ====================== 功能函数实现 ======================

// WiFi连接
void setup_wifi()
{
  delay(10);
  Serial.println();
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }

  Serial.println("");
  Serial.println("WiFi connected");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());
}

// ====================== MQTT非阻塞重连 ======================
void reconnect()
{
  if (client.connected())
  {
    return;
  }

  // 非阻塞重连逻辑
  unsigned long now = millis();
  if (now - lastReconnectAttempt < RECONNECT_INTERVAL)
  {
    return; // 还没到重连时间
  }

  lastReconnectAttempt = now;
  Serial.print("Try to connect MQTT...");

  String clientId = "ESP32_SmartHome_";
  clientId += String(random(0xffff), HEX);

  // 尝试连接
  if (client.connect(clientId.c_str()))
  {
    Serial.println("Connected！");
    client.subscribe(mqtt_topic_control);
    Serial.print("subed topic：");
    Serial.println(mqtt_topic_control);

    // 连接成功后立即发送一次状态
    send_status();
  }
  else
  {
    Serial.print("erro code：");
    Serial.print(client.state());
    Serial.println(",retry in 5s...");
  }
}
// MQTT回调函数（处理APP控制指令）
void callback(char *topic, byte *payload, unsigned int length)
{
  Serial.print("Message received: [");
  Serial.print(topic);
  Serial.print("] ");

  String payload_str = "";
  for (int i = 0; i < length; i++)
  {
    payload_str += (char)payload[i];
  }
  Serial.println(payload_str);

  // 解析JSON指令
  DynamicJsonDocument doc(1024);
  DeserializationError error = deserializeJson(doc, payload_str);
  if (error)
  {
    Serial.print("json err: ");
    Serial.println(error.c_str());
    return;
  }
  // 处理灯光控制
  if (doc.containsKey("light"))
  {
    light_status = doc["light"];
    digitalWrite(RELAY_LIGHT, light_status ? LOW : HIGH);
  }

  // 处理风扇控制
  if (doc.containsKey("fan"))
  {
    fan_status = doc["fan"];
    digitalWrite(RELAY_FAN, fan_status ? LOW : HIGH);
  }

  // 发送更新后的状态
  send_status();

}

// ====================== 读取传感器（带滤波） ======================
void read_sensors()
{
  // 温湿度
  float temp = dht.readTemperature();
  float hum = dht.readHumidity();

  // 数据有效性检查
  if (!isnan(temp) && !isnan(hum))
  {
    if (temp >= -40 && temp <= 80)
    {
      temperature = temp;
    }
    if (hum >= 0 && hum <= 100)
    {
      humidity = hum;
    }
  }
  else
  {
    Serial.println("DHT read failed, using last value");
  }

  // 燃气浓度（滑动平均滤波）
  gas_readings[gas_index] = analogRead(GAS_PIN);
  gas_index = (gas_index + 1) % FILTER_SAMPLES;

  // 计算平均值
  if (!gas_filter_initialized && gas_index == 0)
  {
    gas_filter_initialized = true;
  }

  if (gas_filter_initialized)
  {
    int sum = 0;
    for (int i = 0; i < FILTER_SAMPLES; i++)
    {
      sum += gas_readings[i];
    }
    gas_value = sum / FILTER_SAMPLES;
  }
  else
  {
    gas_value = gas_readings[gas_index];
  }

  // 火焰检测
  flame_value = analogRead(FLAME_PIN);
}

// ====================== RFID检查（非阻塞） ======================
void check_rfid()
{
  if (!mfrc522.PICC_IsNewCardPresent() || !mfrc522.PICC_ReadCardSerial())
  {
    return;
  }

  String uid = "";
  for (byte i = 0; i < mfrc522.uid.size; i++)
  {
    uid += String(mfrc522.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  Serial.print("Card UID: ");
  Serial.println(uid);

  if (check_rfid_whitelist(uid))
  {
    Serial.println("Valid card, access granted!");
    // 开门
    doorServo.write(SERVO_UNLOCKED);
    doorUnlocked = true;
    doorUnlockTime = millis();

    Serial.println("Door unlocked! Will auto-lock in 10s");
    send_alert("Door opened by card: " + uid);
  }
  else
  {
    Serial.println("Invalid card, alarm triggered!");
    send_alert("Invalid RFID card! UID: " + uid);
    // 触发报警但不阻塞
    rfid_alarm_status = true;
    alarmActive = true;
    alarmStartTime = millis();
  }

  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();
}

// ====================== 检查报警（迟滞比较） ======================
void check_alarm()
{
  bool should_alarm = false;
  String alert_msg = "";

  // 燃气报警（迟滞比较）
  if (!alarm_status && gas_value > GAS_THRESHOLD_HIGH)
  {
    should_alarm = true;
    alert_msg += "Gas level HIGH! Value: " + String(gas_value) + " ";
  }
  else if (alarm_status && gas_value < GAS_THRESHOLD_LOW)
  {
    should_alarm = false;
  }
  else if (alarm_status && gas_value > GAS_THRESHOLD_HIGH)
  {
    should_alarm = true;
  }

  //  火焰报警（迟滞比较）
  
  if (!alarm_status && flame_value < FLAME_THRESHOLD_HIGH)
  {
    should_alarm = true;
    alert_msg += "Flame detected! Value: " + String(flame_value);
  }
  else if (alarm_status && flame_value > FLAME_THRESHOLD_LOW)
  {
    should_alarm = false;
  }
  else if (alarm_status && flame_value < FLAME_THRESHOLD_HIGH)
  {
    should_alarm = true;
  }
  

  // 触发报警
  if (should_alarm && !alarm_status)
  {
    alarm_status = true;
    alarmActive = true;
    alarmStartTime = millis();
    send_alert(alert_msg);
    Serial.println("ALARM TRIGGERED!");
  }
  else if (!should_alarm && alarm_status)
  {
    alarm_status = false;
    alarmActive = false;
    digitalWrite(BUZZER_PIN, HIGH);
    digitalWrite(LED_ALARM_PIN, LOW);
    Serial.println("Alarm cleared");
  }
}

// ====================== 非阻塞报警更新 ======================
void update_alarm()
{
  if (!alarmActive && !alarm_status && !rfid_alarm_status)
  {
    return;
  }

  unsigned long now = millis();
  unsigned long elapsed = now - alarmStartTime;

  // 报警持续时间内闪烁
  if (elapsed < ALARM_DURATION)
  {
    if (now - lastBuzzerToggle >= BUZZER_TOGGLE_INTERVAL)
    {
      buzzerState = !buzzerState;
      digitalWrite(BUZZER_PIN, buzzerState ? LOW : HIGH);
      digitalWrite(LED_ALARM_PIN, buzzerState ? HIGH : LOW);
      lastBuzzerToggle = now;
    }
  }
  else
  {
    // 报警结束
    alarmActive = false;
    rfid_alarm_status = false;
    digitalWrite(BUZZER_PIN, HIGH);
    digitalWrite(LED_ALARM_PIN, LOW);
  }
}

// 检查RFID是否在白名单
bool check_rfid_whitelist(String uid)
{
  for (int i = 0; i < whitelist_size; i++)
  {
    if (whitelist[i] == uid)
    {
      return true;
    }
  }
  return false;
}

// ====================== TFT彩色显示（ST7735） ======================
void init_display()
{
  tft.fillScreen(TFT_BLACK);

  // 绘制标题栏（固定不变的部分）
  tft.fillRect(0, 0, 160, 18, TFT_NAVY);
  tft.setTextSize(2);
  tft.setCursor(20, 2);
  tft.setTextColor(TFT_WHITE, TFT_NAVY);
  tft.println("Smart Home");

  // 绘制标签（固定不变的部分）
  tft.setTextSize(1);

  // 时间标签
  tft.setCursor(5, 22);
  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.print("Time: ");

  // 天气标签
  tft.setCursor(5, 35);
  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.print("Weather: ");

  // 温湿度标签（同一行）
  tft.setCursor(5, 50);
  tft.setTextColor(TFT_GREEN, TFT_BLACK);
  tft.print("Temp:");

  tft.setCursor(5, 65);
  tft.print("Humi:");

  // 传感器标签（同一行）
  tft.setCursor(5, 85);
  tft.setTextColor(TFT_MAGENTA, TFT_BLACK);
  tft.print("Gas:");

  tft.setCursor(85, 85);
  tft.print("Flame:");

  // 初始化底部状态栏（默认显示Normal）
  tft.fillRect(0, 110, 160, 18, TFT_DARKGREEN);
  tft.setTextSize(2);
  tft.setCursor(40, 112);
  tft.setTextColor(TFT_WHITE, TFT_DARKGREEN);
  tft.println("Normal");

  display_initialized = true;
}

void display_info()
{
  // 首次调用时初始化
  if (!display_initialized)
  {
    init_display();
  }

  // ========== 更新时间（每秒更新一次） ==========
  unsigned long now = millis();
  if (now - last_time_update >= 1000)
  {
    tft.setTextSize(1);
    tft.setCursor(40, 22);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);

    if (timeValid && getLocalTime(&timeinfo))
    {
      tft.printf("%02d:%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
    }
    else
    {
      tft.print("--:--:--");
    }

    last_time_update = now;
  }

  // ========== 更新MQTT连接状态指示（右上角圆点） ==========
  static bool last_mqtt_status = false;
  bool current_mqtt_status = client.connected();
  if (current_mqtt_status != last_mqtt_status)
  {
    if (current_mqtt_status)
    {
      tft.fillCircle(150, 25, 3, TFT_GREEN); // 绿色=已连接
    }
    else
    {
      tft.fillCircle(150, 25, 3, TFT_RED); // 红色=未连接
    }
    last_mqtt_status = current_mqtt_status;
  }

  // ========== 更新天气（只在变化时更新） ==========
  if (weather_temp != last_weather_temp || weather_text != last_weather_text)
  {
    tft.setCursor(60, 35);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.print("                    "); // 清除旧内容
    tft.setCursor(60, 35);
    tft.print(weather_temp);
    tft.print((char)247); // 度数符号
    tft.print("C ");
    tft.print(weather_text);

    last_weather_temp = weather_temp;
    last_weather_text = weather_text;
  }

  // ========== 更新温度（只在变化时更新） ==========
  if (abs(temperature - last_temperature) > 0.1)
  {
    tft.setTextSize(1); // 确保字体大小正确
    tft.setCursor(40, 50);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.print("          "); // 清除旧内容（加长清除区域）
    tft.setCursor(40, 50);
    tft.printf("%.1f", temperature);
    tft.print((char)247);
    tft.print("C");

    last_temperature = temperature;
  }

  // ========== 更新湿度（只在变化时更新） ==========
  if (abs(humidity - last_humidity) > 0.1)
  {
    tft.setTextSize(1); // 确保字体大小正确
    tft.setCursor(40, 65);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.print("          "); // 清除旧内容（加长清除区域）
    tft.setCursor(40, 65);
    tft.printf("%.1f%%", humidity);

    last_humidity = humidity;
  }

  // ========== 更新燃气值（初始化或变化超过10时更新） ==========
  if (last_gas_value == -1 || abs(gas_value - last_gas_value) > 10)
  {
    tft.setTextSize(1); // 确保字体大小正确
    tft.setCursor(35, 85);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.print("       "); // 清除旧内容
    tft.setCursor(35, 85);
    tft.printf("%4d", gas_value);

    last_gas_value = gas_value;
  }

  // ========== 更新火焰值（初始化或变化超过10时更新） ==========
  if (last_flame_value == -1 || abs(flame_value - last_flame_value) > 10)
  {
    tft.setTextSize(1); // 确保字体大小正确
    tft.setCursor(125, 85);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.print("       "); // 清除旧内容
    tft.setCursor(125, 85);
    tft.printf("%4d", flame_value);

    last_flame_value = flame_value;
  }

  // ============ 更新报警状态 ===============
  bool any_alarm = alarm_status || rfid_alarm_status;
  if (any_alarm != last_alarm_status)
  {
    if (any_alarm)
    {
      tft.fillRect(0, 110, 160, 18, TFT_RED); // 红色警告栏
      tft.setTextSize(2);
      tft.setCursor(20, 112);
      tft.setTextColor(TFT_WHITE, TFT_RED);
      tft.println("!!! ALARM !!!");
      tft.setTextSize(1); // 恢复字体大小
    }
    else
    {
      tft.fillRect(0, 110, 160, 18, TFT_DARKGREEN); // 深绿色正常栏
      tft.setTextSize(2);
      tft.setCursor(40, 112);
      tft.setTextColor(TFT_WHITE, TFT_DARKGREEN);
      tft.println("Normal");
      tft.setTextSize(1); // 恢复字体大小
    }

    last_alarm_status = any_alarm;
  }
}

// 发送设备状态到MQTT
void send_status()
{
  if (!client.connected())
  {
    Serial.println("MQTT not connect");
    return;
  }
  DynamicJsonDocument doc(1024);
  doc["temperature"] = temperature;
  doc["humidity"] = humidity;
  doc["light"] = light_status;
  doc["fan"] = fan_status;
  doc["gas"] = gas_value;
  doc["flame"] = flame_value;
  doc["alarm"] = alarm_status;
  doc["weather_temp"] = weather_temp;
  doc["weather_text"] = weather_text;
  
  String payload;
  serializeJson(doc, payload);

  client.publish(mqtt_topic_status, payload.c_str());
  Serial.print("Status sent: ");
  Serial.println(payload);
}

// 发送报警信息
void send_alert(String alert_msg)
{
  if (!client.connected())
  {
    Serial.println("MQTT not connected, skip alert");
    return;
  }
  DynamicJsonDocument doc(1024);
  doc["type"] = "alert";
  doc["message"] = alert_msg;

  // NTP时间戳
  if (timeValid && getLocalTime(&timeinfo))
  {
    char timeStr[64];
    strftime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", &timeinfo);
    doc["time"] = timeStr;
  }
  else
  {
    doc["time"] = millis(); // 如果用不了 ntp 使用运行时间
  }

  String payload;
  serializeJson(doc, payload);

  bool success = client.publish(mqtt_topic_alert, payload.c_str());
  if (success)
  {
    Serial.print("Alert sent: ");
    Serial.println(payload);
  }
  else
  {
    Serial.println("Alert send failed!");
  }
}

// ====================== 天气更新函数 ======================
void update_weather()
{
  if (WiFi.status() != WL_CONNECTED)
  {
    Serial.println("Skip weather update: WiFi not connected");
    return;
  }

  HTTPClient http;

  // 构建心知天气API URL
  String url = "https://api.seniverse.com/v3/weather/now.json?key=" +
               String(weather_api_key) +
               "&location=" + String(weather_location) +
               "&language=en";

  Serial.println("");
  Serial.println("========================================");
  Serial.println("=== Weather Update START (Seniverse) ===");
  Serial.println("========================================");
  Serial.print("URL: ");
  Serial.println(url);

  http.begin(url);
  http.setTimeout(10000); // 10秒超时

  Serial.println("Sending HTTP GET request...");
  int httpCode = http.GET();

  Serial.print("HTTP Response Code: ");
  Serial.println(httpCode);

  if (httpCode == 200)
  {
    String payload = http.getString();

    Serial.println("");
    Serial.println("=== Raw Response (first 300 chars) ===");
    Serial.println(payload.substring(0, min(300, (int)payload.length())));
    Serial.println("=======================================");
    Serial.println("");

    Serial.print("Response Length: ");
    Serial.println(payload.length());

    // 解析JSON
    DynamicJsonDocument doc(2048);
    DeserializationError error = deserializeJson(doc, payload);

    if (!error)
    {
      if (doc.containsKey("results") && doc["results"].size() > 0)
      {
        JsonObject result = doc["results"][0];
        JsonObject now = result["now"];

        weather_temp = now["temperature"].as<String>();
        weather_text = now["text"].as<String>();

        Serial.println("");
        Serial.println("Weather update SUCCESS!");
        Serial.print("Temperature: ");
        Serial.print(weather_temp);
        Serial.print("°C");
        Serial.print(", Weather: ");
        Serial.println(weather_text);
      }
      else
      {
        Serial.println("API Error: No results in response");
        weather_temp = "--";
        weather_text = "No Data";
      }
    }
    else
    {
      Serial.println("");
      Serial.print("JSON Parse Error: ");
      Serial.println(error.c_str());

      Serial.println("");
      Serial.println("=== Full Response for Debug ===");
      Serial.println(payload);
      Serial.println("===============================");

      weather_temp = "--";
      weather_text = "Parse Err";
    }
  }
  else if (httpCode > 0)
  {
    String payload = http.getString();
    Serial.print("HTTP Error ");
    Serial.print(httpCode);
    Serial.println(":");
    Serial.println(payload);
    weather_temp = "--";
    weather_text = "HTTP Err";
  }
  else
  {
    Serial.print("Connection Error: ");
    Serial.println(http.errorToString(httpCode));
    weather_temp = "--";
    weather_text = "Conn Err";
  }

  http.end();
}
