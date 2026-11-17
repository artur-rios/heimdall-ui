// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_registration_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PendingRegistrationOutput _$PendingRegistrationOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'name',
      'email',
      'createdAt',
      'expiresAt',
      'attemptsLeft',
      'expired',
    ],
    disallowNullValues: const [
      'id',
      'createdAt',
      'expiresAt',
      'attemptsLeft',
      'expired',
    ],
  );
  return PendingRegistrationOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    email: json['email'] as String?,
    createdAt: PendingRegistrationOutput._read_createdAt(json['createdAt']),
    expiresAt: PendingRegistrationOutput._read_expiresAt(json['expiresAt']),
    attemptsLeft: PendingRegistrationOutput._read_attemptsLeft(
      json['attemptsLeft'],
    ),
    expired: json['expired'] as bool?,
  );
}

Map<String, dynamic> _$PendingRegistrationOutputToJson(
  PendingRegistrationOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'email': ?instance.email,
  'createdAt': ?PendingRegistrationOutput._write_createdAt(instance.createdAt),
  'expiresAt': ?PendingRegistrationOutput._write_expiresAt(instance.expiresAt),
  'attemptsLeft': ?PendingRegistrationOutput._write_attemptsLeft(
    instance.attemptsLeft,
  ),
  'expired': ?instance.expired,
};
