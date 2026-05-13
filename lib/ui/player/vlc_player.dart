import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:http/http.dart' as http;

class VlcPlayerWidget extends StatefulWidget {
  final String url;
  final Function(bool isPlaying, double position, double duration) onPlayerStateChanged;
  final VoidCallback onTap;

  const VlcPlayerWidget({
    super.key,
    required this.url,
    required this.onPlayerStateChanged,
    required this.onTap,
  });

  @override
  State<VlcPlayerWidget> createState() => _VlcPlayerWidgetState();
}

class _VlcPlayerWidgetState extends State<VlcPlayerWidget> {
  VlcPlayerController? _controller;
  bool _hasError = false;
  bool _isResolving = true;
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolveAndPlay();
  }

  Future<void> _resolveAndPlay() async {
    String playUrl = widget.url;
    print('[VLC播放器] 🎬 开始解析: originalUrl=${widget.url}');

    if (widget.url.contains('127.0.0.1') && widget.url.contains('proxy')) {
      print('[VLC播放器] 🔗 检测到代理URL，开始解析真实地址...');
      try {
        final uri = Uri.parse(widget.url);
        final actualUrl = uri.queryParameters['url'];
        if (actualUrl != null && actualUrl.isNotEmpty) {
          playUrl = actualUrl;
          print('[VLC播放器] ✅ 从proxy参数提取到直接URL: $playUrl');
        } else {
          print('[VLC播放器] 📡 proxy参数中没有url，尝试HTTP GET获取...');
          final response = await http.get(uri).timeout(const Duration(seconds: 10));
          print('[VLC播放器] 📡 proxy GET响应: status=${response.statusCode}, body=${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
          if (response.statusCode == 200) {
            final body = response.body.trim();
            if (body.startsWith('http')) {
              playUrl = body;
              print('[VLC播放器] ✅ 从proxy响应获取到流地址: $playUrl');
            } else {
              print('[VLC播放器] ⚠️ proxy响应不是http开头: $body');
            }
          } else {
            print('[VLC播放器] ❌ proxy GET失败: status=${response.statusCode}');
          }
        }
      } catch (e) {
        print('[VLC播放器] ❌ 代理解析错误: $e');
      }
    } else {
      print('[VLC播放器] 📡 非代理URL，直接播放');
    }

    print('[VLC播放器] 🎬 最终播放地址: $playUrl');

    if (!mounted) return;

    setState(() {
      _resolvedUrl = playUrl;
      _isResolving = false;
    });

    _initVlc(playUrl);
  }

  void _initVlc(String url) {
    print('[VLC播放器] 🎬 初始化VLC控制器: url=$url');
    _controller = VlcPlayerController.network(
      url,
      autoPlay: true,
      options: VlcPlayerOptions(
        video: VlcVideoOptions([
          'network-caching=3000',
        ]),
        audio: VlcAudioOptions([]),
        subtitle: VlcSubtitleOptions([]),
      ),
    );

    _controller!.addListener(_onPlayerStateChanged);

    setState(() {});
  }

  void _onPlayerStateChanged() {
    if (_controller == null) return;

    if (_controller!.value.hasError && !_hasError) {
      _hasError = true;
      print('[VLC播放器] ❌ 播放错误: ${_controller!.value.errorDescription}');
    }

    if (_controller!.value.isPlaying && _hasError) {
      _hasError = false;
      print('[VLC播放器] ✅ 恢复播放');
    }

    widget.onPlayerStateChanged(
      _controller!.value.isPlaying,
      _controller!.value.position.inMilliseconds.toDouble(),
      _controller!.value.duration.inMilliseconds.toDouble(),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerStateChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolving) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 8),
            Text('正在解析视频地址...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_controller == null) {
      return const Center(
        child: Text('播放器初始化失败', style: TextStyle(color: Colors.white)),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: VlcPlayer(
        controller: _controller!,
        aspectRatio: 16 / 9,
        placeholder: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
