// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hard_delete_person_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HardDeletePersonCommandOutput _$HardDeletePersonCommandOutputFromJson(
  Map<String, dynamic> json,
) => HardDeletePersonCommandOutput(
  id: json['id'] as String?,
  deletedApplicationCount: (json['deletedApplicationCount'] as num?)?.toInt(),
  deletedTokenCount: (json['deletedTokenCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$HardDeletePersonCommandOutputToJson(
  HardDeletePersonCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'deletedApplicationCount': instance.deletedApplicationCount,
  'deletedTokenCount': instance.deletedTokenCount,
};
