// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'set_scope_email_links_command.g.dart';

@JsonSerializable()
class SetScopeEmailLinksCommand {
  const SetScopeEmailLinksCommand({
    this.emailVerificationUrl,
    this.passwordResetUrl,
  });

  factory SetScopeEmailLinksCommand.fromJson(Map<String, Object?> json) =>
      _$SetScopeEmailLinksCommandFromJson(json);

  final String? emailVerificationUrl;
  final String? passwordResetUrl;

  Map<String, Object?> toJson() => _$SetScopeEmailLinksCommandToJson(this);
}
