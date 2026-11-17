// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lift_processing_restriction_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiftProcessingRestrictionCommandOutput
_$LiftProcessingRestrictionCommandOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const ['id', 'liftedAt', 'subjectNotified'],
    disallowNullValues: const ['id', 'liftedAt', 'subjectNotified'],
  );
  return LiftProcessingRestrictionCommandOutput(
    id: json['id'] as String?,
    liftedAt: LiftProcessingRestrictionCommandOutput._read_liftedAt(
      json['liftedAt'],
    ),
    subjectNotified: json['subjectNotified'] as bool?,
  );
}

Map<String, dynamic> _$LiftProcessingRestrictionCommandOutputToJson(
  LiftProcessingRestrictionCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'liftedAt': ?LiftProcessingRestrictionCommandOutput._write_liftedAt(
    instance.liftedAt,
  ),
  'subjectNotified': ?instance.subjectNotified,
};
