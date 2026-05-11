import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/providers/source_provider.dart';
import 'package:tvbox_flutter/ui/widgets/video_card.dart';
import 'package:tvbox_flutter/ui/search/search_page.dart';
import 'package:tvbox_flutter/ui/settings/settings_page.dart';
import 'package:tvbox_flutter/ui/history/history_page.dart';
import 'package:tvbox_flutter/ui/favorite/favorite_page.dart';
import 'package:tvbox_flutter/ui/cloud_drive/cloud_drive_page.dart';
import 'package:tvbox_flutter/ui/live/live_page.dart';
import 'package:tvbox_flutter/ui/widgets/bottom_nav_bar.dart';
import 'package:tvbox_flutter/ui/detail/detail_page.dart';
import 'package:tvbox_flutter/ui/log/log_viewer_page.dart';
import 'package:tvbox_flutter/models/video_item.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  bool _isLoading = true;

  List<Widget>? _pages;

  Widget _getPage(int index) {
    if (_pages == null) {
      _pages = List.filled(5, const SizedBox.shrink());
    }

    switch (index) {
      case 0:
        return const HomeContent();
      case 1:
        return const LivePage();
      case 2:
        return const CloudDrivePage();
      case 3:
        return const HistoryPage();
      case 4:
        return const FavoritePage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadHomeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);

    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    await sourceProvider.loadHomeContent();

    if (sourceProvider.categories.isNotEmpty) {
      _tabController = TabController(
        length: sourceProvider.categories.length,
        vsync: this,
      );
    }

    setState(() => _isLoading = false);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getPage(_selectedIndex),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadHomeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);

    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    await sourceProvider.loadHomeContent();

    if (sourceProvider.categories.isNotEmpty) {
      _tabController = TabController(
        length: sourceProvider.categories.length,
        vsync: this,
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TVBox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: '查看日志',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LogViewerPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
        bottom: _isLoading ||
                Provider.of<SourceProvider>(context).categories.isEmpty
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: Provider.of<SourceProvider>(context)
                    .categories
                    .map((category) => Tab(text: category['type_name'] ?? category['name']))
                    .toList(),
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SpinKitFadingCircle(
          color: Colors.blue,
          size: 50.0,
        ),
      );
    }

    final sourceProvider = Provider.of<SourceProvider>(context);

    if (sourceProvider.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('请先添加数据源'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsPage()),
                );
              },
              child: const Text('添加数据源'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: sourceProvider.categories.map((category) {
        return _buildCategoryContent(category);
      }).toList(),
    );
  }

  Widget _buildCategoryContent(Map<String, dynamic> category) {
    final typeId = category['type_id']?.toString() ?? '';
    return _CategoryContentLoader(
        typeId: typeId,
        typeName: category['type_name'] ?? '');
  }
}

class _CategoryContentLoader extends StatefulWidget {
  final String typeId;
  final String typeName;

  const _CategoryContentLoader(
      {required this.typeId, required this.typeName});

  @override
  State<_CategoryContentLoader> createState() =>
      _CategoryContentLoaderState();
}

class _CategoryContentLoaderState extends State<_CategoryContentLoader>
    with AutomaticKeepAliveClientMixin {
  List<VideoItem> _videos = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final result = await NodeJSService.instance.getCategoryContent(
        categoryId: widget.typeId,
        page: _currentPage,
      );

      final list = result['list'] as List<dynamic>? ?? [];
      final pagecount = result['pagecount'] as int? ?? 1;

      final newVideos = list
          .map((json) =>
              VideoItem.fromJson(json as Map<String, dynamic>))
          .toList();

      setState(() {
        if (_currentPage == 1) {
          _videos = newVideos;
        } else {
          _videos.addAll(newVideos);
        }
        _hasMore = _currentPage < pagecount;
        _currentPage++;
        _isLoading = false;
      });
    } catch (e) {
      print('Failed to load category content: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _videos.isEmpty) {
      return const Center(
        child: SpinKitFadingCircle(color: Colors.blue, size: 50.0),
      );
    }

    if (_videos.isEmpty) {
      return const Center(child: Text('暂无内容'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _videos.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _videos.length) {
          _loadContent();
          return const Center(child: CircularProgressIndicator());
        }

        final video = _videos[index];
        return VideoCard(
          video: video,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailPage(videoId: video.id),
              ),
            );
          },
        );
      },
    );
  }
}
