import 'package:json_annotation/json_annotation.dart';

part 'source_config.g.dart';

@JsonSerializable()
class SourceConfig {
  final String id;
  final String name;
  final String url;
  final bool isEnabled;
  final String? spiderKey;
  final int? spiderType;
  final String? sourceType;

  SourceConfig({
    required this.id,
    required this.name,
    required this.url,
    this.isEnabled = true,
    this.spiderKey,
    this.spiderType,
    this.sourceType = 'catpawopen',
  });

  factory SourceConfig.empty() {
    return SourceConfig(
      id: '',
      name: '',
      url: '',
      isEnabled: false,
      sourceType: 'catpawopen',
    );
  }

  factory SourceConfig.catPawOpen({
    required String id,
    required String name,
    required String spiderKey,
    int spiderType = 3,
  }) {
    return SourceConfig(
      id: id,
      name: name,
      url: 'catpawopen://$spiderKey',
      isEnabled: true,
      spiderKey: spiderKey,
      spiderType: spiderType,
      sourceType: 'catpawopen',
    );
  }

  factory SourceConfig.remote({
    required String id,
    required String name,
    required String url,
  }) {
    return SourceConfig(
      id: id,
      name: name,
      url: url,
      isEnabled: true,
      sourceType: 'remote',
    );
  }

  factory SourceConfig.local({
    required String id,
    required String name,
    required String url,
  }) {
    return SourceConfig(
      id: id,
      name: name,
      url: url,
      isEnabled: true,
      sourceType: 'local',
    );
  }

  SourceConfig copyWith({
    String? id,
    String? name,
    String? url,
    bool? isEnabled,
    String? spiderKey,
    int? spiderType,
    String? sourceType,
  }) {
    return SourceConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      isEnabled: isEnabled ?? this.isEnabled,
      spiderKey: spiderKey ?? this.spiderKey,
      spiderType: spiderType ?? this.spiderType,
      sourceType: sourceType ?? this.sourceType,
    );
  }

  factory SourceConfig.fromJson(Map<String, dynamic> json) =>
      _$SourceConfigFromJson(json);

  Map<String, dynamic> toJson() => _$SourceConfigToJson(this);
}
