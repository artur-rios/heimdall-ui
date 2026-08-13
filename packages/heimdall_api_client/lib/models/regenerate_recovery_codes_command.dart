// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'regenerate_recovery_codes_command.g.dart';

@JsonSerializable()
class RegenerateRecoveryCodesCommand {
  const RegenerateRecoveryCodesCommand({this.code, this.recoveryCode});

  factory RegenerateRecoveryCodesCommand.fromJson(Map<String, Object?> json) =>
      _$RegenerateRecoveryCodesCommandFromJson(json);

  final String? code;
  final String? recoveryCode;

  Map<String, Object?> toJson() => _$RegenerateRecoveryCodesCommandToJson(this);
}
