// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'regenerate_recovery_codes_command_output.g.dart';

@JsonSerializable()
class RegenerateRecoveryCodesCommandOutput {
  const RegenerateRecoveryCodesCommandOutput({this.recoveryCodes});

  factory RegenerateRecoveryCodesCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$RegenerateRecoveryCodesCommandOutputFromJson(json);

  final List<String>? recoveryCodes;

  Map<String, Object?> toJson() =>
      _$RegenerateRecoveryCodesCommandOutputToJson(this);
}
