// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'erasure_request_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErasureRequestOutput _$ErasureRequestOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'subjectId',
      'isGoogleUser',
      'requestedAt',
      'dueAt',
      'overdue',
      'blockedReason',
    ],
    disallowNullValues: const [
      'subjectId',
      'isGoogleUser',
      'requestedAt',
      'dueAt',
      'overdue',
    ],
  );
  return ErasureRequestOutput(
    subjectId: json['subjectId'] as String?,
    isGoogleUser: json['isGoogleUser'] as bool?,
    requestedAt: ErasureRequestOutput._read_requestedAt(json['requestedAt']),
    dueAt: ErasureRequestOutput._read_dueAt(json['dueAt']),
    overdue: json['overdue'] as bool?,
    blockedReason: json['blockedReason'] as String?,
  );
}

Map<String, dynamic> _$ErasureRequestOutputToJson(
  ErasureRequestOutput instance,
) => <String, dynamic>{
  'subjectId': ?instance.subjectId,
  'isGoogleUser': ?instance.isGoogleUser,
  'requestedAt': ?ErasureRequestOutput._write_requestedAt(instance.requestedAt),
  'dueAt': ?ErasureRequestOutput._write_dueAt(instance.dueAt),
  'overdue': ?instance.overdue,
  'blockedReason': ?instance.blockedReason,
};
