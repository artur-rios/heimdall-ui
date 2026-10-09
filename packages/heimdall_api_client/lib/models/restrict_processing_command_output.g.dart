// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restrict_processing_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RestrictProcessingCommandOutput _$RestrictProcessingCommandOutputFromJson(
  Map<String, dynamic> json,
) => RestrictProcessingCommandOutput(
  id: json['id'] as String?,
  restrictedAt: json['restrictedAt'] == null
      ? null
      : DateTime.parse(json['restrictedAt'] as String),
  ground: (json['ground'] as num?)?.toInt(),
);

Map<String, dynamic> _$RestrictProcessingCommandOutputToJson(
  RestrictProcessingCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'restrictedAt': instance.restrictedAt?.toIso8601String(),
  'ground': instance.ground,
};
