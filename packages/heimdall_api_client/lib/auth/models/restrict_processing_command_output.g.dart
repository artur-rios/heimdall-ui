// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restrict_processing_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RestrictProcessingCommandOutput _$RestrictProcessingCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['id', 'restrictedAt', 'ground'],
    disallowNullValues: const ['id', 'restrictedAt', 'ground'],
  );
  return RestrictProcessingCommandOutput(
    id: json['id'] as String?,
    restrictedAt: RestrictProcessingCommandOutput._read_restrictedAt(
      json['restrictedAt'],
    ),
    ground: RestrictProcessingCommandOutput._read_ground(json['ground']),
  );
}

Map<String, dynamic> _$RestrictProcessingCommandOutputToJson(
  RestrictProcessingCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'restrictedAt': ?RestrictProcessingCommandOutput._write_restrictedAt(
    instance.restrictedAt,
  ),
  'ground': ?RestrictProcessingCommandOutput._write_ground(instance.ground),
};
