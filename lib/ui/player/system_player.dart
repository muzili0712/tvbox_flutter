import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:tvbox_flutter/services/log_service.dart';

class SystemPlayerWidget extends StatefulWidget {
  final String url;
  final Function(bool isPlaying, double position, double duration) onPlayerStateChanged;
  final VoidCallback onTap;

  const SystemPlayerWidget({
    super.key,
    required this.url,
    required this.onPlayerStateChanged,
    required this.onTap,
  });

  @override
  State<SystemPlayerWidget> createState() => _SystemPlayerWidgetState();
}

class _SystemPlayerWidgetState extends State<SystemPlayerWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    log('[系统播放器] 🎬 初始化: url=${widget.url}');
    
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)',
        },
      );
      
      await _videoController!.initialize();
      
      if (!mounted) return;
      
      log('[系统播放器] ✅ 视频初始化成功，时长: ${_videoController!.value.duration}');
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        showControls: false,
        errorBuilder: (context, errorMessage) {
          log('[系统播放器] ❌ Chewie错误: $errorMessage');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 8),
                Text(
                  '播放出错: ${errorMessage.length > 50 ? errorMessage.substring(0, 50) : errorMessage}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      );
      
      _videoController!.addListener(_onPlayerStateChanged);
      
      await _videoController!.play();
      log('[系统播放器] ✅ 开始播放');
      
      setState(() {});
    } catch (error) {
      log('[系统播放器] ❌ 初始化失败: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onPlayerStateChanged);
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _onPlayerStateChanged() {
    if (_videoController == null) return;
    
    if (_videoController!.value.hasError && !_hasError) {
      _hasError = true;
      _errorMessage = _videoController!.value.errorDescription;
      log('[系统播放器] ❌ 播放错误: $_errorMessage');
    }
    
    if (_videoController!.value.isPlaying && _hasError) {
      _hasError = false;
      log('[系统播放器] ✅ 恢复播放');
    }
    
    widget.onPlayerStateChanged(
      _videoController!.value.isPlaying,
      _videoController!.value.position.inMilliseconds.toDouble(),
      _videoController!.value.duration.inMilliseconds.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Center(
        child: _chewieController != null
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
