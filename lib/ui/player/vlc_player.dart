import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:http/http.dart' as http;
import 'package:tvbox_flutter/services/log_service.dart';

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
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _resolveAndPlay();
  }

  Future<void> _resolveAndPlay() async {
    String playUrl = widget.url;
    log('[VLC播放器] 🎬 开始解析: originalUrl=${widget.url}');

    // 检查是否是数组格式（来自 wogg/网盘源）
    if (widget.url.startsWith('[') && widget.url.endsWith(']')) {
      log('[VLC播放器] 🔍 检测到数组格式，尝试解析...');
      try {
        // 尝试从数组中提取 URL
        RegExp urlRegex = RegExp(r'(https?://[^\s,\'\"]+)');
        Iterable<RegExpMatch> matches = urlRegex.allMatches(widget.url);
        if (matches.isNotEmpty) {
          // 取最后一个匹配的 URL，通常是真实播放地址
          playUrl = matches.last.group(0)!;
          log('[VLC播放器] ✅ 从数组中提取到URL: $playUrl');
        }
      } catch (e) {
        log('[VLC播放器] ⚠️ 数组解析失败: $e');
      }
    }

    if (widget.url.contains('127.0.0.1') && widget.url.contains('proxy')) {
      log('[VLC播放器] 🔗 检测到代理URL，开始解析真实地址...');
      try {
        final uri = Uri.parse(widget.url);
        final actualUrl = uri.queryParameters['url'];
        if (actualUrl != null && actualUrl.isNotEmpty) {
          playUrl = actualUrl;
          log('[VLC播放器] ✅ 从proxy参数提取到直接URL: $playUrl');
        } else {
          log('[VLC播放器] 📡 proxy参数中没有url，尝试HTTP GET获取...');
          final response = await http.get(uri).timeout(const Duration(seconds: 10));
          log('[VLC播放器] 📡 proxy GET响应: status=${response.statusCode}, body=${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
          if (response.statusCode == 200) {
            final body = response.body.trim();
            if (body.startsWith('http')) {
              playUrl = body;
              log('[VLC播放器] ✅ 从proxy响应获取到流地址: $playUrl');
            } else {
              log('[VLC播放器] ⚠️ proxy响应不是http开头: $body');
            }
          } else {
            log('[VLC播放器] ❌ proxy GET失败: status=${response.statusCode}');
          }
        }
      } catch (e) {
        log('[VLC播放器] ❌ 代理解析错误: $e');
      }
    } else {
      log('[VLC播放器] 📡 非代理URL，直接播放');
    }

    log('[VLC播放器] 🎬 最终播放地址: $playUrl');

    if (!mounted) return;

    setState(() {
      _resolvedUrl = playUrl;
      _isResolving = false;
    });

    _initVlc(playUrl);
  }

  Future<void> _initVlc(String url) async {
    log('[VLC播放器] 🎬 初始化VLC控制器: url=$url');
    
    final isM3U8 = url.contains('.m3u8') || url.contains('m3u8');
    log('[VLC播放器] 📋 URL类型: ${isM3U8 ? 'M3U8/HLS' : 'MP4/Direct'}');
    
    if (_controller != null) {
      _controller!.removeListener(_onPlayerStateChanged);
      await _controller!.dispose();
      _controller = null;
    }
    
    _controller = VlcPlayerController.network(
      url,
      autoPlay: true,
      options: VlcPlayerOptions(
        video: VlcVideoOptions([
          '--network-caching=15000',
          '--file-caching=15000',
          '--live-caching=15000',
          '--avformat-options',
          'fflags=nogenpts',
          if (isM3U8) '--hls-live-edge=3',
          if (isM3U8) '--hls-segment-threads=1',
        ]),
        audio: VlcAudioOptions([
          '--network-caching=15000',
        ]),
        subtitle: VlcSubtitleOptions([]),
        http: VlcHttpOptions([
          '--http-user-agent=Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
          '--http-referrer=https://vip.123pan.cn/',
          '--http-continuous-flow',
          '--http-connect-timeout=10',
          '--http-max-connections=3',
        ]),
        rtp: VlcRtpOptions([]),
        advanced: VlcAdvancedOptions([
          '--avcodec-threads=1',
          '--clock-jitter=0',
          '--clock-synchro=0',
          '--sout-mux-caching=15000',
        ]),
      ),
    );

    _controller!.addListener(_onPlayerStateChanged);

    setState(() {});
    
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted && _controller != null) {
      final isPlaying = _controller!.value.isPlaying;
      final duration = _controller!.value.duration.inMilliseconds.toDouble();
      log('[VLC播放器] 📊 初始状态检查: isPlaying=$isPlaying, duration=$duration');
      
      if (!isPlaying && !_controller!.value.hasError && _retryCount < _maxRetries) {
        _retryCount++;
        log('[VLC播放器] 🔄 尝试重新播放 (第$_retryCount次)...');
        await _controller!.play();
        await Future.delayed(const Duration(seconds: 3));
        
        if (mounted && _controller != null) {
          final retryIsPlaying = _controller!.value.isPlaying;
          log('[VLC播放器] 📊 重试后状态: isPlaying=$retryIsPlaying');
        }
      }
    }
  }

  void _onPlayerStateChanged() {
    if (_controller == null) return;

    if (_controller!.value.hasError && !_hasError) {
      _hasError = true;
      log('[VLC播放器] ❌ 播放错误: ${_controller!.value.errorDescription}');
      
      if (_retryCount < _maxRetries) {
        _retryCount++;
        log('[VLC播放器] 🔄 检测到错误，尝试重新初始化 (第$_retryCount次)...');
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && _resolvedUrl != null) {
            _hasError = false;
            _initVlc(_resolvedUrl!);
          }
        });
      }
    }

    if (_controller!.value.isPlaying && _hasError) {
      _hasError = false;
      log('[VLC播放器] ✅ 恢复播放');
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            const Text('播放器初始化失败', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isResolving = true;
                  _retryCount = 0;
                  _hasError = false;
                });
                _resolveAndPlay();
              },
              child: const Text('重试'),
            ),
          ],
        ),
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
