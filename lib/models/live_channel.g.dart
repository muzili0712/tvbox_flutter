// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiveChannel _$LiveChannelFromJson(Map<String, dynamic> json) => LiveChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      logo: json['logo'] as String?,
      group: json['group'] as String?,
    );

Map<String, dynamic> _$LiveChannelToJson(LiveChannel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'url': instance.url,
      'logo': instance.logo,
      'group': instance.group,
    };
