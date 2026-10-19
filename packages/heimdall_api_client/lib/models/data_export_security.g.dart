// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_security.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportSecurity _$DataExportSecurityFromJson(Map<String, dynamic> json) =>
    DataExportSecurity(
      passwordSet: json['passwordSet'] as bool?,
      twoFactorActive: json['twoFactorActive'] as bool?,
      twoFactorAppEnabled: json['twoFactorAppEnabled'] as bool?,
      twoFactorEmailEnabled: json['twoFactorEmailEnabled'] as bool?,
      unusedRecoveryCodes: (json['unusedRecoveryCodes'] as num?)?.toInt(),
      failedLoginAttempts: (json['failedLoginAttempts'] as num?)?.toInt(),
      lockedOutUntil: json['lockedOutUntil'] == null
          ? null
          : DateTime.parse(json['lockedOutUntil'] as String),
      failedSecondFactorAttempts: (json['failedSecondFactorAttempts'] as num?)
          ?.toInt(),
      secondFactorLockedOutUntil: json['secondFactorLockedOutUntil'] == null
          ? null
          : DateTime.parse(json['secondFactorLockedOutUntil'] as String),
      secondFactorLockouts: (json['secondFactorLockouts'] as num?)?.toInt(),
      failedReauthenticationAttempts:
          (json['failedReauthenticationAttempts'] as num?)?.toInt(),
      reauthenticationWindowStartedAt:
          json['reauthenticationWindowStartedAt'] == null
          ? null
          : DateTime.parse(json['reauthenticationWindowStartedAt'] as String),
      reauthenticationPausedUntil: json['reauthenticationPausedUntil'] == null
          ? null
          : DateTime.parse(json['reauthenticationPausedUntil'] as String),
      accountEmailsSent: (json['accountEmailsSent'] as num?)?.toInt(),
      accountEmailWindowEndsAt: json['accountEmailWindowEndsAt'] == null
          ? null
          : DateTime.parse(json['accountEmailWindowEndsAt'] as String),
      accountEmailLastSentAt: json['accountEmailLastSentAt'] == null
          ? null
          : DateTime.parse(json['accountEmailLastSentAt'] as String),
    );

Map<String, dynamic> _$DataExportSecurityToJson(
  DataExportSecurity instance,
) => <String, dynamic>{
  'passwordSet': instance.passwordSet,
  'twoFactorActive': instance.twoFactorActive,
  'twoFactorAppEnabled': instance.twoFactorAppEnabled,
  'twoFactorEmailEnabled': instance.twoFactorEmailEnabled,
  'unusedRecoveryCodes': instance.unusedRecoveryCodes,
  'failedLoginAttempts': instance.failedLoginAttempts,
  'lockedOutUntil': instance.lockedOutUntil?.toIso8601String(),
  'failedSecondFactorAttempts': instance.failedSecondFactorAttempts,
  'secondFactorLockedOutUntil': instance.secondFactorLockedOutUntil
      ?.toIso8601String(),
  'secondFactorLockouts': instance.secondFactorLockouts,
  'failedReauthenticationAttempts': instance.failedReauthenticationAttempts,
  'reauthenticationWindowStartedAt': instance.reauthenticationWindowStartedAt
      ?.toIso8601String(),
  'reauthenticationPausedUntil': instance.reauthenticationPausedUntil
      ?.toIso8601String(),
  'accountEmailsSent': instance.accountEmailsSent,
  'accountEmailWindowEndsAt': instance.accountEmailWindowEndsAt
      ?.toIso8601String(),
  'accountEmailLastSentAt': instance.accountEmailLastSentAt?.toIso8601String(),
};
