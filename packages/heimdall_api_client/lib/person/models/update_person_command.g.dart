// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_person_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdatePersonCommand _$UpdatePersonCommandFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'name',
      'email',
      'roleId',
      'currentPassword',
      'twoFactorCode',
    ],
  );
  return UpdatePersonCommand(
    name: json['name'] as String?,
    email: json['email'] as String?,
    roleId: UpdatePersonCommand._read_roleId(json['roleId']),
    currentPassword: json['currentPassword'] as String?,
    twoFactorCode: json['twoFactorCode'] as String?,
  );
}

Map<String, dynamic> _$UpdatePersonCommandToJson(
  UpdatePersonCommand instance,
) => <String, dynamic>{
  'name': ?instance.name,
  'email': ?instance.email,
  'roleId': ?UpdatePersonCommand._write_roleId(instance.roleId),
  'currentPassword': ?instance.currentPassword,
  'twoFactorCode': ?instance.twoFactorCode,
};
