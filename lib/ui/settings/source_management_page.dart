import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/providers/source_provider.dart';
import 'package:tvbox_flutter/models/source_config.dart';

class SourceManagementPage extends StatefulWidget {
  const SourceManagementPage({super.key});

  @override
  State<SourceManagementPage> createState() => _SourceManagementPageState();
}

class _SourceManagementPageState extends State<SourceManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    _nameController.clear();
    _urlController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('添加数据源'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入数据源名称' : null,
                decoration: const InputDecoration(
                  labelText: '数据源名称',
                  hintText: '例如：我的影院',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _urlController,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入源地址';
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme) return '请输入有效的URL';
                  if (!v.trim().endsWith('.js') && !v.trim().endsWith('.js.md5')) return '源地址应以.js结尾';
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: '源地址',
                  hintText: 'https://example.com/cat/index.js',
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          Consumer<SourceProvider>(
            builder: (context, provider, _) {
              return TextButton(
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;

                        final name = _nameController.text.trim();
                        final url = _urlController.text.trim();
                        final id =
                            DateTime.now().millisecondsSinceEpoch.toString();

                        final source = SourceConfig.remote(id: id, name: name, url: url);

                        Navigator.pop(context);

                        final success = await provider.addSource(source);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? '添加成功'
                                  : (provider.errorMessage ?? '添加失败')),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                child: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('添加'),
              );
            },
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
          if (provider.isLoading && provider.sources.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.sources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.source_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无数据源',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
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

          return Column(
            children: [
              if (provider.errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.red.shade100,
                  child: Text(provider.errorMessage!,
                      style: TextStyle(color: Colors.red.shade900)),
                ),
              if (provider.isLoading)
                const LinearProgressIndicator(),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.sources.length,
                  itemBuilder: (context, index) {
                    final source = provider.sources[index];
                    final isCurrent = provider.currentSource?.id == source.id;

                    return ListTile(
                      leading: Icon(
                        isCurrent
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isCurrent ? Colors.green : null,
                      ),
                      title: Text(source.name),
                      subtitle: Text(source.url),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('确认删除'),
                              content: Text('确定要删除数据源 "${source.name}" 吗？'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('取消')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('删除')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await provider.removeSource(source.id);
                          }
                        },
                      ),
                      onTap: () async {
                        await provider.setCurrentSource(source);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
