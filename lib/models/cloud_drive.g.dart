// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cloud_drive.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CloudDrive _$CloudDriveFromJson(Map<String, dynamic> json) => CloudDrive(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      config: json['config'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$CloudDriveToJson(CloudDrive instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'config': instance.config,
    };

DriveFile _$DriveFileFromJson(Map<String, dynamic> json) => DriveFile(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      size: json['size'] as int?,
      updatedAt: json['updatedAt'] as String?,
    );

Map<String, dynamic> _$DriveFileToJson(DriveFile instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'size': instance.size,
      'updatedAt': instance.updatedAt,
    };
