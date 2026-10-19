// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'data_export_security.g.dart';

@JsonSerializable()
class DataExportSecurity {
  const DataExportSecurity({
    this.passwordSet,
    this.twoFactorActive,
    this.twoFactorAppEnabled,
    this.twoFactorEmailEnabled,
    this.unusedRecoveryCodes,
    this.failedLoginAttempts,
    this.lockedOutUntil,
    this.failedSecondFactorAttempts,
    this.secondFactorLockedOutUntil,
    this.secondFactorLockouts,
    this.failedReauthenticationAttempts,
    this.reauthenticationWindowStartedAt,
    this.reauthenticationPausedUntil,
    this.accountEmailsSent,
    this.accountEmailWindowEndsAt,
    this.accountEmailLastSentAt,
  });

  factory DataExportSecurity.fromJson(Map<String, Object?> json) =>
      _$DataExportSecurityFromJson(json);

  final bool? passwordSet;
  final bool? twoFactorActive;
  final bool? twoFactorAppEnabled;
  final bool? twoFactorEmailEnabled;
  final int? unusedRecoveryCodes;
  final int? failedLoginAttempts;
  final DateTime? lockedOutUntil;
  final int? failedSecondFactorAttempts;
  final DateTime? secondFactorLockedOutUntil;
  final int? secondFactorLockouts;
  final int? failedReauthenticationAttempts;
  final DateTime? reauthenticationWindowStartedAt;
  final DateTime? reauthenticationPausedUntil;
  final int? accountEmailsSent;
  final DateTime? accountEmailWindowEndsAt;
  final DateTime? accountEmailLastSentAt;

  Map<String, Object?> toJson() => _$DataExportSecurityToJson(this);
}
