// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'two_factor_status_output.g.dart';

@JsonSerializable()
class TwoFactorStatusOutput {
  const TwoFactorStatusOutput({
    this.isActive,
    this.appEnabled,
    this.emailEnabled,
    this.remainingRecoveryCodes,
  });

  factory TwoFactorStatusOutput.fromJson(Map<String, Object?> json) =>
      _$TwoFactorStatusOutputFromJson(json);

  final bool? isActive;
  final bool? appEnabled;
  final bool? emailEnabled;
  final int? remainingRecoveryCodes;

  Map<String, Object?> toJson() => _$TwoFactorStatusOutputToJson(this);
}
