// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_application_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateApplicationCommand _$CreateApplicationCommandFromJson(
  Map<String, dynamic> json,
) => CreateApplicationCommand(
  scopeId: json['scopeId'] as String?,
  name: json['name'] as String?,
  ownerId: json['ownerId'] as String?,
  actingPersonId: json['actingPersonId'] as String?,
  actingRole: (json['actingRole'] as num?)?.toInt(),
);

Map<String, dynamic> _$CreateApplicationCommandToJson(
  CreateApplicationCommand instance,
) => <String, dynamic>{
  'scopeId': instance.scopeId,
  'name': instance.name,
  'ownerId': instance.ownerId,
  'actingPersonId': instance.actingPersonId,
  'actingRole': instance.actingRole,
};
