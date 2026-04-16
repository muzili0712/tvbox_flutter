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

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController.network(
      widget.url,
      autoPlay: true,
      options: VlcPlayerOptions(
        video: VlcVideoOptions({}),
        audio: VlcAudioOptions({}),
        subtitle: VlcSubtitleOptions({}),
        extras: [
          '--network-caching=1000',
          '--rtsp-tcp',
        ],
      ),
    );
    
    _controller.addListener(_onPlayerStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onPlayerStateChanged() {
    widget.onPlayerStateChanged(
      _controller.value.isPlaying,
      _controller.value.position.inMilliseconds.toDouble(),
      _controller.value.duration.inMilliseconds.toDouble(),
    );
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
