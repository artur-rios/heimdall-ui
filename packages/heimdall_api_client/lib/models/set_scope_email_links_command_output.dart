// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'set_scope_email_links_command_output.g.dart';

@JsonSerializable()
class SetScopeEmailLinksCommandOutput {
  const SetScopeEmailLinksCommandOutput({
    this.id,
    this.name,
    this.description,
    this.googleSignInEnabled,
    this.selfRegistrationEnabled,
    this.emailVerificationUrl,
    this.passwordResetUrl,
    this.ownerIds,
    this.createdAt,
    this.updatedAt,
  });

  factory SetScopeEmailLinksCommandOutput.fromJson(Map<String, Object?> json) =>
      _$SetScopeEmailLinksCommandOutputFromJson(json);

  final String? id;
  final String? name;
  final String? description;
  final bool? googleSignInEnabled;
  final bool? selfRegistrationEnabled;
  final String? emailVerificationUrl;
  final String? passwordResetUrl;
  final List<String>? ownerIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() =>
      _$SetScopeEmailLinksCommandOutputToJson(this);
}
