// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_application_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateApplicationCommand _$CreateApplicationCommandFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['name', 'ownerId'],
    disallowNullValues: const ['ownerId'],
  );
  return CreateApplicationCommand(
    name: json['name'] as String?,
    ownerId: json['ownerId'] as String?,
  );
}

Map<String, dynamic> _$CreateApplicationCommandToJson(
  CreateApplicationCommand instance,
) => <String, dynamic>{'name': ?instance.name, 'ownerId': ?instance.ownerId};
