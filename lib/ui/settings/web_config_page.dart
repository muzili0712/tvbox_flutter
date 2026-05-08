import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

class WebConfigPage extends StatefulWidget {
  const WebConfigPage({Key? key}) : super(key: key);

  @override
  State<WebConfigPage> createState() => _WebConfigPageState();
}

class _WebConfigPageState extends State<WebConfigPage> {
  late WebViewController _controller;
  String _configUrl = '';
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadConfigPage();
  }

  void _loadConfigPage() {
    _configUrl = NodeJSService.instance.getWebsiteUrl();
    
    if (_configUrl.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Node.js 服务未启动，请稍后重试',
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onHttpError: (HttpResponseError error) {
            print('HTTP error: $error');
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: $error');
            Fluttertoast.showToast(
              msg: '加载失败: ${error.description}',
              toastLength: Toast.LENGTH_LONG,
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(_configUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CatPawOpen 配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          
          // 加载指示器
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      '加载中... ${(_progress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          
          // 进度条
          if (_isLoading && _progress > 0 && _progress < 1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
