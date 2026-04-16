import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/providers/source_provider.dart';
import 'package:tvbox_flutter/models/source_config.dart';
import 'package:tvbox_flutter/utils/toast_util.dart';

class SourceManagementPage extends StatefulWidget {
  const SourceManagementPage({super.key});

  @override
  State<SourceManagementPage> createState() => _SourceManagementPageState();
}

class _SourceManagementPageState extends State<SourceManagementPage> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加数据源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '数据源名称',
                hintText: '例如：我的影院',
              ),
            ),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '数据源地址',
                hintText: '本地路径或远程URL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              final url = _urlController.text.trim();
              
              if (name.isEmpty || url.isEmpty) {
                ToastUtil.showError('请填写完整信息');
                return;
              }
              
              final source = SourceConfig(
                id: DateTime.now().toString(),
                name: name,
                url: url,
              );
              
              await Provider.of<SourceProvider>(context, listen: false)
                  .addSource(source);
              
              _nameController.clear();
              _urlController.clear();
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
        title: const Text('数据源管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: Consumer<SourceProvider>(
        builder: (context, provider, child) {
          return ListView.builder(
            itemCount: provider.sources.length,
            itemBuilder: (context, index) {
              final source = provider.sources[index];
              final isCurrent = provider.currentSource?.id == source.id;
              
              return ListTile(
                title: Text(source.name),
                subtitle: Text(source.url),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrent)
                      const Icon(Icons.check, color: Colors.green)
                    else
                      TextButton(
                        onPressed: () async {
                          await provider.setCurrentSource(source);
                          ToastUtil.showSuccess('已切换');
                        },
                        child: const Text('使用'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await provider.removeSource(source.id);
                        ToastUtil.showSuccess('已删除');
                      },
                    ),
                  ],
                ),
                onTap: () async {
                  await provider.setCurrentSource(source);
                  ToastUtil.showSuccess('已切换');
                },
              );
            },
          );
        },
      ),
    );
  }
}
