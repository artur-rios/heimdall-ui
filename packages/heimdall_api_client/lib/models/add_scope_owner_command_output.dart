// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'add_scope_owner_command_output.g.dart';

@JsonSerializable()
class AddScopeOwnerCommandOutput {
  const AddScopeOwnerCommandOutput({
    this.scopeId,
    this.personId,
    this.alreadyOwner,
    this.invited,
    this.invitationId,
    this.invitationExpiresAt,
  });

  factory AddScopeOwnerCommandOutput.fromJson(Map<String, Object?> json) =>
      _$AddScopeOwnerCommandOutputFromJson(json);

  final String? scopeId;
  final String? personId;
  final bool? alreadyOwner;
  final bool? invited;
  final String? invitationId;
  final DateTime? invitationExpiresAt;

  Map<String, Object?> toJson() => _$AddScopeOwnerCommandOutputToJson(this);
}
