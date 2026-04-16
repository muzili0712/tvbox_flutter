import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/providers/cloud_drive_provider.dart';
import 'package:tvbox_flutter/models/cloud_drive.dart';
import 'package:tvbox_flutter/utils/toast_util.dart';

class CloudDriveSettingsPage extends StatefulWidget {
  const CloudDriveSettingsPage({super.key});

  @override
  State<CloudDriveSettingsPage> createState() => _CloudDriveSettingsPageState();
}

class _CloudDriveSettingsPageState extends State<CloudDriveSettingsPage> {
  String _selectedType = 'aliyun';
  final _nameController = TextEditingController();
  final _tokenController = TextEditingController();
  final _driveIdController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _tokenController.dispose();
    _driveIdController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加网盘'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: '网盘类型'),
                items: const [
                  DropdownMenuItem(value: 'aliyun', child: Text('阿里云盘')),
                  DropdownMenuItem(value: 'baidu', child: Text('百度网盘')),
                  DropdownMenuItem(value: 'quark', child: Text('夸克网盘')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '网盘名称'),
              ),
              if (_selectedType == 'aliyun') ...[
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(labelText: 'Refresh Token'),
                ),
                TextField(
                  controller: _driveIdController,
                  decoration: const InputDecoration(labelText: 'Drive ID'),
                ),
              ] else ...[
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(labelText: 'Cookie'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isEmpty) {
                ToastUtil.showError('请填写名称');
                return;
              }
              
              Map<String, dynamic> config;
              if (_selectedType == 'aliyun') {
                config = {
                  'token': _tokenController.text.trim(),
                  'driveId': _driveIdController.text.trim(),
                };
              } else {
                config = {
                  'cookie': _tokenController.text.trim(),
                };
              }
              
              final drive = CloudDrive(
                id: DateTime.now().toString(),
                name: name,
                type: _selectedType,
                config: config,
              );
              
              await Provider.of<CloudDriveProvider>(context, listen: false)
                  .addDrive(drive);
              
              _nameController.clear();
              _tokenController.clear();
              _driveIdController.clear();
              Navigator.pop(context);
              ToastUtil.showSuccess('添加成功');
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('网盘管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: Consumer<CloudDriveProvider>(
        builder: (context, provider, child) {
          return ListView.builder(
            itemCount: provider.drives.length,
            itemBuilder: (context, index) {
              final drive = provider.drives[index];
              return ListTile(
                leading: _getDriveIcon(drive.type),
                title: Text(drive.name),
                subtitle: Text(_getDriveTypeName(drive.type)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await provider.removeDrive(drive.id);
                    ToastUtil.showSuccess('已删除');
                  },
                ),
              );
            },
          );
        },
      ),
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
