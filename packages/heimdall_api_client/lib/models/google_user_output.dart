// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'google_user_output.g.dart';

@JsonSerializable()
class GoogleUserOutput {
  const GoogleUserOutput({
    this.id,
    this.googleId,
    this.name,
    this.email,
    this.emailVerified,
    this.profilePictureUrl,
    this.isDeleted,
    this.scopeId,
    this.createdAt,
    this.updatedAt,
  });

  factory GoogleUserOutput.fromJson(Map<String, Object?> json) =>
      _$GoogleUserOutputFromJson(json);

  final String? id;
  final String? googleId;
  final String? name;
  final String? email;
  final bool? emailVerified;
  final String? profilePictureUrl;
  final bool? isDeleted;
  final String? scopeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => _$GoogleUserOutputToJson(this);
}
