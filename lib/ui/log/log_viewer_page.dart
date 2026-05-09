import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/services/log_service.dart';

class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAutoScroll = true;
  LogService? _logService;

  @override
  void initState() {
    super.initState();
    _logService = LogService.instance;
    _logService!.addListener(_onLogsChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onLogsChanged() {
    if (mounted) {
      setState(() {});
      if (_isAutoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 50) {
      if (_isAutoScroll) {
        setState(() => _isAutoScroll = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除日志'),
        content: const Text('确定要清除所有日志吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _logService?.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('日志已清除')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyAllLogs() async {
    final logText = _logService?.getAllLogsAsText() ?? '';
    await Clipboard.setData(ClipboardData(text: logText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('日志已复制到剪贴板'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScroll = !_isAutoScroll;
      if (_isAutoScroll) {
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _logService?.removeListener(_onLogsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = _logService?.logs ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('日志查看器'),
        backgroundColor: Colors.grey[800],
        actions: [
          IconButton(
            icon: Icon(_isAutoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center),
            tooltip: _isAutoScroll ? '自动滚动已开启' : '自动滚动已关闭',
            onPressed: _toggleAutoScroll,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '复制所有日志',
            onPressed: _copyAllLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '清除日志',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Container(
        color: Colors.black87,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blueGrey[900],
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '提示: 点击右上角的复制按钮可以将日志复制到剪贴板，然后发给我分析问题',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white70),
                    onPressed: _copyAllLogs,
                    tooltip: '复制日志',
                  ),
                ],
              ),
            ),
            Expanded(
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无日志',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        Color textColor = Colors.white;

                        switch (log.level) {
                          case LogLevel.error:
                            textColor = Colors.red[300]!;
                            break;
                          case LogLevel.warning:
                            textColor = Colors.orange[300]!;
                            break;
                          case LogLevel.info:
                            textColor = Colors.green[300]!;
                            break;
                          case LogLevel.debug:
                            textColor = Colors.white70;
                            break;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText(
                            log.formattedString,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: textColor,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[900],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '日志条目: ${logs.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    '自动滚动: ${_isAutoScroll ? "开启" : "关闭"}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
