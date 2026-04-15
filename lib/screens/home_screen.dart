// 主界面

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/sensor_card.dart';
import '../widgets/control_switch.dart';
import '../widgets/alert_banner.dart';
import '../widgets/weather_widget.dart';
import '../constants/colors.dart';
import 'door_log_screen.dart';
import 'scene_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final deviceProvider = context.read<DeviceProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    // 初始化设置
    await settingsProvider.initialize();

    // 初始化设备Provider
    await deviceProvider.initialize();

    // 连接到MQTT服务器
    await deviceProvider.connect(
      settingsProvider.mqttBroker,
      settingsProvider.mqttPort,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '智能家居控制',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 连接状态指示器
          Consumer<DeviceProvider>(
            builder: (context, provider, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: provider.isConnected
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.danger.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: provider.isConnected
                                ? AppColors.success
                                : AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          provider.isConnected ? '已连接' : '未连接',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: provider.isConnected
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, child) {
          final status = provider.currentStatus;

          return RefreshIndicator(
            onRefresh: () async {
              // 重新连接
              final settings = context.read<SettingsProvider>();
              await provider.connect(
                settings.mqttBroker,
                settings.mqttPort,
              );
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 报警横幅
                  if (status?.needsAlert ?? false)
                    AlertBanner(
                      message: status!.alertReason,
                      isActive: true,
                    ),

                  // 天气信息
                  WeatherWidget(
                    temperature: provider.weatherTemp,
                    description: provider.weatherText,
                  ),
                  const SizedBox(height: 16),

                  // 设备控制区域
                  _buildSectionTitle('设备控制'),
                  const SizedBox(height: 12),
                  ControlSwitch(
                    title: '灯光',
                    subtitle: status?.lightStatus ?? false ? '已开启' : '已关闭',
                    icon: Icons.lightbulb,
                    value: status?.lightStatus ?? false,
                    onChanged: (value) {
                      provider.controlLight(value);
                    },
                    activeColor: Colors.amber,
                  ),
                  const SizedBox(height: 12),
                  ControlSwitch(
                    title: '风扇',
                    subtitle: status?.fanStatus ?? false ? '运行中' : '已停止',
                    icon: Icons.air,
                    value: status?.fanStatus ?? false,
                    onChanged: (value) {
                      provider.controlFan(value);
                    },
                    activeColor: Colors.blue,
                  ),
                  const SizedBox(height: 24),

                  // 传感器数据区域
                  _buildSectionTitle('环境监测'),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      SensorCard(
                        title: '温度',
                        value: status?.temperature.toStringAsFixed(1) ?? '--',
                        unit: '°C',
                        icon: Icons.thermostat,
                        color: AppColors.temperatureCard,
                      ),
                      SensorCard(
                        title: '湿度',
                        value: status?.humidity.toStringAsFixed(1) ?? '--',
                        unit: '%',
                        icon: Icons.water_drop,
                        color: AppColors.humidityCard,
                      ),
                      SensorCard(
                        title: '燃气浓度',
                        value: status?.gasValue.toString() ?? '--',
                        unit: '',
                        icon: Icons.gas_meter,
                        color: AppColors.gasCard,
                        isWarning: (status?.gasValue ?? 0) > 550,
                      ),
                      SensorCard(
                        title: '火焰检测',
                        value: status?.flameValue.toString() ?? '--',
                        unit: '',
                        icon: Icons.local_fire_department,
                        color: AppColors.flameCard,
                        isWarning: (status?.flameValue ?? 9999) < 1000,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 快捷功能区域
                  _buildSectionTitle('快捷功能'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          context,
                          icon: Icons.door_front_door,
                          label: '门禁记录',
                          color: AppColors.info,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DoorLogScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionButton(
                          context,
                          icon: Icons.auto_awesome,
                          label: '场景模式',
                          color: AppColors.accent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SceneScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
