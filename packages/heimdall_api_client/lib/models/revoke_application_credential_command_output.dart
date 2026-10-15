// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'revoke_application_credential_command_output.g.dart';

@JsonSerializable()
class RevokeApplicationCredentialCommandOutput {
  const RevokeApplicationCredentialCommandOutput({this.id, this.revokedAt});

  factory RevokeApplicationCredentialCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$RevokeApplicationCredentialCommandOutputFromJson(json);

  final String? id;
  final DateTime? revokedAt;

  Map<String, Object?> toJson() =>
      _$RevokeApplicationCredentialCommandOutputToJson(this);
}
