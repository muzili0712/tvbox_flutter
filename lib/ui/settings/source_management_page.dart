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
    String sourceType = 'remote';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加数据源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'remote', label: Text('远程源')),
                  ButtonSegment(value: 'local', label: Text('本地源')),
                  ButtonSegment(value: 'catpawopen', label: Text('内置')),
                ],
                selected: {sourceType},
                onSelectionChanged: (v) {
                  setDialogState(() => sourceType = v.first);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '数据源名称',
                  hintText: '例如：我的影院',
                ),
              ),
              const SizedBox(height: 8),
              if (sourceType == 'remote')
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: '源地址',
                    hintText: 'https://example.com/cat/index.js',
                  ),
                  keyboardType: TextInputType.url,
                ),
              if (sourceType == 'local')
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: '本地路径',
                    hintText: '本地文件路径',
                  ),
                ),
              if (sourceType == 'catpawopen')
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Spider Key',
                    hintText: '例如：kunyu77',
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

                if (name.isEmpty ||
                    (sourceType != 'catpawopen' && url.isEmpty)) {
                  ToastUtil.showError('请填写完整信息');
                  return;
                }

                SourceConfig source;
                final id = DateTime.now().millisecondsSinceEpoch.toString();

                if (sourceType == 'remote') {
                  source = SourceConfig.remote(id: id, name: name, url: url);
                } else if (sourceType == 'local') {
                  source = SourceConfig.local(id: id, name: name, url: url);
                } else {
                  source = SourceConfig.catPawOpen(
                    id: id,
                    name: name,
                    spiderKey: url,
                    spiderType: 3,
                  );
                }

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
          if (provider.sources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('暂无数据源'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('添加数据源'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.sources.length,
            itemBuilder: (context, index) {
              final source = provider.sources[index];
              final isCurrent = provider.currentSource?.id == source.id;

              String typeLabel;
              switch (source.sourceType) {
                case 'remote':
                  typeLabel = '远程';
                  break;
                case 'local':
                  typeLabel = '本地';
                  break;
                case 'catpawopen':
                  typeLabel = '内置';
                  break;
                default:
                  typeLabel = '未知';
              }

              return ListTile(
                leading: Icon(
                  isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isCurrent ? Colors.green : null,
                ),
                title: Text(source.name),
                subtitle: Text('[$typeLabel] ${source.url}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await provider.removeSource(source.id);
                    ToastUtil.showSuccess('已删除');
                  },
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
