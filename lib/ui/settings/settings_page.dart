import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/providers/source_provider.dart';
import 'package:tvbox_flutter/ui/settings/source_management_page.dart';
import 'package:tvbox_flutter/ui/settings/player_settings_page.dart';
import 'package:tvbox_flutter/ui/settings/cloud_drive_settings_page.dart';
import 'package:tvbox_flutter/ui/settings/web_config_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _getAppVersion();
  }

  Future<void> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('数据源'),
          ListTile(
            leading: const Icon(Icons.source),
            title: const Text('数据源管理'),
            subtitle: Text('当前: ${Provider.of<SourceProvider>(context).currentSource?.name ?? "未设置"}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SourceManagementPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('CatPawOpen 配置'),
            subtitle: const Text('网盘登录、Cookie 管理等'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WebConfigPage()),
              );
            },
          ),
          const Divider(),
          
          _buildSectionHeader('播放器'),
          ListTile(
            leading: const Icon(Icons.play_circle),
            title: const Text('播放器设置'),
            subtitle: const Text('默认播放器、解码方式、倍速等'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlayerSettingsPage()),
              );
            },
          ),
          const Divider(),
          
          _buildSectionHeader('网盘'),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('网盘管理'),
            subtitle: const Text('添加和管理阿里云盘、百度网盘等'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CloudDriveSettingsPage()),
              );
            },
          ),
          const Divider(),
          
          _buildSectionHeader('数据'),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('备份与恢复'),
            subtitle: const Text('备份和恢复应用数据'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // 实现备份与恢复
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('清除缓存'),
            subtitle: const Text('清除应用缓存数据'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // 实现清除缓存
            },
          ),
          const Divider(),
          
          _buildSectionHeader('关于'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于TVBox'),
            subtitle: Text('版本 $_appVersion'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'TVBox',
                applicationVersion: _appVersion,
                applicationIcon: const Icon(Icons.tv),
                children: const [
                  Text('一个功能强大的视频播放应用'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
