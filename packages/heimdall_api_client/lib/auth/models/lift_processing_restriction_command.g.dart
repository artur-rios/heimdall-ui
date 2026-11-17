// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lift_processing_restriction_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiftProcessingRestrictionCommand _$LiftProcessingRestrictionCommandFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(json, allowedKeys: const ['subjectId']);
  return LiftProcessingRestrictionCommand(
    subjectId: json['subjectId'] as String?,
  );
}

Map<String, dynamic> _$LiftProcessingRestrictionCommandToJson(
  LiftProcessingRestrictionCommand instance,
) => <String, dynamic>{'subjectId': ?instance.subjectId};
