import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/services/log_service.dart';
import 'package:tvbox_flutter/providers/player_provider.dart';
import 'package:tvbox_flutter/models/video_detail.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/ui/player/vlc_player.dart';
import 'package:tvbox_flutter/ui/player/system_player.dart';
import 'package:tvbox_flutter/utils/player_util.dart';
import 'package:tvbox_flutter/services/hls_parser.dart';
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
  String _parsedUrl = '';
  List<String> _urlSegments = [];
  
  // HLS 清晰度相关
  List<HLSQualityOption> _qualityOptions = [];
  HLSQualityOption? _currentQuality;
  bool _isResolvingQuality = false;
  String? _qualityResolveToken;
  CancelableOperation? _qualityResolveOperation;
  
  // 倍速控制
  double _playbackSpeed = 1.0;
  static const List<double> _availableSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _currentPlayer = Provider.of<PlayerProvider>(context, listen: false).defaultPlayer;
    _currentEpisodeIndex = widget.initialEpisodeIndex;
    _currentSourceIndex = widget.initialSourceIndex;
    
    final parsedResult = PlayerUtil.parsePlayUrl(widget.playUrl);
    _parsedUrl = parsedResult.url;
    _urlSegments = parsedResult.segments;
    
    log('[播放页] 🎬 初始化: player=$_currentPlayer, originalUrl=${widget.playUrl}, title=${widget.title}');
    log('[播放页] 📝 URL解析结果: url=$_parsedUrl, segmentsCount=${_urlSegments.length}, quality=${parsedResult.quality}');
    
    // 异步解析 HLS 清晰度
    _resolveQualityOptions();
  }

  @override
  void dispose() {
    _qualityResolveOperation?.cancel();
    super.dispose();
  }

  Future<void> _resolveQualityOptions() async {
    if (!HLSParser.looksLikeHLSURL(_parsedUrl)) {
      log('[播放页] ⚠️ 不是HLS URL，跳过清晰度解析');
      return;
    }

    setState(() {
      _isResolvingQuality = true;
    });

    final token = UniqueKey().toString();
    _qualityResolveToken = token;

    _qualityResolveOperation = CancelableOperation.fromFuture(
      HLSParser.resolveQualityOptions(_parsedUrl),
      onCancel: () => log('[播放页] 🔄 清晰度解析任务已取消'),
    );

    try {
      final options = await _qualityResolveOperation?.value;
      
      if (!mounted || _qualityResolveToken != token) return;
      
      setState(() {
        _qualityOptions = options ?? [];
        _isResolvingQuality = false;
        if (_qualityOptions.isNotEmpty) {
          _currentQuality = _qualityOptions.first;
          log('[播放页] ✅ HLS清晰度解析完成: ${_qualityOptions.length}个选项');
        }
      });
    } catch (e) {
      log('[播放页] ❌ 清晰度解析失败: $e');
      if (mounted) {
        setState(() {
          _isResolvingQuality = false;
        });
      }
    }
  }

  void _changeQuality(HLSQualityOption quality) {
    log('[播放页] 🔄 切换清晰度: ${_currentQuality?.name ?? '未知'} -> ${quality.name}');
    setState(() {
      _currentQuality = quality;
      _parsedUrl = quality.url;
    });
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
    
    _qualityResolveOperation?.cancel();
    
    setState(() {
      _currentEpisodeIndex = index;
      _isLoading = true;
      _qualityOptions = [];
      _currentQuality = null;
    });
    
    final episode = widget.videoDetail!.episodes[index];
    try {
      await NodeJSService.instance.initSpider();
      final result = await NodeJSService.instance.getPlayUrl(
        videoId: '',
        flag: episode.sourceName ?? '',
        playId: episode.url,
      );
      
      // 处理数组格式的响应
      String playUrl = '';
      final urlField = result['url'];
      if (urlField is List) {
        for (final item in urlField.reversed) {
          if (item is String && item.isNotEmpty) {
            playUrl = item;
            break;
          }
        }
      } else {
        playUrl = urlField?.toString() ?? result['parse']?.toString() ?? '';
      }
      
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
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换集数失败: $e')),
        );
      }
    }
  }

  Future<void> _changeSource(int index) async {
    if (widget.videoDetail == null) return;
    _qualityResolveOperation?.cancel();
    
    setState(() {
      _currentSourceIndex = index;
      _isLoading = true;
      _qualityOptions = [];
      _currentQuality = null;
    });
    
    final episode = widget.videoDetail!.episodes[_currentEpisodeIndex];
    try {
      await NodeJSService.instance.initSpider();
      final result = await NodeJSService.instance.getPlayUrl(
        videoId: '',
        flag: episode.sourceName ?? '',
        playId: episode.url,
      );
      
      String playUrl = '';
      final urlField = result['url'];
      if (urlField is List) {
        for (final item in urlField.reversed) {
          if (item is String && item.isNotEmpty) {
            playUrl = item;
            break;
          }
        }
      } else {
        playUrl = urlField?.toString() ?? result['parse']?.toString() ?? '';
      }
      
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
        setState(() => _isLoading = false);
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
    if (_parsedUrl.isEmpty) {
      return const Center(
        child: Text('无法解析播放地址', style: TextStyle(color: Colors.white)),
      );
    }
    
    switch (_currentPlayer) {
      case PlayerType.vlc:
        return VlcPlayerWidget(
          url: _parsedUrl,
          playbackSpeed: _playbackSpeed,
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
          url: _parsedUrl,
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
                _buildQualityButton(),
                _buildSpeedButton(),
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

  Widget _buildSpeedButton() {
    return PopupMenuButton<double>(
      tooltip: '倍速',
      onSelected: (speed) {
        setState(() {
          _playbackSpeed = speed;
          log('[播放页] 🔄 切换倍速: ${speed}x');
        });
      },
      itemBuilder: (context) {
        return _availableSpeeds.map((speed) {
          return PopupMenuItem(
            value: speed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${speed}x'),
                if (_playbackSpeed == speed)
                  const Icon(Icons.check, color: Colors.blue),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.speed, size: 16),
            const SizedBox(width: 4),
            Text(
              '${_playbackSpeed}x',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityButton() {
    if (_qualityOptions.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return PopupMenuButton<HLSQualityOption>(
      icon: const Icon(Icons.high_quality),
      tooltip: '清晰度',
      onSelected: _changeQuality,
      itemBuilder: (context) {
        return _qualityOptions.map((option) {
          return PopupMenuItem(
            value: option,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(option.name),
                if (_currentQuality?.url == option.url)
                  const Icon(Icons.check, color: Colors.blue),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.high_quality, size: 16),
            const SizedBox(width: 4),
            Text(
              _currentQuality?.name ?? '高清',
              style: const TextStyle(fontSize: 14),
            ),
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