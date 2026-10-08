// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'resend_two_factor_challenge_code_command.g.dart';

@JsonSerializable()
class ResendTwoFactorChallengeCodeCommand {
  const ResendTwoFactorChallengeCodeCommand({this.challengeToken});

  factory ResendTwoFactorChallengeCodeCommand.fromJson(
    Map<String, Object?> json,
  ) => _$ResendTwoFactorChallengeCodeCommandFromJson(json);

  final String? challengeToken;

  Map<String, Object?> toJson() =>
      _$ResendTwoFactorChallengeCodeCommandToJson(this);
}
