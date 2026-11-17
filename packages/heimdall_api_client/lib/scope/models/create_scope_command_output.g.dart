// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_scope_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateScopeCommandOutput _$CreateScopeCommandOutputFromJson(
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
    ],
    disallowNullValues: const [
      'id',
      'googleSignInEnabled',
      'selfRegistrationEnabled',
      'createdAt',
    ],
  );
  return CreateScopeCommandOutput(
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
    createdAt: CreateScopeCommandOutput._read_createdAt(json['createdAt']),
  );
}

Map<String, dynamic> _$CreateScopeCommandOutputToJson(
  CreateScopeCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'description': ?instance.description,
  'googleSignInEnabled': ?instance.googleSignInEnabled,
  'selfRegistrationEnabled': ?instance.selfRegistrationEnabled,
  'emailVerificationUrl': ?instance.emailVerificationUrl,
  'passwordResetUrl': ?instance.passwordResetUrl,
  'ownerIds': ?instance.ownerIds,
  'createdAt': ?CreateScopeCommandOutput._write_createdAt(instance.createdAt),
};
