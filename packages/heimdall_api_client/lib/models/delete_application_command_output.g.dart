// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_application_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteApplicationCommandOutput _$DeleteApplicationCommandOutputFromJson(
  Map<String, dynamic> json,
) => DeleteApplicationCommandOutput(
  id: json['id'] as String?,
  alreadyDeleted: json['alreadyDeleted'] as bool?,
);

Map<String, dynamic> _$DeleteApplicationCommandOutputToJson(
  DeleteApplicationCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'alreadyDeleted': instance.alreadyDeleted,
};
