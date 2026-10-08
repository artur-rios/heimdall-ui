// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reapply_erasures_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReapplyErasuresCommandOutput _$ReapplyErasuresCommandOutputFromJson(
  Map<String, dynamic> json,
) => ReapplyErasuresCommandOutput(
  anonymised: (json['anonymised'] as num?)?.toInt(),
  alreadyAnonymised: (json['alreadyAnonymised'] as num?)?.toInt(),
  notFound: (json['notFound'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$ReapplyErasuresCommandOutputToJson(
  ReapplyErasuresCommandOutput instance,
) => <String, dynamic>{
  'anonymised': instance.anonymised,
  'alreadyAnonymised': instance.alreadyAnonymised,
  'notFound': instance.notFound,
};
