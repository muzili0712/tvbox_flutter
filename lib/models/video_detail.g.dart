// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideoDetail _$VideoDetailFromJson(Map<String, dynamic> json) => VideoDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      cover: json['cover'] as String,
      desc: json['desc'] as String?,
      year: json['year'] as String?,
      area: json['area'] as String?,
      director: json['director'] as String?,
      actor: json['actor'] as String?,
      episodes: (json['episodes'] as List<dynamic>)
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$VideoDetailToJson(VideoDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'cover': instance.cover,
      'desc': instance.desc,
      'year': instance.year,
      'area': instance.area,
      'director': instance.director,
      'actor': instance.actor,
      'episodes': instance.episodes.map((e) => e.toJson()).toList(),
    };

Episode _$EpisodeFromJson(Map<String, dynamic> json) => Episode(
      name: json['name'] as String,
      url: json['url'] as String,
      sourceName: json['sourceName'] as String?,
    );

Map<String, dynamic> _$EpisodeToJson(Episode instance) => <String, dynamic>{
      'name': instance.name,
      'url': instance.url,
      'sourceName': instance.sourceName,
    };
