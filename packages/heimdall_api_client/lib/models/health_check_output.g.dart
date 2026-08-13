// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_check_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HealthCheckOutput _$HealthCheckOutputFromJson(Map<String, dynamic> json) =>
    HealthCheckOutput(
      status: json['status'] as String?,
      services: (json['services'] as List<dynamic>?)
          ?.map((e) => ServiceHealthOutput.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$HealthCheckOutputToJson(HealthCheckOutput instance) =>
    <String, dynamic>{'status': instance.status, 'services': instance.services};
