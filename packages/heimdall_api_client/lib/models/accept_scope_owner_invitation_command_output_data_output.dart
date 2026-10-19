// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'accept_scope_owner_invitation_command_output.dart';

part 'accept_scope_owner_invitation_command_output_data_output.g.dart';

@JsonSerializable()
class AcceptScopeOwnerInvitationCommandOutputDataOutput {
  const AcceptScopeOwnerInvitationCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory AcceptScopeOwnerInvitationCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$AcceptScopeOwnerInvitationCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final AcceptScopeOwnerInvitationCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$AcceptScopeOwnerInvitationCommandOutputDataOutputToJson(this);
}
