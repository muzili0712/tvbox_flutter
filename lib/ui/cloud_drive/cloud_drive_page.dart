import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/providers/cloud_drive_provider.dart';
import 'package:tvbox_flutter/ui/cloud_drive/drive_file_list.dart';
import 'package:tvbox_flutter/ui/settings/cloud_drive_settings_page.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class CloudDrivePage extends StatefulWidget {
  const CloudDrivePage({super.key});

  @override
  State<CloudDrivePage> createState() => _CloudDrivePageState();
}

class _CloudDrivePageState extends State<CloudDrivePage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _isLoading = false;
  }

  Future<void> _loadDrives() async {
    setState(() => _isLoading = true);

    try {
      await Provider.of<CloudDriveProvider>(context, listen: false).loadDrives();
    } catch (e) {
      print('Failed to load drives: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('网盘'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CloudDriveSettingsPage()),
              ).then((_) => _loadDrives());
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final driveProvider = Provider.of<CloudDriveProvider>(context);

    if (_isLoading) {
      return const Center(
        child: SpinKitFadingCircle(
          color: Colors.blue,
          size: 50.0,
        ),
      );
    }

    if (driveProvider.drives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('还没有添加网盘', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CloudDriveSettingsPage()),
                ).then((_) => _loadDrives());
              },
              child: const Text('添加网盘'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: driveProvider.drives.length,
      itemBuilder: (context, index) {
        final drive = driveProvider.drives[index];
        return Card(
          child: ListTile(
            leading: _getDriveIcon(drive.type),
            title: Text(drive.name),
            subtitle: Text(_getDriveTypeName(drive.type)),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriveFileListPage(
                    driveId: drive.id,
                    driveName: drive.name,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _getDriveIcon(String type) {
    switch (type) {
      case 'aliyun':
        return const Icon(Icons.cloud, color: Colors.blue);
      case 'baidu':
        return const Icon(Icons.cloud, color: Colors.blueAccent);
      case 'quark':
        return const Icon(Icons.cloud, color: Colors.orange);
      default:
        return const Icon(Icons.cloud);
    }
  }

  String _getDriveTypeName(String type) {
    switch (type) {
      case 'aliyun':
        return '阿里云盘';
      case 'baidu':
        return '百度网盘';
      case 'quark':
        return '夸克网盘';
      default:
        return '未知网盘';
    }
  }
}
