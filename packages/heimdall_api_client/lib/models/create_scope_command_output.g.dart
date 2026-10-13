// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_scope_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateScopeCommandOutput _$CreateScopeCommandOutputFromJson(
  Map<String, dynamic> json,
) => CreateScopeCommandOutput(
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
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$CreateScopeCommandOutputToJson(
  CreateScopeCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'googleSignInEnabled': instance.googleSignInEnabled,
  'selfRegistrationEnabled': instance.selfRegistrationEnabled,
  'emailVerificationUrl': instance.emailVerificationUrl,
  'passwordResetUrl': instance.passwordResetUrl,
  'ownerIds': instance.ownerIds,
  'createdAt': instance.createdAt?.toIso8601String(),
};
