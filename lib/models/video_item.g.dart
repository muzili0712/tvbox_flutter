// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideoItem _$VideoItemFromJson(Map<String, dynamic> json) => VideoItem(
      id: json['id'] as String,
      name: json['name'] as String,
      cover: json['cover'] as String,
      desc: json['desc'] as String?,
      year: json['year'] as String?,
      area: json['area'] as String?,
      director: json['director'] as String?,
      actor: json['actor'] as String?,
      remark: json['remark'] as String?,
    );

Map<String, dynamic> _$VideoItemToJson(VideoItem instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'cover': instance.cover,
      'desc': instance.desc,
      'year': instance.year,
      'area': instance.area,
      'director': instance.director,
      'actor': instance.actor,
      'remark': instance.remark,
    };
