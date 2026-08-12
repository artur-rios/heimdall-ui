// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_scope_permission_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteScopePermissionCommandOutputDataOutput
_$DeleteScopePermissionCommandOutputDataOutputFromJson(
  Map<String, dynamic> json,
) => DeleteScopePermissionCommandOutputDataOutput(
  messages: (json['messages'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  errors: (json['errors'] as List<dynamic>?)?.map((e) => e as String).toList(),
  timestamp: json['timestamp'] == null
      ? null
      : DateTime.parse(json['timestamp'] as String),
  success: json['success'] as bool?,
  data: json['data'] == null
      ? null
      : DeleteScopePermissionCommandOutput.fromJson(
          json['data'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$DeleteScopePermissionCommandOutputDataOutputToJson(
  DeleteScopePermissionCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
