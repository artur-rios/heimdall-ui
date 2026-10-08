// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_erasure_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestErasureCommandOutput _$RequestErasureCommandOutputFromJson(
  Map<String, dynamic> json,
) => RequestErasureCommandOutput(
  id: json['id'] as String?,
  requestedAt: json['requestedAt'] == null
      ? null
      : DateTime.parse(json['requestedAt'] as String),
  dueAt: json['dueAt'] == null ? null : DateTime.parse(json['dueAt'] as String),
  blocked: json['blocked'] as bool?,
  blockedReason: json['blockedReason'] as String?,
);

Map<String, dynamic> _$RequestErasureCommandOutputToJson(
  RequestErasureCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'requestedAt': instance.requestedAt?.toIso8601String(),
  'dueAt': instance.dueAt?.toIso8601String(),
  'blocked': instance.blocked,
  'blockedReason': instance.blockedReason,
};
