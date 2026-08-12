// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'google_sign_in_command.g.dart';

@JsonSerializable()
class GoogleSignInCommand {
  const GoogleSignInCommand({this.scopeId, this.idToken});

  factory GoogleSignInCommand.fromJson(Map<String, Object?> json) =>
      _$GoogleSignInCommandFromJson(json);

  final String? scopeId;
  final String? idToken;

  Map<String, Object?> toJson() => _$GoogleSignInCommandToJson(this);
}
