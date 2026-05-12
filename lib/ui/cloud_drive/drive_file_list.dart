import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/providers/cloud_drive_provider.dart';
import 'package:tvbox_flutter/models/cloud_drive.dart';
import 'package:tvbox_flutter/ui/player/video_player_page.dart';
import 'package:tvbox_flutter/utils/player_util.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class DriveFileListPage extends StatefulWidget {
  final String driveId;
  final String driveName;
  final String? currentPath;

  const DriveFileListPage({
    super.key,
    required this.driveId,
    required this.driveName,
    this.currentPath,
  });

  @override
  State<DriveFileListPage> createState() => _DriveFileListPageState();
}

class _DriveFileListPageState extends State<DriveFileListPage> {
  List<DriveFile> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    
    try {
      final files = await Provider.of<CloudDriveProvider>(context, listen: false)
          .listFiles(widget.driveId, widget.currentPath ?? 'root');
      setState(() {
        _files = files;
      });
    } catch (e) {
      print('Load files error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openFile(DriveFile file) async {
    if (file.type == 'folder') {
      // 进入文件夹
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriveFileListPage(
            driveId: widget.driveId,
            driveName: widget.driveName,
            currentPath: file.id,
          ),
        ),
      );
    } else {
      // 播放文件
      final playUrl = await Provider.of<CloudDriveProvider>(context, listen: false)
          .getPlayUrl(widget.driveId, file.id);
      
      if (!mounted) return;
      
      if (playUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取播放地址')),
          );
        }
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(
            playUrl: playUrl,
            title: file.name,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.driveName),
      ),
      body: _isLoading
          ? const Center(
              child: SpinKitFadingCircle(
                color: Colors.blue,
                size: 50.0,
              ),
            )
          : ListView.builder(
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                return ListTile(
                  leading: Icon(
                    file.type == 'folder'
                        ? Icons.folder
                        : Icons.video_file,
                    color: file.type == 'folder' ? Colors.amber : Colors.blue,
                  ),
                  title: Text(file.name),
                  subtitle: file.type == 'file' && file.size != null
                      ? Text(PlayerUtil.formatFileSize(file.size!))
                      : null,
                  onTap: () => _openFile(file),
                );
              },
            ),
    );
  }
}
