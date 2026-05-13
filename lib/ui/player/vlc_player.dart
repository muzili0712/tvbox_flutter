import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

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
  late VlcPlayerController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController.network(
      widget.url,
      autoPlay: true,
      options: VlcPlayerOptions(
        video: VlcVideoOptions([
          'network-caching=3000',
          'codec=avcodec',
        ]),
        audio: VlcAudioOptions([]),
        subtitle: VlcSubtitleOptions([]),
      ),
    );
    
    _controller.addListener(_onPlayerStateChanged);
  }

  void _onPlayerStateChanged() {
    if (_controller.value.hasError && !_hasError) {
      _hasError = true;
      print('[VLC] Error: ${_controller.value.errorDescription}');
    }
    
    if (_controller.value.isPlaying && _hasError) {
      _hasError = false;
    }
    
    widget.onPlayerStateChanged(
      _controller.value.isPlaying,
      _controller.value.position.inMilliseconds.toDouble(),
      _controller.value.duration.inMilliseconds.toDouble(),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: VlcPlayer(
        controller: _controller,
        aspectRatio: 16 / 9,
        placeholder: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
