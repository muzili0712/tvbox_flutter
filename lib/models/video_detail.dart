import 'package:json_annotation/json_annotation.dart';

part 'video_detail.g.dart';

@JsonSerializable()
class VideoDetail {
  final String id;
  final String name;
  final String cover;
  final String? desc;
  final String? year;
  final String? area;
  final String? director;
  final String? actor;
  final List<Episode> episodes;

  VideoDetail({
    required this.id,
    required this.name,
    required this.cover,
    this.desc,
    this.year,
    this.area,
    this.director,
    this.actor,
    required this.episodes,
  });

  factory VideoDetail.fromJson(Map<String, dynamic> json) =>
      _$VideoDetailFromJson(json);

  Map<String, dynamic> toJson() => _$VideoDetailToJson(this);
}

@JsonSerializable()
class Episode {
  final String name;
  final String url;
  final String? sourceName;

  Episode({
    required this.name,
    required this.url,
    this.sourceName,
  });

  factory Episode.fromJson(Map<String, dynamic> json) =>
      _$EpisodeFromJson(json);

  Map<String, dynamic> toJson() => _$EpisodeToJson(this);
}
