// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_scope_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateScopeCommand _$CreateScopeCommandFromJson(Map<String, dynamic> json) =>
    CreateScopeCommand(
      name: json['name'] as String?,
      description: json['description'] as String?,
      ownerIds: (json['ownerIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$CreateScopeCommandToJson(CreateScopeCommand instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'ownerIds': instance.ownerIds,
    };
