import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/models/cloud_drive.dart';
import 'package:tvbox_flutter/constants/app_constants.dart';

class CloudDriveProvider extends ChangeNotifier {
  List<CloudDrive> _drives = [];
  bool _isLoading = false;

  List<CloudDrive> get drives => _drives;
  bool get isLoading => _isLoading;

  CloudDriveProvider() {
    loadDrives();
  }

  Future<void> loadDrives() async {
    final prefs = await SharedPreferences.getInstance();
    final drivesJson = prefs.getStringList(AppConstants.keyCloudDrives) ?? [];

    _drives = drivesJson
        .map((json) => CloudDrive.fromJson(jsonDecode(json)))
        .toList();

    notifyListeners();
  }

  Future<void> addDrive(CloudDrive drive) async {
    await NodeJSService.instance.addCloudDrive(drive.type, drive.config);
    _drives.add(drive);
    await _saveDrives();
    notifyListeners();
  }

  Future<void> removeDrive(String id) async {
    _drives.removeWhere((d) => d.id == id);
    await _saveDrives();
    notifyListeners();
  }

  Future<void> _saveDrives() async {
    final prefs = await SharedPreferences.getInstance();
    final drivesJson = _drives.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList(AppConstants.keyCloudDrives, drivesJson);
  }

  Future<List<DriveFile>> listFiles(String driveId, String path) async {
    final filesJson = await NodeJSService.instance.listCloudDriveFiles(driveId, path);
    return (jsonDecode(filesJson) as List)
        .map((json) => DriveFile.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<String?> getPlayUrl(String driveId, String fileId) async {
    return await NodeJSService.instance.getCloudDrivePlayUrl(driveId, fileId);
  }
}
