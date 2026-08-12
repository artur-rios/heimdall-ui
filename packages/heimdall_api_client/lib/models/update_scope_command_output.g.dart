// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_scope_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateScopeCommandOutput _$UpdateScopeCommandOutputFromJson(
  Map<String, dynamic> json,
) => UpdateScopeCommandOutput(
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
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UpdateScopeCommandOutputToJson(
  UpdateScopeCommandOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'googleSignInEnabled': instance.googleSignInEnabled,
  'ownerIds': instance.ownerIds,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
