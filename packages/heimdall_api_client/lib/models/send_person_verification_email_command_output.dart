// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'send_person_verification_email_command_output.g.dart';

@JsonSerializable()
class SendPersonVerificationEmailCommandOutput {
  const SendPersonVerificationEmailCommandOutput({this.id});

  factory SendPersonVerificationEmailCommandOutput.fromJson(
    Map<String, Object?> json,
  ) => _$SendPersonVerificationEmailCommandOutputFromJson(json);

  final String? id;

  Map<String, Object?> toJson() =>
      _$SendPersonVerificationEmailCommandOutputToJson(this);
}
