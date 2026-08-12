// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_application_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateApplicationCommand _$UpdateApplicationCommandFromJson(
  Map<String, dynamic> json,
) => UpdateApplicationCommand(
  scopeId: json['scopeId'] as String?,
  id: json['id'] as String?,
  name: json['name'] as String?,
  ownerId: json['ownerId'] as String?,
  actingPersonId: json['actingPersonId'] as String?,
  actingRole: (json['actingRole'] as num?)?.toInt(),
);

Map<String, dynamic> _$UpdateApplicationCommandToJson(
  UpdateApplicationCommand instance,
) => <String, dynamic>{
  'scopeId': instance.scopeId,
  'id': instance.id,
  'name': instance.name,
  'ownerId': instance.ownerId,
  'actingPersonId': instance.actingPersonId,
  'actingRole': instance.actingRole,
};
