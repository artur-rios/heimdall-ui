// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_scope_email_links_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetScopeEmailLinksCommand _$SetScopeEmailLinksCommandFromJson(
  Map<String, dynamic> json,
) => SetScopeEmailLinksCommand(
  emailVerificationUrl: json['emailVerificationUrl'] as String?,
  passwordResetUrl: json['passwordResetUrl'] as String?,
);

Map<String, dynamic> _$SetScopeEmailLinksCommandToJson(
  SetScopeEmailLinksCommand instance,
) => <String, dynamic>{
  'emailVerificationUrl': instance.emailVerificationUrl,
  'passwordResetUrl': instance.passwordResetUrl,
};
