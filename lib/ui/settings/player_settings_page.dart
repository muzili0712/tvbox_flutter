import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/providers/player_provider.dart';

class PlayerSettingsPage extends StatelessWidget {
  const PlayerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放器设置'),
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, child) {
          return ListView(
            children: [
              ListTile(
                title: const Text('默认播放器'),
                subtitle: Text(_getPlayerName(provider.defaultPlayer)),
                trailing: DropdownButton<PlayerType>(
                  value: provider.defaultPlayer,
                  items: const [
                    DropdownMenuItem(
                      value: PlayerType.vlc,
                      child: Text('VLC播放器'),
                    ),
                    DropdownMenuItem(
                      value: PlayerType.system,
                      child: Text('系统播放器'),
                    ),
                    DropdownMenuItem(
                      value: PlayerType.exo,
                      child: Text('Exo播放器'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      provider.setDefaultPlayer(value);
                    }
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('硬件加速'),
                subtitle: const Text('开启后可提升播放性能'),
                value: provider.hardwareAcceleration,
                onChanged: provider.setHardwareAcceleration,
              ),
              ListTile(
                title: const Text('默认倍速'),
                subtitle: Text('${provider.playbackSpeed}x'),
                trailing: DropdownButton<double>(
                  value: provider.playbackSpeed,
                  items: const [
                    DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                    DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                    DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                    DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                    DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                    DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      provider.setPlaybackSpeed(value);
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  String _getPlayerName(PlayerType type) {
    switch (type) {
      case PlayerType.vlc:
        return 'VLC播放器';
      case PlayerType.system:
        return '系统播放器';
      case PlayerType.exo:
        return 'Exo播放器';
    }
  }
}
