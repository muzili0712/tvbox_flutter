import 'package:json_annotation/json_annotation.dart';

part 'source_config.g.dart';

@JsonSerializable()
class SourceConfig {
  final String id;
  final String name;
  final String url;
  final bool isEnabled;
  
  // CatPawOpen 相关字段
  final String? spiderKey;      // catpawopen Spider key
  final int? spiderType;        // catpawopen Spider type (3=视频, 40=网盘等)
  final String? sourceType;     // 数据源类型: 'catpawopen' 或 'legacy'

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

  /// 创建 CatPawOpen 数据源
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
