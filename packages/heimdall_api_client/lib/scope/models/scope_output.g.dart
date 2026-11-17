// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scope_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScopeOutput _$ScopeOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'name',
      'description',
      'googleSignInEnabled',
      'selfRegistrationEnabled',
      'defaultLegalBasis',
      'privacyNoticeUri',
      'emailVerificationUrl',
      'passwordResetUrl',
      'isDeleted',
      'ownerIds',
      'createdAt',
      'updatedAt',
    ],
    disallowNullValues: const [
      'id',
      'googleSignInEnabled',
      'selfRegistrationEnabled',
      'isDeleted',
      'createdAt',
      'updatedAt',
    ],
  );
  return ScopeOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    description: json['description'] as String?,
    googleSignInEnabled: json['googleSignInEnabled'] as bool?,
    selfRegistrationEnabled: json['selfRegistrationEnabled'] as bool?,
    defaultLegalBasis: ScopeOutput._read_defaultLegalBasis(
      json['defaultLegalBasis'],
    ),
    privacyNoticeUri: json['privacyNoticeUri'] as String?,
    emailVerificationUrl: json['emailVerificationUrl'] as String?,
    passwordResetUrl: json['passwordResetUrl'] as String?,
    isDeleted: json['isDeleted'] as bool?,
    ownerIds: (json['ownerIds'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    createdAt: ScopeOutput._read_createdAt(json['createdAt']),
    updatedAt: ScopeOutput._read_updatedAt(json['updatedAt']),
  );
}

Map<String, dynamic> _$ScopeOutputToJson(ScopeOutput instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'name': ?instance.name,
      'description': ?instance.description,
      'googleSignInEnabled': ?instance.googleSignInEnabled,
      'selfRegistrationEnabled': ?instance.selfRegistrationEnabled,
      'defaultLegalBasis': ?ScopeOutput._write_defaultLegalBasis(
        instance.defaultLegalBasis,
      ),
      'privacyNoticeUri': ?instance.privacyNoticeUri,
      'emailVerificationUrl': ?instance.emailVerificationUrl,
      'passwordResetUrl': ?instance.passwordResetUrl,
      'isDeleted': ?instance.isDeleted,
      'ownerIds': ?instance.ownerIds,
      'createdAt': ?ScopeOutput._write_createdAt(instance.createdAt),
      'updatedAt': ?ScopeOutput._write_updatedAt(instance.updatedAt),
    };
