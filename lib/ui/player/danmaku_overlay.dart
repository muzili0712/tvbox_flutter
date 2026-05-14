import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class DanmakuItem {
  final String text;
  final Color color;
  final double speed;
  final double top;
  final DateTime createdAt;

  DanmakuItem({
    required this.text,
    this.color = Colors.white,
    this.speed = 1.0,
    required this.top,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class DanmakuOverlay extends StatefulWidget {
  final Stream<String>? danmakuStream;
  final bool enabled;

  const DanmakuOverlay({
    super.key,
    this.danmakuStream,
    this.enabled = true,
  });

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  final List<_DanmakuEntry> _activeDanmaku = [];
  final Random _random = Random();
  StreamSubscription<String>? _subscription;
  late Ticker _ticker;
  int _lastTimestamp = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
    _subscribeStream();
  }

  void _subscribeStream() {
    _subscription?.cancel();
    if (widget.danmakuStream != null) {
      _subscription = widget.danmakuStream!.listen((text) {
        _addDanmaku(text);
      });
    }
  }

  void _addDanmaku(String text) {
    if (!widget.enabled || !mounted) return;
    
    final top = _random.nextDouble() * 0.7;
    final speed = 0.3 + _random.nextDouble() * 0.4;
    
    final colors = [
      Colors.white,
      Colors.yellow,
      Colors.cyan,
      Colors.greenAccent,
      Colors.pinkAccent,
    ];
    
    setState(() {
      _activeDanmaku.add(_DanmakuEntry(
        text: text,
        color: colors[_random.nextInt(colors.length)],
        speed: speed,
        top: top,
        progress: 1.0,
      ));
    });
  }

  void _onTick(Duration elapsed) {
    final timestamp = elapsed.inMilliseconds;
    if (_lastTimestamp == 0) {
      _lastTimestamp = timestamp;
      return;
    }
    final delta = (timestamp - _lastTimestamp) / 1000.0;
    _lastTimestamp = timestamp;

    bool needsRebuild = false;
    for (int i = _activeDanmaku.length - 1; i >= 0; i--) {
      final d = _activeDanmaku[i];
      d.progress -= d.speed * delta * 0.3;
      if (d.progress < -0.3) {
        _activeDanmaku.removeAt(i);
        needsRebuild = true;
      }
    }

    if (needsRebuild && mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.danmakuStream != widget.danmakuStream) {
      _subscribeStream();
    }
    if (!widget.enabled) {
      setState(() {
        _activeDanmaku.clear();
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _activeDanmaku.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Stack(
        children: _activeDanmaku.map((d) {
          return Positioned(
            left: d.progress * MediaQuery.of(context).size.width,
            top: d.top * (MediaQuery.of(context).size.height * 0.6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                d.text,
                style: TextStyle(
                  color: d.color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DanmakuEntry {
  String text;
  Color color;
  double speed;
  double top;
  double progress;

  _DanmakuEntry({
    required this.text,
    required this.color,
    required this.speed,
    required this.top,
    required this.progress,
  });
}
