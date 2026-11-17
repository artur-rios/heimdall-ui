// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_scope_email_links_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetScopeEmailLinksCommandOutput _$SetScopeEmailLinksCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'name',
      'description',
      'googleSignInEnabled',
      'selfRegistrationEnabled',
      'emailVerificationUrl',
      'passwordResetUrl',
      'ownerIds',
      'createdAt',
      'updatedAt',
    ],
    disallowNullValues: const [
      'id',
      'googleSignInEnabled',
      'selfRegistrationEnabled',
      'createdAt',
      'updatedAt',
    ],
  );
  return SetScopeEmailLinksCommandOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    description: json['description'] as String?,
    googleSignInEnabled: json['googleSignInEnabled'] as bool?,
    selfRegistrationEnabled: json['selfRegistrationEnabled'] as bool?,
    emailVerificationUrl: json['emailVerificationUrl'] as String?,
    passwordResetUrl: json['passwordResetUrl'] as String?,
    ownerIds: (json['ownerIds'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    createdAt: SetScopeEmailLinksCommandOutput._read_createdAt(
      json['createdAt'],
    ),
    updatedAt: SetScopeEmailLinksCommandOutput._read_updatedAt(
      json['updatedAt'],
    ),
  );
}

Map<String, dynamic> _$SetScopeEmailLinksCommandOutputToJson(
  SetScopeEmailLinksCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'description': ?instance.description,
  'googleSignInEnabled': ?instance.googleSignInEnabled,
  'selfRegistrationEnabled': ?instance.selfRegistrationEnabled,
  'emailVerificationUrl': ?instance.emailVerificationUrl,
  'passwordResetUrl': ?instance.passwordResetUrl,
  'ownerIds': ?instance.ownerIds,
  'createdAt': ?SetScopeEmailLinksCommandOutput._write_createdAt(
    instance.createdAt,
  ),
  'updatedAt': ?SetScopeEmailLinksCommandOutput._write_updatedAt(
    instance.updatedAt,
  ),
};
