// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reapply_erasures_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReapplyErasuresCommand _$ReapplyErasuresCommandFromJson(
  Map<String, dynamic> json,
) => ReapplyErasuresCommand(
  subjectIds: (json['subjectIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$ReapplyErasuresCommandToJson(
  ReapplyErasuresCommand instance,
) => <String, dynamic>{'subjectIds': instance.subjectIds};
