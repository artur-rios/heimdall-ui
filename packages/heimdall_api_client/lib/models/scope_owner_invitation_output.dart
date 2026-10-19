// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'scope_owner_invitation_output.g.dart';

@JsonSerializable()
class ScopeOwnerInvitationOutput {
  const ScopeOwnerInvitationOutput({
    this.id,
    this.inviteeId,
    this.inviteeName,
    this.inviteeEmail,
    this.invitedByName,
    this.createdAt,
    this.expiresAt,
  });

  factory ScopeOwnerInvitationOutput.fromJson(Map<String, Object?> json) =>
      _$ScopeOwnerInvitationOutputFromJson(json);

  final String? id;
  final String? inviteeId;
  final String? inviteeName;
  final String? inviteeEmail;
  final String? invitedByName;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => _$ScopeOwnerInvitationOutputToJson(this);
}
