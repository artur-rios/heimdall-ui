// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_token_check_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplicationTokenCheckOutput _$ApplicationTokenCheckOutputFromJson(
  Map<String, dynamic> json,
) => ApplicationTokenCheckOutput(
  applicationId: json['applicationId'] as String?,
  name: json['name'] as String?,
  scopeId: json['scopeId'] as String?,
  credentialId: json['credentialId'] as String?,
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$ApplicationTokenCheckOutputToJson(
  ApplicationTokenCheckOutput instance,
) => <String, dynamic>{
  'applicationId': instance.applicationId,
  'name': instance.name,
  'scopeId': instance.scopeId,
  'credentialId': instance.credentialId,
  'expiresAt': instance.expiresAt?.toIso8601String(),
};
