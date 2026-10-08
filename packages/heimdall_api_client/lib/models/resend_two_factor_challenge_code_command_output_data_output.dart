// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'resend_two_factor_challenge_code_command_output.dart';

part 'resend_two_factor_challenge_code_command_output_data_output.g.dart';

@JsonSerializable()
class ResendTwoFactorChallengeCodeCommandOutputDataOutput {
  const ResendTwoFactorChallengeCodeCommandOutputDataOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
  });

  factory ResendTwoFactorChallengeCodeCommandOutputDataOutput.fromJson(
    Map<String, Object?> json,
  ) => _$ResendTwoFactorChallengeCodeCommandOutputDataOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final ResendTwoFactorChallengeCodeCommandOutput? data;

  Map<String, Object?> toJson() =>
      _$ResendTwoFactorChallengeCodeCommandOutputDataOutputToJson(this);
}
