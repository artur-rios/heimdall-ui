// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_credential_list_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplicationCredentialListOutput _$ApplicationCredentialListOutputFromJson(
  Map<String, dynamic> json,
) => ApplicationCredentialListOutput(
  credentials: (json['credentials'] as List<dynamic>?)
      ?.map(
        (e) => ApplicationCredentialOutput.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
);

Map<String, dynamic> _$ApplicationCredentialListOutputToJson(
  ApplicationCredentialListOutput instance,
) => <String, dynamic>{'credentials': instance.credentials};
