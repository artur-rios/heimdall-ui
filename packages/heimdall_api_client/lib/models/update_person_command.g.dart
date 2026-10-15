// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_person_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdatePersonCommand _$UpdatePersonCommandFromJson(Map<String, dynamic> json) =>
    UpdatePersonCommand(
      name: json['name'] as String?,
      email: json['email'] as String?,
      roleId: (json['roleId'] as num?)?.toInt(),
      currentPassword: json['currentPassword'] as String?,
      twoFactorCode: json['twoFactorCode'] as String?,
    );

Map<String, dynamic> _$UpdatePersonCommandToJson(
  UpdatePersonCommand instance,
) => <String, dynamic>{
  'name': instance.name,
  'email': instance.email,
  'roleId': instance.roleId,
  'currentPassword': instance.currentPassword,
  'twoFactorCode': instance.twoFactorCode,
};
