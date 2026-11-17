// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hard_delete_application_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HardDeleteApplicationCommandOutput _$HardDeleteApplicationCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(json, allowedKeys: const ['id'], disallowNullValues: const ['id']);
  return HardDeleteApplicationCommandOutput(id: json['id'] as String?);
}

Map<String, dynamic> _$HardDeleteApplicationCommandOutputToJson(
  HardDeleteApplicationCommandOutput instance,
) => <String, dynamic>{'id': ?instance.id};
