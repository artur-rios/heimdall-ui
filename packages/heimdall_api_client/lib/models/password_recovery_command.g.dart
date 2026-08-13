// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'password_recovery_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PasswordRecoveryCommand _$PasswordRecoveryCommandFromJson(
  Map<String, dynamic> json,
) => PasswordRecoveryCommand(
  email: json['email'] as String?,
  scopeId: json['scopeId'] as String?,
);

Map<String, dynamic> _$PasswordRecoveryCommandToJson(
  PasswordRecoveryCommand instance,
) => <String, dynamic>{'email': instance.email, 'scopeId': instance.scopeId};
