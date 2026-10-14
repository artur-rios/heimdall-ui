// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'application_credential_output.dart';

part 'application_credential_list_output.g.dart';

@JsonSerializable()
class ApplicationCredentialListOutput {
  const ApplicationCredentialListOutput({this.credentials});

  factory ApplicationCredentialListOutput.fromJson(Map<String, Object?> json) =>
      _$ApplicationCredentialListOutputFromJson(json);

  final List<ApplicationCredentialOutput>? credentials;

  Map<String, Object?> toJson() =>
      _$ApplicationCredentialListOutputToJson(this);
}
