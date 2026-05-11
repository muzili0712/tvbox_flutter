import 'package:json_annotation/json_annotation.dart';

part 'video_item.g.dart';

@JsonSerializable()
class VideoItem {
  final String id;
  final String name;
  final String cover;
  final String? desc;
  final String? year;
  final String? area;
  final String? director;
  final String? actor;
  final String? remark;

  VideoItem({
    required this.id,
    required this.name,
    required this.cover,
    this.desc,
    this.year,
    this.area,
    this.director,
    this.actor,
    this.remark,
  });

  factory VideoItem.fromCatPawOpen(Map<String, dynamic> json) {
    return VideoItem(
      id: json['vod_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['vod_name']?.toString() ?? json['name']?.toString() ?? '',
      cover: json['vod_pic']?.toString() ?? json['cover']?.toString() ?? '',
      desc: json['vod_content']?.toString() ?? json['desc']?.toString(),
      year: json['vod_year']?.toString() ?? json['year']?.toString(),
      area: json['vod_area']?.toString() ?? json['area']?.toString(),
      director:
          json['vod_director']?.toString() ?? json['director']?.toString(),
      actor: json['vod_actor']?.toString() ?? json['actor']?.toString(),
      remark: json['vod_remarks']?.toString() ?? json['remark']?.toString(),
    );
  }

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('vod_id') || json.containsKey('vod_name')) {
      return VideoItem.fromCatPawOpen(json);
    }
    return _$VideoItemFromJson(json);
  }

  Map<String, dynamic> toJson() => _$VideoItemToJson(this);
}
