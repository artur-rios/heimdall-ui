// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_scope_owner_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddScopeOwnerCommandOutputDataOutput
_$AddScopeOwnerCommandOutputDataOutputFromJson(Map<String, dynamic> json) =>
    AddScopeOwnerCommandOutputDataOutput(
      messages: (json['messages'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      errors: (json['errors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      success: json['success'] as bool?,
      data: json['data'] == null
          ? null
          : AddScopeOwnerCommandOutput.fromJson(
              json['data'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$AddScopeOwnerCommandOutputDataOutputToJson(
  AddScopeOwnerCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
