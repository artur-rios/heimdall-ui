// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_erasure_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestErasureCommandOutput _$RequestErasureCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'requestedAt',
      'dueAt',
      'blocked',
      'blockedReason',
      'restrictionLifted',
    ],
    disallowNullValues: const [
      'id',
      'requestedAt',
      'dueAt',
      'blocked',
      'restrictionLifted',
    ],
  );
  return RequestErasureCommandOutput(
    id: json['id'] as String?,
    requestedAt: RequestErasureCommandOutput._read_requestedAt(
      json['requestedAt'],
    ),
    dueAt: RequestErasureCommandOutput._read_dueAt(json['dueAt']),
    blocked: json['blocked'] as bool?,
    blockedReason: json['blockedReason'] as String?,
    restrictionLifted: json['restrictionLifted'] as bool?,
  );
}

Map<String, dynamic> _$RequestErasureCommandOutputToJson(
  RequestErasureCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'requestedAt': ?RequestErasureCommandOutput._write_requestedAt(
    instance.requestedAt,
  ),
  'dueAt': ?RequestErasureCommandOutput._write_dueAt(instance.dueAt),
  'blocked': ?instance.blocked,
  'blockedReason': ?instance.blockedReason,
  'restrictionLifted': ?instance.restrictionLifted,
};
