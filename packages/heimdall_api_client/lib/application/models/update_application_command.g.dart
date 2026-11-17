// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_application_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateApplicationCommand _$UpdateApplicationCommandFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['name', 'ownerId'],
    disallowNullValues: const ['ownerId'],
  );
  return UpdateApplicationCommand(
    name: json['name'] as String?,
    ownerId: json['ownerId'] as String?,
  );
}

Map<String, dynamic> _$UpdateApplicationCommandToJson(
  UpdateApplicationCommand instance,
) => <String, dynamic>{'name': ?instance.name, 'ownerId': ?instance.ownerId};
