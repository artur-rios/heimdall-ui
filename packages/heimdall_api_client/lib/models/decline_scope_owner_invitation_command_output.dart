// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'decline_scope_owner_invitation_command_output.g.dart';

@JsonSerializable()
class DeclineScopeOwnerInvitationCommandOutput {
  const DeclineScopeOwnerInvitationCommandOutput({this.id});

  factory DeclineScopeOwnerInvitationCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$DeclineScopeOwnerInvitationCommandOutputFromJson(json);

  final String? id;

  Map<String, Object?> toJson() =>
      _$DeclineScopeOwnerInvitationCommandOutputToJson(this);
}
