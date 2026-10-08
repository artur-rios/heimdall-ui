// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lift_processing_restriction_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiftProcessingRestrictionCommandOutput
_$LiftProcessingRestrictionCommandOutputFromJson(Map<String, dynamic> json) =>
    LiftProcessingRestrictionCommandOutput(
      id: json['id'] as String?,
      liftedAt: json['liftedAt'] == null
          ? null
          : DateTime.parse(json['liftedAt'] as String),
      subjectNotified: json['subjectNotified'] as bool?,
    );

Map<String, dynamic> _$LiftProcessingRestrictionCommandOutputToJson(
  LiftProcessingRestrictionCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'liftedAt': instance.liftedAt?.toIso8601String(),
  'subjectNotified': instance.subjectNotified,
};
