// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'decline_scope_owner_invitation_command_output.dart';

part 'decline_scope_owner_invitation_command_output_data_output.g.dart';

@JsonSerializable()
class DeclineScopeOwnerInvitationCommandOutputDataOutput {
  const DeclineScopeOwnerInvitationCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory DeclineScopeOwnerInvitationCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$DeclineScopeOwnerInvitationCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final DeclineScopeOwnerInvitationCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$DeclineScopeOwnerInvitationCommandOutputDataOutputToJson(this);
}
