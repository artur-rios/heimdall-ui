// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'discard_pending_registration_command_output.g.dart';

@JsonSerializable()
class DiscardPendingRegistrationCommandOutput {
  const DiscardPendingRegistrationCommandOutput({this.id});

  factory DiscardPendingRegistrationCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$DiscardPendingRegistrationCommandOutputFromJson(json);

  final String? id;

  Map<String, Object?> toJson() =>
      _$DiscardPendingRegistrationCommandOutputToJson(this);
}
