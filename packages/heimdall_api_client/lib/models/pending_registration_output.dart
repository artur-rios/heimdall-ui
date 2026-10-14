// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'pending_registration_output.g.dart';

@JsonSerializable()
class PendingRegistrationOutput {
  const PendingRegistrationOutput({
    this.id,
    this.name,
    this.email,
    this.createdAt,
    this.expiresAt,
    this.attemptsLeft,
    this.expired,
  });

  factory PendingRegistrationOutput.fromJson(Map<String, Object?> json) =>
      _$PendingRegistrationOutputFromJson(json);

  final String? id;
  final String? name;
  final String? email;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final int? attemptsLeft;
  final bool? expired;

  Map<String, Object?> toJson() => _$PendingRegistrationOutputToJson(this);
}
