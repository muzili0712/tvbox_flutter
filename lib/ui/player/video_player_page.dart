import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:tvbox_flutter/providers/player_provider.dart';
import 'package:tvbox_flutter/models/video_detail.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/ui/player/vlc_player.dart';
import 'package:tvbox_flutter/ui/player/system_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class VideoPlayerPage extends StatefulWidget {
  final String playUrl;
  final String title;
  final VideoDetail? videoDetail;
  final int initialEpisodeIndex;
  final int initialSourceIndex;

  const VideoPlayerPage({
    super.key,
    required this.playUrl,
    required this.title,
    this.videoDetail,
    this.initialEpisodeIndex = 0,
    this.initialSourceIndex = 0,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late PlayerType _currentPlayer;
  bool _isLoading = true;
  bool _showControls = true;
  double _currentPosition = 0;
  double _duration = 0;
  bool _isPlaying = false;
  late int _currentEpisodeIndex;
  late int _currentSourceIndex;
  String _resolvedPlayUrl = '';
  bool _urlResolved = false;

  @override
  void initState() {
    super.initState();
    _currentPlayer = Provider.of<PlayerProvider>(context, listen: false).defaultPlayer;
    _currentEpisodeIndex = widget.initialEpisodeIndex;
    _currentSourceIndex = widget.initialSourceIndex;
    _resolvedPlayUrl = widget.playUrl;
    _resolveAndLoadVideo();
  }

  Future<void> _resolveAndLoadVideo() async {
    setState(() => _isLoading = true);
    
    String finalUrl = widget.playUrl;
    
    if (widget.playUrl.contains('127.0.0.1') && widget.playUrl.contains('proxy')) {
      try {
        final uri = Uri.parse(widget.playUrl);
        final actualUrl = uri.queryParameters['url'];
        if (actualUrl != null && actualUrl.isNotEmpty) {
          finalUrl = actualUrl;
          print('[VideoPlayer] Extracted direct URL from proxy: ${finalUrl.substring(0, finalUrl.length > 100 ? 100 : finalUrl.length)}...');
        } else {
          print('[VideoPlayer] No url param in proxy, trying HTTP fetch...');
          final response = await http.get(uri).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final body = response.body.trim();
            if (body.startsWith('http') && (body.contains('.m3u8') || body.contains('.mp4'))) {
              finalUrl = body;
              print('[VideoPlayer] Got actual stream URL: ${finalUrl.substring(0, 100)}...');
            }
          }
        }
      } catch (e) {
        print('[VideoPlayer] Proxy resolve error: $e');
      }
    }
    
    setState(() {
      _resolvedPlayUrl = finalUrl;
      _urlResolved = true;
      _isLoading = false;
    });
  }

  void _loadVideo() {
    // 空实现，避免老函数调用
  }

  void _changePlayer(PlayerType player) {
    setState(() {
      _currentPlayer = player;
      _isLoading = true;
    });
    _loadVideo();
  }

  Future<void> _changeEpisode(int index) async {
    if (widget.videoDetail == null) return;
    setState(() {
      _currentEpisodeIndex = index;
      _isLoading = true;
    });
    final episode = widget.videoDetail!.episodes[index];
    try {
      await NodeJSService.instance.initSpider();
      final result = await NodeJSService.instance.getPlayUrl(
        videoId: '',
        flag: episode.sourceName ?? '',
        playId: episode.url,
      );
      final playUrl = result['url']?.toString() ?? result['parse']?.toString() ?? '';
      if (playUrl.isEmpty || !mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(
            playUrl: playUrl,
            title: '${widget.videoDetail!.name} - ${episode.name}',
            videoDetail: widget.videoDetail,
            initialEpisodeIndex: index,
            initialSourceIndex: 0,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换集数失败: $e')),
        );
      }
    }
  }

  Future<void> _changeSource(int index) async {
    if (widget.videoDetail == null) return;
    setState(() {
      _currentSourceIndex = index;
      _isLoading = true;
    });
    final episode = widget.videoDetail!.episodes[_currentEpisodeIndex];
    try {
      await NodeJSService.instance.initSpider();
      final result = await NodeJSService.instance.getPlayUrl(
        videoId: '',
        flag: episode.sourceName ?? '',
        playId: episode.url,
      );
      final playUrl = result['url']?.toString() ?? result['parse']?.toString() ?? '';
      if (playUrl.isEmpty || !mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(
            playUrl: playUrl,
            title: '${widget.videoDetail!.name} - ${episode.name}',
            videoDetail: widget.videoDetail,
            initialEpisodeIndex: _currentEpisodeIndex,
            initialSourceIndex: index,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换源失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildPlayer(),
          if (_showControls) _buildControls(),
          if (_isLoading) _buildLoading(),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    if (!_urlResolved) {
      return const SizedBox.shrink();
    }
    
    final playUrl = _resolvedPlayUrl.isNotEmpty ? _resolvedPlayUrl : widget.playUrl;
    final playerKey = ValueKey<String>(playUrl);
    
    switch (_currentPlayer) {
      case PlayerType.vlc:
        return VlcPlayerWidget(
          key: playerKey,
          url: playUrl,
          onPlayerStateChanged: (isPlaying, position, duration) {
            setState(() {
              _isPlaying = isPlaying;
              _currentPosition = position;
              _duration = duration;
            });
          },
          onTap: () => setState(() => _showControls = !_showControls),
        );
      case PlayerType.system:
        return SystemPlayerWidget(
          key: playerKey,
          url: playUrl,
          onPlayerStateChanged: (isPlaying, position, duration) {
            setState(() {
              _isPlaying = isPlaying;
              _currentPosition = position;
              _duration = duration;
            });
          },
          onTap: () => setState(() => _showControls = !_showControls),
        );
    }
  }

  Widget _buildControls() {
    return GestureDetector(
      onTap: () => setState(() => _showControls = false),
      child: Container(
        color: Colors.black54,
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(widget.title),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                PopupMenuButton<PlayerType>(
                  icon: const Icon(Icons.settings),
                  onSelected: _changePlayer,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: PlayerType.vlc,
                      child: Text('VLC播放器'),
                    ),
                    PopupMenuItem(
                      value: PlayerType.system,
                      child: Text('系统播放器'),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            _buildPlayerControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _currentPosition,
                  max: _duration,
                  onChanged: (value) {},
                  activeColor: Colors.blue,
                  inactiveColor: Colors.white30,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: _currentEpisodeIndex > 0
                    ? () => _changeEpisode(_currentEpisodeIndex - 1)
                    : null,
              ),
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: widget.videoDetail != null &&
                        _currentEpisodeIndex < widget.videoDetail!.episodes.length - 1
                    ? () => _changeEpisode(_currentEpisodeIndex + 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          if (widget.videoDetail != null) _buildEpisodeSelector(),
        ],
      ),
    );
  }

  Widget _buildEpisodeSelector() {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.videoDetail!.episodes.length,
        itemBuilder: (context, index) {
          return Container(
            width: 60,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: index == _currentEpisodeIndex
                    ? Colors.blue
                    : Colors.grey[800],
                padding: EdgeInsets.zero,
              ),
              onPressed: () => _changeEpisode(index),
              child: Text('${index + 1}'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: SpinKitFadingCircle(
        color: Colors.white,
        size: 50.0,
      ),
    );
  }

  String _formatDuration(double milliseconds) {
    final duration = Duration(milliseconds: milliseconds.toInt());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours}:$minutes:$seconds';
  }
}
