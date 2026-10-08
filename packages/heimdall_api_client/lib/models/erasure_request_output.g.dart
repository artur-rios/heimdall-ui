// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'erasure_request_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErasureRequestOutput _$ErasureRequestOutputFromJson(
  Map<String, dynamic> json,
) => ErasureRequestOutput(
  subjectId: json['subjectId'] as String?,
  isGoogleUser: json['isGoogleUser'] as bool?,
  requestedAt: json['requestedAt'] == null
      ? null
      : DateTime.parse(json['requestedAt'] as String),
  dueAt: json['dueAt'] == null ? null : DateTime.parse(json['dueAt'] as String),
  overdue: json['overdue'] as bool?,
  blockedReason: json['blockedReason'] as String?,
);

Map<String, dynamic> _$ErasureRequestOutputToJson(
  ErasureRequestOutput instance,
) => <String, dynamic>{
  'subjectId': instance.subjectId,
  'isGoogleUser': instance.isGoogleUser,
  'requestedAt': instance.requestedAt?.toIso8601String(),
  'dueAt': instance.dueAt?.toIso8601String(),
  'overdue': instance.overdue,
  'blockedReason': instance.blockedReason,
};
