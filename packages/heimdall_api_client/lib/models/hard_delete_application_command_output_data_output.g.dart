// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hard_delete_application_command_output_data_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HardDeleteApplicationCommandOutputDataOutput
_$HardDeleteApplicationCommandOutputDataOutputFromJson(
  Map<String, dynamic> json,
) => HardDeleteApplicationCommandOutputDataOutput(
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
      : HardDeleteApplicationCommandOutput.fromJson(
          json['data'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$HardDeleteApplicationCommandOutputDataOutputToJson(
  HardDeleteApplicationCommandOutputDataOutput instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'errors': instance.errors,
  'timestamp': instance.timestamp?.toIso8601String(),
  'success': instance.success,
  'data': instance.data,
};
