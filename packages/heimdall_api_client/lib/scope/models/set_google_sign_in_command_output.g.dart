// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_google_sign_in_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetGoogleSignInCommandOutput _$SetGoogleSignInCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'name',
      'description',
      'googleSignInEnabled',
      'emailVerificationUrl',
      'passwordResetUrl',
      'ownerIds',
      'createdAt',
      'updatedAt',
    ],
    disallowNullValues: const [
      'id',
      'googleSignInEnabled',
      'createdAt',
      'updatedAt',
    ],
  );
  return SetGoogleSignInCommandOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    description: json['description'] as String?,
    googleSignInEnabled: json['googleSignInEnabled'] as bool?,
    emailVerificationUrl: json['emailVerificationUrl'] as String?,
    passwordResetUrl: json['passwordResetUrl'] as String?,
    ownerIds: (json['ownerIds'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    createdAt: SetGoogleSignInCommandOutput._read_createdAt(json['createdAt']),
    updatedAt: SetGoogleSignInCommandOutput._read_updatedAt(json['updatedAt']),
  );
}

Map<String, dynamic> _$SetGoogleSignInCommandOutputToJson(
  SetGoogleSignInCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'description': ?instance.description,
  'googleSignInEnabled': ?instance.googleSignInEnabled,
  'emailVerificationUrl': ?instance.emailVerificationUrl,
  'passwordResetUrl': ?instance.passwordResetUrl,
  'ownerIds': ?instance.ownerIds,
  'createdAt': ?SetGoogleSignInCommandOutput._write_createdAt(
    instance.createdAt,
  ),
  'updatedAt': ?SetGoogleSignInCommandOutput._write_updatedAt(
    instance.updatedAt,
  ),
};
