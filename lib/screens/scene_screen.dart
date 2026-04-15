// 场景模式界面

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../constants/colors.dart';

class SceneScreen extends StatelessWidget {
  const SceneScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '场景模式',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 说明文字
          Card(
            elevation: 0,
            color: AppColors.info.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.info,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '一键执行预设场景，让智能家居更便捷',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 场景卡片列表
          _buildSceneCard(
            context,
            title: '全部关闭',
            description: '关闭所有设备，节能环保',
            icon: Icons.power_off,
            color: AppColors.danger,
            onTap: () {
              _executeScene(
                context,
                '全部关闭',
                () => context.read<DeviceProvider>().sceneAllOff(),
              );
            },
          ),
          const SizedBox(height: 16),

          _buildSceneCard(
            context,
            title: '离家模式',
            description: '关闭所有设备，启动安全监控',
            icon: Icons.exit_to_app,
            color: AppColors.warning,
            onTap: () {
              _executeScene(
                context,
                '离家模式',
                () => context.read<DeviceProvider>().sceneLeaveHome(),
              );
            },
          ),
          const SizedBox(height: 16),

          _buildSceneCard(
            context,
            title: '回家模式',
            description: '打开灯光，营造温馨氛围',
            icon: Icons.home,
            color: AppColors.success,
            onTap: () {
              _executeScene(
                context,
                '回家模式',
                () => context.read<DeviceProvider>().sceneArriveHome(),
              );
            },
          ),
          const SizedBox(height: 16),

          _buildSceneCard(
            context,
            title: '睡眠模式',
            description: '关闭灯光和风扇，安静入眠',
            icon: Icons.nightlight,
            color: AppColors.primary,
            onTap: () {
              _executeScene(
                context,
                '睡眠模式',
                () async {
                  final provider = context.read<DeviceProvider>();
                  await provider.controlLight(false);
                  await provider.controlFan(false);
                },
              );
            },
          ),
          const SizedBox(height: 16),

          _buildSceneCard(
            context,
            title: '阅读模式',
            description: '打开灯光，关闭风扇',
            icon: Icons.menu_book,
            color: Colors.amber,
            onTap: () {
              _executeScene(
                context,
                '阅读模式',
                () async {
                  final provider = context.read<DeviceProvider>();
                  await provider.controlLight(true);
                  await provider.controlFan(false);
                },
              );
            },
          ),
          const SizedBox(height: 16),

          _buildSceneCard(
            context,
            title: '通风模式',
            description: '打开风扇，保持空气流通',
            icon: Icons.air,
            color: Colors.blue,
            onTap: () {
              _executeScene(
                context,
                '通风模式',
                () async {
                  final provider = context.read<DeviceProvider>();
                  await provider.controlFan(true);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSceneCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Row(
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              // 文字信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // 箭头图标
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _executeScene(
    BuildContext context,
    String sceneName,
    Future<void> Function() action,
  ) async {
    // 显示加载提示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('正在执行 $sceneName...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 执行场景
      await action();

      // 关闭加载对话框
      Navigator.pop(context);

      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $sceneName 执行成功'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // 关闭加载对话框
      Navigator.pop(context);

      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ $sceneName 执行失败: $e'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
