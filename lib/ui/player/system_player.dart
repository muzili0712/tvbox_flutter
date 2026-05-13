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
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    
    _videoController!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    }).catchError((error) {
      print('[SystemPlayer] Initialize error: $error');
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
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                '播放出错',
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
      print('[SystemPlayer] Error: $_errorMessage');
    }
    
    if (_videoController!.value.isPlaying && _hasError) {
      _hasError = false;
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
