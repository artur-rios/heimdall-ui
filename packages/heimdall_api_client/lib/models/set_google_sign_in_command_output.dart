// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'set_google_sign_in_command_output.g.dart';

@JsonSerializable()
class SetGoogleSignInCommandOutput {
  const SetGoogleSignInCommandOutput({
    this.id,
    this.name,
    this.description,
    this.googleSignInEnabled,
    this.ownerIds,
    this.createdAt,
    this.updatedAt,
  });

  factory SetGoogleSignInCommandOutput.fromJson(Map<String, Object?> json) =>
      _$SetGoogleSignInCommandOutputFromJson(json);

  final String? id;
  final String? name;
  final String? description;
  final bool? googleSignInEnabled;
  final List<String>? ownerIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => _$SetGoogleSignInCommandOutputToJson(this);
}
