// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_scope_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateScopeCommandOutput _$CreateScopeCommandOutputFromJson(
  Map<String, dynamic> json,
) => CreateScopeCommandOutput(
  id: json['id'] as String?,
  name: json['name'] as String?,
  description: json['description'] as String?,
  googleSignInEnabled: json['googleSignInEnabled'] as bool?,
  ownerIds: (json['ownerIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$CreateScopeCommandOutputToJson(
  CreateScopeCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'googleSignInEnabled': instance.googleSignInEnabled,
  'ownerIds': instance.ownerIds,
  'createdAt': instance.createdAt?.toIso8601String(),
};
