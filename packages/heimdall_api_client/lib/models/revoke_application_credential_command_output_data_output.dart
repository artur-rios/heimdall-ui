// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'revoke_application_credential_command_output.dart';

part 'revoke_application_credential_command_output_data_output.g.dart';

@JsonSerializable()
class RevokeApplicationCredentialCommandOutputDataOutput {
  const RevokeApplicationCredentialCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory RevokeApplicationCredentialCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$RevokeApplicationCredentialCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final RevokeApplicationCredentialCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$RevokeApplicationCredentialCommandOutputDataOutputToJson(this);
}
