// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_person_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeletePersonCommandOutputDataOutput
_$DeletePersonCommandOutputDataOutputFromJson(Map<String, dynamic> json) =>
    DeletePersonCommandOutputDataOutput(
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
          : DeletePersonCommandOutput.fromJson(
              json['data'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$DeletePersonCommandOutputDataOutputToJson(
  DeletePersonCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
