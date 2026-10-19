// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'accept_scope_owner_invitation_command_output.g.dart';

@JsonSerializable()
class AcceptScopeOwnerInvitationCommandOutput {
  const AcceptScopeOwnerInvitationCommandOutput({this.id, this.scopeId});

  factory AcceptScopeOwnerInvitationCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$AcceptScopeOwnerInvitationCommandOutputFromJson(json);

  final String? id;
  final String? scopeId;

  Map<String, Object?> toJson() =>
      _$AcceptScopeOwnerInvitationCommandOutputToJson(this);
}
