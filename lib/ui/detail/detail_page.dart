import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/models/video_detail.dart';
import 'package:tvbox_flutter/ui/player/video_player_page.dart';
import 'package:tvbox_flutter/providers/history_provider.dart';
import 'package:tvbox_flutter/providers/favorite_provider.dart';
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
      final data = await NodeJSService.instance.getVideoDetail(widget.videoId);
      final detail = VideoDetail.fromJson(data);
      final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
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
                  if (detail.director != null) Text('导演：${detail.director}'),
                  if (detail.actor != null) Text('演员：${detail.actor}'),
                  const Divider(),
                  const Text('选集', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  onPressed: () async {
                    final source = episode.sources.first;
                    final playUrl = await NodeJSService.instance.getPlayUrl(source.url);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerPage(
                          playUrl: playUrl,
                          title: '${detail.name} - ${episode.name}',
                          videoDetail: detail,
                          initialEpisodeIndex: index,
                          initialSourceIndex: 0,
                        ),
                      ),
                    );
                  },
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
