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

    if (widget.url.contains('127.0.0.1') && widget.url.contains('proxy')) {
      try {
        final uri = Uri.parse(widget.url);
        final actualUrl = uri.queryParameters['url'];
        if (actualUrl != null && actualUrl.isNotEmpty) {
          playUrl = actualUrl;
          print('[VLC] Extracted direct URL from proxy params');
        } else {
          print('[VLC] Fetching proxy URL to get actual stream...');
          final response = await http.get(uri).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final body = response.body.trim();
            if (body.startsWith('http')) {
              playUrl = body;
              print('[VLC] Got stream URL from proxy response');
            }
          }
        }
      } catch (e) {
        print('[VLC] Proxy resolve error: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _resolvedUrl = playUrl;
      _isResolving = false;
    });

    _initVlc(playUrl);
  }

  void _initVlc(String url) {
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
      print('[VLC] Error: ${_controller!.value.errorDescription}');
    }

    if (_controller!.value.isPlaying && _hasError) {
      _hasError = false;
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
