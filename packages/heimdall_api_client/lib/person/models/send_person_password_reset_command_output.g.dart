// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_person_password_reset_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SendPersonPasswordResetCommandOutput
_$SendPersonPasswordResetCommandOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(json, allowedKeys: const ['id'], disallowNullValues: const ['id']);
  return SendPersonPasswordResetCommandOutput(id: json['id'] as String?);
}

Map<String, dynamic> _$SendPersonPasswordResetCommandOutputToJson(
  SendPersonPasswordResetCommandOutput instance,
) => <String, dynamic>{'id': ?instance.id};
