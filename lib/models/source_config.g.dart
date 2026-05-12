// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SourceConfig _$SourceConfigFromJson(Map<String, dynamic> json) => SourceConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
      spiderKey: json['spiderKey'] as String?,
      spiderType: json['spiderType'] as int?,
      sourceType: json['sourceType'] as String? ?? 'remote',
    );

Map<String, dynamic> _$SourceConfigToJson(SourceConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'url': instance.url,
      'isEnabled': instance.isEnabled,
      'spiderKey': instance.spiderKey,
      'spiderType': instance.spiderType,
      'sourceType': instance.sourceType,
    };
