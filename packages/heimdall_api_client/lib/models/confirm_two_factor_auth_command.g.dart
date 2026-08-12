// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'confirm_two_factor_auth_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfirmTwoFactorAuthCommand _$ConfirmTwoFactorAuthCommandFromJson(
  Map<String, dynamic> json,
) => ConfirmTwoFactorAuthCommand(
  appCode: json['appCode'] as String?,
  emailCode: json['emailCode'] as String?,
  actingPersonId: json['actingPersonId'] as String?,
  actingRole: (json['actingRole'] as num?)?.toInt(),
);

Map<String, dynamic> _$ConfirmTwoFactorAuthCommandToJson(
  ConfirmTwoFactorAuthCommand instance,
) => <String, dynamic>{
  'appCode': instance.appCode,
  'emailCode': instance.emailCode,
  'actingPersonId': instance.actingPersonId,
  'actingRole': instance.actingRole,
};
