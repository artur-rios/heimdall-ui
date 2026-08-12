// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_person_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeletePersonCommandOutput _$DeletePersonCommandOutputFromJson(
  Map<String, dynamic> json,
) => DeletePersonCommandOutput(
  id: json['id'] as String?,
  alreadyDeleted: json['alreadyDeleted'] as bool?,
);

Map<String, dynamic> _$DeletePersonCommandOutputToJson(
  DeletePersonCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'alreadyDeleted': instance.alreadyDeleted,
};
