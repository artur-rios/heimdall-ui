// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'enable_two_factor_auth_command_output.g.dart';

@JsonSerializable()
class EnableTwoFactorAuthCommandOutput {
  const EnableTwoFactorAuthCommandOutput({this.otpAuthUri, this.emailCodeSent});

  factory EnableTwoFactorAuthCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$EnableTwoFactorAuthCommandOutputFromJson(json);

  final String? otpAuthUri;
  final bool? emailCodeSent;

  Map<String, Object?> toJson() =>
      _$EnableTwoFactorAuthCommandOutputToJson(this);
}
