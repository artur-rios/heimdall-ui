// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'set_self_registration_command.g.dart';

@JsonSerializable()
class SetSelfRegistrationCommand {
  const SetSelfRegistrationCommand({this.enabled});

  factory SetSelfRegistrationCommand.fromJson(Map<String, Object?> json) =>
      _$SetSelfRegistrationCommandFromJson(json);

  final bool? enabled;

  Map<String, Object?> toJson() => _$SetSelfRegistrationCommandToJson(this);
}
