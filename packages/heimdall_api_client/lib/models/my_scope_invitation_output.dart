// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'my_scope_invitation_output.g.dart';

@JsonSerializable()
class MyScopeInvitationOutput {
  const MyScopeInvitationOutput({
    this.id,
    this.scopeId,
    this.scopeName,
    this.invitedByName,
    this.createdAt,
    this.expiresAt,
  });

  factory MyScopeInvitationOutput.fromJson(Map<String, Object?> json) =>
      _$MyScopeInvitationOutputFromJson(json);

  final String? id;
  final String? scopeId;
  final String? scopeName;
  final String? invitedByName;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => _$MyScopeInvitationOutputToJson(this);
}
