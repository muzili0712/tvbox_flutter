import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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

  void _initPlayer() {
    print('[系统播放器] 🎬 初始化: url=${widget.url}');
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    
    _videoController!.initialize().then((_) {
      if (!mounted) return;
      print('[系统播放器] ✅ 初始化成功！开始播放');
      setState(() {});
    }).catchError((error) {
      print('[系统播放器] ❌ 初始化失败: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = error.toString();
        });
      }
    });

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      showControls: false,
      errorBuilder: (context, errorMessage) {
        print('[系统播放器] ❌ Chewie错误: $errorMessage');
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
      print('[系统播放器] ❌ 播放错误: $_errorMessage');
    }
    
    if (_videoController!.value.isPlaying && _hasError) {
      _hasError = false;
      print('[系统播放器] ✅ 恢复播放');
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
