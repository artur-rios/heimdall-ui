// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_health_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceHealthOutput _$ServiceHealthOutputFromJson(Map<String, dynamic> json) =>
    ServiceHealthOutput(
      name: json['name'] as String?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$ServiceHealthOutputToJson(
  ServiceHealthOutput instance,
) => <String, dynamic>{'name': instance.name, 'status': instance.status};
