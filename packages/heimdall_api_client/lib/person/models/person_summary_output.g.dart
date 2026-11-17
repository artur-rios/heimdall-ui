// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_summary_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonSummaryOutput _$PersonSummaryOutputFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const ['id', 'name', 'email'],
    disallowNullValues: const ['id'],
  );
  return PersonSummaryOutput(
    id: json['id'] as String?,
    name: json['name'] as String?,
    email: json['email'] as String?,
  );
}

Map<String, dynamic> _$PersonSummaryOutputToJson(
  PersonSummaryOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'email': ?instance.email,
};
