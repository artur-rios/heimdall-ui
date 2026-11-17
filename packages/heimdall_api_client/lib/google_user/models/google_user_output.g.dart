// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_user_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleUserOutput _$GoogleUserOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'googleId',
      'name',
      'email',
      'emailVerified',
      'profilePictureUrl',
      'isDeleted',
      'scopeId',
      'createdAt',
      'updatedAt',
    ],
    disallowNullValues: const [
      'id',
      'emailVerified',
      'isDeleted',
      'scopeId',
      'createdAt',
      'updatedAt',
    ],
  );
  return GoogleUserOutput(
    id: json['id'] as String?,
    googleId: json['googleId'] as String?,
    name: json['name'] as String?,
    email: json['email'] as String?,
    emailVerified: json['emailVerified'] as bool?,
    profilePictureUrl: json['profilePictureUrl'] as String?,
    isDeleted: json['isDeleted'] as bool?,
    scopeId: json['scopeId'] as String?,
    createdAt: GoogleUserOutput._read_createdAt(json['createdAt']),
    updatedAt: GoogleUserOutput._read_updatedAt(json['updatedAt']),
  );
}

Map<String, dynamic> _$GoogleUserOutputToJson(GoogleUserOutput instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'googleId': ?instance.googleId,
      'name': ?instance.name,
      'email': ?instance.email,
      'emailVerified': ?instance.emailVerified,
      'profilePictureUrl': ?instance.profilePictureUrl,
      'isDeleted': ?instance.isDeleted,
      'scopeId': ?instance.scopeId,
      'createdAt': ?GoogleUserOutput._write_createdAt(instance.createdAt),
      'updatedAt': ?GoogleUserOutput._write_updatedAt(instance.updatedAt),
    };
