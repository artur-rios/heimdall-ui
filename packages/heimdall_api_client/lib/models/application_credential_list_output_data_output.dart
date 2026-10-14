// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'application_credential_list_output.dart';

part 'application_credential_list_output_data_output.g.dart';

@JsonSerializable()
class ApplicationCredentialListOutputDataOutput {
  const ApplicationCredentialListOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory ApplicationCredentialListOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$ApplicationCredentialListOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final ApplicationCredentialListOutput? data;

  Map<String, Object?> toJson() =>
      _$ApplicationCredentialListOutputDataOutputToJson(this);
}
