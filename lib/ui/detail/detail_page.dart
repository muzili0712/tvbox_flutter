import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/models/video_detail.dart';
import 'package:tvbox_flutter/ui/player/video_player_page.dart';
import 'package:tvbox_flutter/providers/history_provider.dart';
import 'package:tvbox_flutter/providers/favorite_provider.dart';
import 'package:tvbox_flutter/services/log_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tvbox_flutter/models/video_item.dart';

class DetailPage extends StatefulWidget {
  final String videoId;

  const DetailPage({super.key, required this.videoId});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  VideoDetail? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      log('[详情页] 📖 加载视频详情: videoId=${widget.videoId}');
      await NodeJSService.instance.initSpider();
      final result =
          await NodeJSService.instance.getVideoDetail(videoId: widget.videoId);
      final list = result['list'] as List<dynamic>? ?? [];
      log('[详情页] 📖 详情响应: list.length=${list.length}');
      if (list.isNotEmpty) {
        final vod = list.first as Map<String, dynamic>;
        log('[详情页] 📖 视频信息: name=${vod['vod_name']}, id=${vod['vod_id']}');

        final playFrom =
            (vod['vod_play_from'] as String? ?? '').split('\$\$\$');
        final playUrl =
            (vod['vod_play_url'] as String? ?? '').split('\$\$\$');

        log('[详情页] 📖 播放源: playFrom.length=${playFrom.length}, playUrl.length=${playUrl.length}');
        for (int i = 0; i < playFrom.length; i++) {
          final sourceEpisodes = playUrl.length > i ? playUrl[i].split('#').length : 0;
          log('[详情页] 📖   源${i + 1}: name=${playFrom[i]}, 集数=$sourceEpisodes');
        }

        List<Episode> episodes = [];
        for (int i = 0; i < playUrl.length && i < playFrom.length; i++) {
          final sources = playUrl[i].split('#');
          final sourceName = playFrom[i];
          for (final source in sources) {
            final parts = source.split('\$');
            if (parts.length >= 2) {
              episodes.add(Episode(
                name: parts[0],
                url: parts[1],
                sourceName: sourceName,
              ));
            }
          }
        }

        log('[详情页] 📖 解析出${episodes.length}个剧集');
        if (episodes.isNotEmpty) {
          log('[详情页] 📖 第一集: name=${episodes.first.name}, sourceName=${episodes.first.sourceName}, url=${episodes.first.url.length > 80 ? '${episodes.first.url.substring(0, 80)}...' : episodes.first.url}');
        }

        final detail = VideoDetail(
          id: vod['vod_id']?.toString() ?? '',
          name: vod['vod_name']?.toString() ?? '',
          cover: vod['vod_pic']?.toString() ?? '',
          desc: vod['vod_content']?.toString() ?? '',
          year: vod['vod_year']?.toString(),
          area: vod['vod_area']?.toString(),
          director: vod['vod_director']?.toString(),
          actor: vod['vod_actor']?.toString(),
          episodes: episodes,
        );

        final historyProvider =
            Provider.of<HistoryProvider>(context, listen: false);
        historyProvider.addToHistory(
          VideoItem(
            id: detail.id,
            name: detail.name,
            cover: detail.cover,
            desc: detail.desc,
          ),
        );

        setState(() {
          _detail = detail;
        });
      } else {
        log('[详情页] ⚠️ 详情返回空列表');
      }
    } catch (e) {
      log('[详情页] ❌ 加载详情失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playEpisode(int index) async {
    if (_detail == null) return;
    final episode = _detail!.episodes[index];

    log('[详情页] 🎬 点击播放: ${_detail!.name} - ${episode.name}, sourceName=${episode.sourceName}, url=${episode.url.length > 80 ? '${episode.url.substring(0, 80)}...' : episode.url}');

    try {
      await NodeJSService.instance.initSpider();

      final result = await NodeJSService.instance.getPlayUrl(
        videoId: '',
        flag: episode.sourceName ?? '',
        playId: episode.url,
      );
      final playUrl = result['url']?.toString() ?? result['parse']?.toString() ?? '';

      log('[详情页] 🎬 getPlayUrl结果: flag=${episode.sourceName}, id=${episode.url}, playUrl=$playUrl');

      if (playUrl.isEmpty) {
        log('[详情页] ❌ 播放地址为空！');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('获取播放地址失败')),
          );
        }
        return;
      }

      log('[详情页] ✅ 跳转到播放页面: url=$playUrl');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerPage(
              playUrl: playUrl,
              title: '${_detail!.name} - ${episode.name}',
              videoDetail: _detail,
              initialEpisodeIndex: index,
              initialSourceIndex: 0,
            ),
          ),
        );
      }
    } catch (e) {
      log('[详情页] ❌ 播放失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_detail == null) {
      return const Scaffold(body: Center(child: Text('加载失败')));
    }
    final detail = _detail!;
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    final isFavorite = favoriteProvider.isFavorite(detail.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(detail.name),
              background: CachedNetworkImage(
                imageUrl: detail.cover,
                fit: BoxFit.cover,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                ),
                onPressed: () {
                  favoriteProvider.toggleFavorite(
                    VideoItem(
                      id: detail.id,
                      name: detail.name,
                      cover: detail.cover,
                    ),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (detail.desc != null) Text('简介：${detail.desc}'),
                  if (detail.year != null) Text('年份：${detail.year}'),
                  if (detail.area != null) Text('地区：${detail.area}'),
                  if (detail.director != null)
                    Text('导演：${detail.director}'),
                  if (detail.actor != null) Text('演员：${detail.actor}'),
                  const Divider(),
                  const Text('选集',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final episode = detail.episodes[index];
                return ElevatedButton(
                  onPressed: () => _playEpisode(index),
                  child: Text(episode.name),
                );
              },
              childCount: detail.episodes.length,
            ),
          ),
        ],
      ),
    );
  }
}
