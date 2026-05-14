import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tvbox_flutter/services/log_service.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/providers/source_provider.dart';
import 'package:tvbox_flutter/ui/widgets/video_card.dart';
import 'package:tvbox_flutter/ui/search/search_page.dart';
import 'package:tvbox_flutter/ui/settings/settings_page.dart';
import 'package:tvbox_flutter/ui/settings/web_config_page.dart';
import 'package:tvbox_flutter/ui/history/history_page.dart';
import 'package:tvbox_flutter/ui/favorite/favorite_page.dart';
import 'package:tvbox_flutter/ui/cloud_drive/cloud_drive_page.dart';
import 'package:tvbox_flutter/ui/live/live_page.dart';
import 'package:tvbox_flutter/ui/widgets/bottom_nav_bar.dart';
import 'package:tvbox_flutter/ui/detail/detail_page.dart';
import 'package:tvbox_flutter/ui/log/log_viewer_page.dart';
import 'package:tvbox_flutter/ui/settings/source_management_page.dart';
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

  Widget _getPage(int index) {
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  bool _isLoading = true;
  bool _wasPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 0, vsync: this);
    _loadHomeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  void _safeUpdateTabController(int newLength) {
    if (_tabController.length != newLength) {
      if (mounted) {
        final oldController = _tabController;
        _tabController = TabController(length: newLength, vsync: this);
        oldController.dispose();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    log('[主页] 📱 生命周期: $state');
    
    // 记录是否曾经暂停
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
    }
    
    // 当应用从后台恢复时，重新加载首页
    if (_wasPaused && state == AppLifecycleState.resumed) {
      log('[主页] ⚡ 从后台恢复，重新加载数据');
      _wasPaused = false;
      _loadHomeData();
    }
  }

  Future<void> _loadHomeData() async {
    log('[主页] 🏠 开始加载首页数据...');
    setState(() => _isLoading = true);

    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);

    await sourceProvider.ensureLoaded();
    log('[主页] 🏠 ensureLoaded完成: currentSource=${sourceProvider.currentSource?.name ?? "无"}, hasSpiderServer=${NodeJSService.instance.hasSpiderServer}');

    final nodejs = NodeJSService.instance;

    if (sourceProvider.currentSource != null &&
        sourceProvider.currentSource!.sourceType == 'remote' &&
        !nodejs.hasSpiderServer) {
      String loadUrl = sourceProvider.currentSource!.url;
      if (loadUrl.endsWith('.js.md5')) {
        loadUrl = loadUrl.substring(0, loadUrl.length - 4);
      }
      log('[主页] 🏠 Spider未启动，从URL加载: $loadUrl');
      final success = await nodejs.loadSourceFromURL(loadUrl);
      log('[主页] 🏠 loadSourceFromURL结果: $success, spiderPort=${nodejs.spiderPort}');
      if (!success) {
        log('[主页] ❌ 加载源失败，停止加载首页');
        setState(() => _isLoading = false);
        return;
      }
    }

    await sourceProvider.loadHomeContent();
    log('[主页] 🏠 loadHomeContent完成: categories=${sourceProvider.categories.length}');

    if (sourceProvider.categories.isNotEmpty && mounted) {
      setState(() {
        _safeUpdateTabController(sourceProvider.categories.length);
      });
      log('[主页] ✅ 首页TabBar已更新: ${sourceProvider.categories.length}个分类');
    } else {
      log('[主页] ⚠️ 没有分类数据，首页显示"内容未加载"');
      if (mounted) {
        setState(() {
          _safeUpdateTabController(0);
        });
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Consumer<SourceProvider>(
          builder: (context, provider, _) {
            if (provider.sites.length > 1) {
              return PopupMenuButton<Map<String, dynamic>>(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz, size: 20),
                    Flexible(
                      child: Text(
                        provider.currentSite?['name'] ?? '',
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                onSelected: (site) {
                  provider.setCurrentSite(site).then((_) {
                    if (mounted) {
                      setState(() {
                        if (provider.categories.isNotEmpty) {
                          _safeUpdateTabController(provider.categories.length);
                        } else {
                          _safeUpdateTabController(0);
                        }
                      });
                    }
                  });
                },
                itemBuilder: (context) => provider.sites.map((site) {
                  final key = site['key'] as String? ?? '';
                  final name = site['name'] as String? ?? key;
                  final isCurrent = provider.currentSite?['key'] == key;
                  return PopupMenuItem<Map<String, dynamic>>(
                    value: site,
                    child: Row(
                      children: [
                        Icon(
                          isCurrent
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isCurrent ? Colors.green : null,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name)),
                      ],
                    ),
                  );
                }).toList(),
              );
            }
            return const SizedBox.shrink();
          },
        ),
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

    if (sourceProvider.sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.source_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('请添加数据源', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SourceManagementPage()),
                ).then((_) => _loadHomeData());
              },
              child: const Text('添加数据源'),
            ),
          ],
        ),
      );
    }

    if (sourceProvider.categories.isEmpty && !sourceProvider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('内容未加载', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadHomeData(),
              child: const Text('加载内容'),
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
    final siteKey = Provider.of<SourceProvider>(context).currentSite?['key'] ?? '';
    return _CategoryContentLoader(
        typeId: typeId,
        typeName: category['type_name'] ?? '',
        siteKey: siteKey);
  }
}

class _CategoryContentLoader extends StatefulWidget {
  final String typeId;
  final String typeName;
  final String siteKey;

  const _CategoryContentLoader({
    required this.typeId,
    required this.typeName,
    required this.siteKey,
  });

  @override
  State<_CategoryContentLoader> createState() =>
      _CategoryContentLoaderState();
}

class _ImageViewerPage extends StatelessWidget {
  final String url;
  final String title;
  
  const _ImageViewerPage({required this.url, required this.title});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              log('[图片查看器] ❌ 加载失败: $error');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('图片加载失败', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // 尝试用WebView打开
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => _WebViewPage(url: url, title: title),
                          ),
                        );
                      },
                      child: const Text('用浏览器打开'),
                    ),
                  ],
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WebViewPage extends StatefulWidget {
  final String url;
  final String title;
  
  const _WebViewPage({required this.url, required this.title});

  @override
  State<_WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<_WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;

  String _decodeUrlIfNeeded(String url) {
    try {
      // 尝试解析可能的 base64 编码的 URL
      final uri = Uri.parse(url);
      // 检查是否有 proxy 或其他参数包含 base64
      if (uri.queryParameters.containsKey('url')) {
        final encodedUrl = uri.queryParameters['url']!;
        try {
          // 尝试解码 base64
          final decoded = Uri.decodeComponent(encodedUrl);
          if (decoded.startsWith('http')) {
            log('[WebView] 📝 解码到 URL: $decoded');
            return decoded;
          }
        } catch (_) {
          // 不是有效的 URL 编码，继续使用原始 URL
        }
      }
      // 检查 URL 本身是否看起来像 base64
      if (url.contains('/proxy/')) {
        try {
          final parts = url.split('/proxy/');
          if (parts.length > 1) {
            final encodedPart = parts.last;
            // 尝试 base64 解码
            final decoded = String.fromCharCodes(Uri.decodeComponent(encodedPart).runes);
            if (decoded.startsWith('http')) {
              log('[WebView] 📝 从 proxy 路径解码到 URL: $decoded');
              return decoded;
            }
          }
        } catch (_) {
          // 解码失败，继续
        }
      }
    } catch (_) {
      // URL 解析失败，使用原始值
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    
    final decodedUrl = _decodeUrlIfNeeded(widget.url);
    log('[WebView] 🎬 加载 URL: $decodedUrl');
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            log('[WebView] 🚀 页面开始加载: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            log('[WebView] ✅ 页面加载完成: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onHttpError: (HttpResponseError error) {
            log('[WebView] ❌ HTTP 错误: $error');
          },
          onWebResourceError: (WebResourceError error) {
            log('[WebView] ❌ Web 资源错误: ${error.description}, code: ${error.errorCode}');
          },
        ),
      )
      ..loadRequest(Uri.parse(decodedUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_isLoading && _progress > 0 && _progress < 1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryContentLoaderState extends State<_CategoryContentLoader>
    with AutomaticKeepAliveClientMixin {
  List<VideoItem> _videos = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;
  String _lastSiteKey = '';
  String _lastFiltersKey = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _lastSiteKey = widget.siteKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waitForFiltersAndLoad();
    });
  }

  Future<void> _waitForFiltersAndLoad() async {
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    int waitCount = 0;
    while (waitCount < 20) {
      if (sourceProvider.categories.isNotEmpty && 
          sourceProvider.filters.isNotEmpty && 
          sourceProvider.currentSite?['key'] == 'nodejs_$widget.siteKey') {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 200));
      waitCount++;
    }
    if (mounted) {
      _loadContent();
    }
  }

  @override
  void didUpdateWidget(_CategoryContentLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.siteKey != _lastSiteKey || 
        widget.typeId != oldWidget.typeId ||
        _lastFiltersKey != Provider.of<SourceProvider>(context, listen: false).filters.keys.toString()) {
      _lastSiteKey = widget.siteKey;
      _lastFiltersKey = Provider.of<SourceProvider>(context, listen: false).filters.keys.toString();
      _currentPage = 1;
      _hasMore = true;
      _videos = [];
      _waitForFiltersAndLoad();
    }
  }

  Future<void> _loadContent() async {
    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      log('[分类内容] 📋 加载分类: typeId=${widget.typeId}, typeName=${widget.typeName}, siteKey=${widget.siteKey}, page=$_currentPage');
      await NodeJSService.instance.initSpider();
      
      final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
      
      log('[分类内容] 🔍 调试 - filters.keys=${sourceProvider.filters.keys.toList()}, typeId=${widget.typeId}, typeIdType=${widget.typeId.runtimeType}');
      
      List<dynamic>? filters = sourceProvider.filters[widget.typeId] as List<dynamic>?;
      Map<String, dynamic> filterParams = {};
      bool shouldTryEmptyFilters = false;
      
      if (filters != null && filters.isNotEmpty) {
        log('[分类内容] 🔍 当前分类(${widget.typeId})有${filters.length}个filters, 完整filters: $filters');
        for (final filter in filters) {
          if (filter is Map<String, dynamic>) {
            final key = filter['key'] as String?;
            final init = filter['init'];
            final values = filter['value'] as List<dynamic>?;
            
            if (key != null) {
              String? filterValue;
              
              // 优先使用 init 值
              if (init != null && init.toString().isNotEmpty) {
                filterValue = init.toString();
                log('[分类内容] ✅ 使用init值: $key=$filterValue');
              } else if (values != null && values.isNotEmpty) {
                // 从 values 中获取第一个有效值
                for (final v in values) {
                  if (v is Map) {
                    final vv = v['v']?.toString() ?? v['value']?.toString();
                    if (vv != null && vv.isNotEmpty) {
                      filterValue = vv;
                      break;
                    }
                  } else if (v != null && v.toString().isNotEmpty) {
                    filterValue = v.toString();
                    break;
                  }
                }
                if (filterValue != null) {
                  log('[分类内容] ✅ 使用第一个可选值: $key=$filterValue');
                }
              }
              
              // 只有当值不为空时才添加到 filterParams
              if (filterValue != null && filterValue.isNotEmpty) {
                filterParams[key] = filterValue;
              } else {
                log('[分类内容] ⚠️ filter $key 没有有效值，跳过');
              }
            }
          }
        }
        shouldTryEmptyFilters = true;
      } else {
        log('[分类内容] ⚠️ 当前分类(${widget.typeId})没有filters');
      }
      
      log('[分类内容] 📋 使用filters: $filterParams');
      
      final result = await NodeJSService.instance.getCategoryContent(
        categoryId: widget.typeId,
        page: _currentPage,
        filters: filterParams,
      );

      var list = result['list'] as List<dynamic>? ?? [];
      final pagecount = result['pagecount'] as int? ?? 1;

      log('[分类内容] 📋 获取到${list.length}个视频, pagecount=$pagecount, currentPage=$_currentPage');

      // 如果第一次返回空，尝试不传 filters
      if (list.isEmpty && _currentPage == 1 && shouldTryEmptyFilters && filterParams.isNotEmpty) {
        log('[分类内容] 🔄 第一次返回空，尝试不传任何 filters 重新加载');
        final retryResult = await NodeJSService.instance.getCategoryContent(
          categoryId: widget.typeId,
          page: _currentPage,
          filters: {},
        );
        list = retryResult['list'] as List<dynamic>? ?? [];
        log('[分类内容] 📋 重试后获取到${list.length}个视频');
      }

      final newVideos = list
          .map((json) =>
              VideoItem.fromJson(json as Map<String, dynamic>))
          .toList();

      if (newVideos.isNotEmpty) {
        log('[分类内容] 📋 第一个视频: name=${newVideos.first.name}, id=${newVideos.first.id}');
      } else if (_currentPage == 1) {
        log('[分类内容] ⚠️ 分类内容为空，可能该分类需要子分类或filters参数');
        // 检查是否有filters可用但未使用
        final availableFilters = sourceProvider.filters[widget.typeId];
        if (availableFilters != null && availableFilters is List && availableFilters.isNotEmpty) {
          log('[分类内容] 💡 该分类有${availableFilters.length}个filter可用，尝试使用filter的init值重新加载');
          // 尝试使用每个filter的init值重新加载
          Map<String, dynamic> retryFilterParams = {};
          for (final filter in availableFilters) {
            if (filter is Map<String, dynamic>) {
              final key = filter['key'] as String?;
              final init = filter['init'];
              final values = filter['value'] as List<dynamic>?;
              
              if (key != null) {
                if (init != null && init.toString().isNotEmpty) {
                  retryFilterParams[key] = init;
                  log('[分类内容] 💡 使用filter init值: $key=$init');
                } else if (values != null && values.isNotEmpty) {
                  // 使用第一个非null值
                  for (final v in values) {
                    if (v != null) {
                      if (v is Map && v['v'] != null) {
                        retryFilterParams[key] = v['v'];
                        log('[分类内容] 💡 使用filter值: $key=${v['v']}');
                        break;
                      } else if (v is Map && v['value'] != null) {
                        retryFilterParams[key] = v['value'];
                        log('[分类内容] 💡 使用filter值(value字段): $key=${v['value']}');
                        break;
                      } else {
                        retryFilterParams[key] = v;
                        log('[分类内容] 💡 使用filter原始值: $key=$v');
                        break;
                      }
                    }
                  }
                }
              }
            }
          }
          if (retryFilterParams.isNotEmpty) {
            log('[分类内容] 💡 使用重试filters: $retryFilterParams');
            final retryResult = await NodeJSService.instance.getCategoryContent(
              categoryId: widget.typeId,
              page: 1,
              filters: retryFilterParams,
            );
            final retryList = retryResult['list'] as List<dynamic>? ?? [];
            if (retryList.isNotEmpty) {
              log('[分类内容] ✅ 使用filter后获取到${retryList.length}个视频');
              final retryVideos = retryList
                  .map((json) => VideoItem.fromJson(json as Map<String, dynamic>))
                  .toList();
              setState(() {
                _videos = retryVideos;
                _hasMore = 1 < (retryResult['pagecount'] as int? ?? 1);
                _currentPage = 2;
                _isLoading = false;
              });
              return;
            } else {
              log('[分类内容] ⚠️ 使用filter后仍然为空，pagecount=${retryResult['pagecount']}');
            }
          }
        }
      }

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
      log('[分类内容] ❌ 加载失败: $e');
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
      final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
      final isIndexSite = sourceProvider.isCurrentSiteIndex;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              isIndexSite ? '该线路为索引服务，请点击影视跳转搜索' : '暂无内容',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (!isIndexSite) ...[
              const SizedBox(height: 8),
              Text(
                '可尝试切换其他线路或使用搜索功能',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      );
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
            final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
            final currentSiteKey = sourceProvider.currentSite?['key'] as String? ?? '';
            final isIndexSite = sourceProvider.isCurrentSiteIndex;
            
            // 处理索引服务线路（如豆瓣）的点击行为 - 跳转搜索
            if (isIndexSite || currentSiteKey == 'nodejs_douban') {
              log('[分类内容] 🎬 索引线路，跳转到搜索: ${video.name}');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchPage(initialSearch: video.name),
                ),
              );
            } else if (currentSiteKey == 'nodejs_baseset') {
              log('[分类内容] ⚙️ 配置中心线路，检查内容: ${video.name}, cover=${video.cover}');
              
              if (video.cover.isNotEmpty && video.cover.startsWith('http')) {
                log('[分类内容] 🎨 配置中心检测到链接: ${video.cover}');
                
                String openUrl = video.cover;
                
                // 尝试解码 proxy URL 中的 base64 部分
                final proxyMatch = RegExp(r'/proxy/([A-Za-z0-9+/=]+)').firstMatch(video.cover);
                if (proxyMatch != null) {
                  try {
                    final encoded = proxyMatch.group(1)!;
                    final decoded = utf8.decode(base64Decode(encoded));
                    log('[分类内容] 🔓 proxy解码: $decoded');
                    if (decoded.startsWith('http')) {
                      openUrl = decoded;
                    }
                  } catch (e) {
                    log('[分类内容] ⚠️ proxy解码失败: $e');
                  }
                }
                
                // 配置中心链接始终用WebView打开
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _WebViewPage(url: openUrl, title: video.name),
                  ),
                );
              } else {
                log('[分类内容] ⚙️ 配置中心线路，打开Web配置页面');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WebConfigPage(),
                  ),
                );
              }
            } else {
              // 正常处理
              log('[分类内容] 🎬 正常跳转到详情页: ${video.name}, id=${video.id}');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailPage(videoId: video.id),
                ),
              );
            }
          },
        );
      },
    );
  }
}
