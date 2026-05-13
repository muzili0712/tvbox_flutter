import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/services/log_service.dart';
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
  bool _isLoading = false;
  bool _showControls = true;
  double _currentPosition = 0;
  double _duration = 0;
  bool _isPlaying = false;
  late int _currentEpisodeIndex;
  late int _currentSourceIndex;

  @override
  void initState() {
    super.initState();
    _currentPlayer = Provider.of<PlayerProvider>(context, listen: false).defaultPlayer;
    _currentEpisodeIndex = widget.initialEpisodeIndex;
    _currentSourceIndex = widget.initialSourceIndex;
    log('[播放页] 🎬 初始化: player=$_currentPlayer, url=${widget.playUrl}, title=${widget.title}');
  }

  void _changePlayer(PlayerType player) {
    log('[播放页] 🔄 切换播放器: $_currentPlayer -> $player');
    setState(() {
      _currentPlayer = player;
      _isLoading = false;
    });
  }

  Future<void> _changeEpisode(int index) async {
    if (widget.videoDetail == null) return;
    log('[播放页] 🔄 切换集数: $_currentEpisodeIndex -> $index');
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
      log('[播放页] 🔄 切换集数结果: playUrl=$playUrl');
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
      log('[播放页] ❌ 切换集数失败: $e');
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
    switch (_currentPlayer) {
      case PlayerType.vlc:
        return VlcPlayerWidget(
          url: widget.playUrl,
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
          url: widget.playUrl,
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
                  max: _duration > 0 ? _duration : 1,
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
