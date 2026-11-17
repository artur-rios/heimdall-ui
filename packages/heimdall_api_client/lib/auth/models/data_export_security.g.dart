// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_security.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportSecurity _$DataExportSecurityFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'passwordSet',
      'twoFactorActive',
      'twoFactorAppEnabled',
      'twoFactorEmailEnabled',
      'unusedRecoveryCodes',
      'failedLoginAttempts',
      'lockedOutUntil',
      'failedSecondFactorAttempts',
      'secondFactorLockedOutUntil',
      'secondFactorLockouts',
      'failedReauthenticationAttempts',
      'reauthenticationWindowStartedAt',
      'reauthenticationPausedUntil',
      'accountEmailsSent',
      'accountEmailWindowEndsAt',
      'accountEmailLastSentAt',
    ],
    disallowNullValues: const [
      'passwordSet',
      'twoFactorActive',
      'twoFactorAppEnabled',
      'twoFactorEmailEnabled',
      'unusedRecoveryCodes',
      'failedLoginAttempts',
      'failedSecondFactorAttempts',
      'secondFactorLockouts',
      'failedReauthenticationAttempts',
      'accountEmailsSent',
    ],
  );
  return DataExportSecurity(
    passwordSet: json['passwordSet'] as bool?,
    twoFactorActive: json['twoFactorActive'] as bool?,
    twoFactorAppEnabled: json['twoFactorAppEnabled'] as bool?,
    twoFactorEmailEnabled: json['twoFactorEmailEnabled'] as bool?,
    unusedRecoveryCodes: DataExportSecurity._read_unusedRecoveryCodes(
      json['unusedRecoveryCodes'],
    ),
    failedLoginAttempts: DataExportSecurity._read_failedLoginAttempts(
      json['failedLoginAttempts'],
    ),
    lockedOutUntil: DataExportSecurity._read_lockedOutUntil(
      json['lockedOutUntil'],
    ),
    failedSecondFactorAttempts:
        DataExportSecurity._read_failedSecondFactorAttempts(
          json['failedSecondFactorAttempts'],
        ),
    secondFactorLockedOutUntil:
        DataExportSecurity._read_secondFactorLockedOutUntil(
          json['secondFactorLockedOutUntil'],
        ),
    secondFactorLockouts: DataExportSecurity._read_secondFactorLockouts(
      json['secondFactorLockouts'],
    ),
    failedReauthenticationAttempts:
        DataExportSecurity._read_failedReauthenticationAttempts(
          json['failedReauthenticationAttempts'],
        ),
    reauthenticationWindowStartedAt:
        DataExportSecurity._read_reauthenticationWindowStartedAt(
          json['reauthenticationWindowStartedAt'],
        ),
    reauthenticationPausedUntil:
        DataExportSecurity._read_reauthenticationPausedUntil(
          json['reauthenticationPausedUntil'],
        ),
    accountEmailsSent: DataExportSecurity._read_accountEmailsSent(
      json['accountEmailsSent'],
    ),
    accountEmailWindowEndsAt: DataExportSecurity._read_accountEmailWindowEndsAt(
      json['accountEmailWindowEndsAt'],
    ),
    accountEmailLastSentAt: DataExportSecurity._read_accountEmailLastSentAt(
      json['accountEmailLastSentAt'],
    ),
  );
}

Map<String, dynamic> _$DataExportSecurityToJson(
  DataExportSecurity instance,
) => <String, dynamic>{
  'passwordSet': ?instance.passwordSet,
  'twoFactorActive': ?instance.twoFactorActive,
  'twoFactorAppEnabled': ?instance.twoFactorAppEnabled,
  'twoFactorEmailEnabled': ?instance.twoFactorEmailEnabled,
  'unusedRecoveryCodes': ?DataExportSecurity._write_unusedRecoveryCodes(
    instance.unusedRecoveryCodes,
  ),
  'failedLoginAttempts': ?DataExportSecurity._write_failedLoginAttempts(
    instance.failedLoginAttempts,
  ),
  'lockedOutUntil': ?DataExportSecurity._write_lockedOutUntil(
    instance.lockedOutUntil,
  ),
  'failedSecondFactorAttempts':
      ?DataExportSecurity._write_failedSecondFactorAttempts(
        instance.failedSecondFactorAttempts,
      ),
  'secondFactorLockedOutUntil':
      ?DataExportSecurity._write_secondFactorLockedOutUntil(
        instance.secondFactorLockedOutUntil,
      ),
  'secondFactorLockouts': ?DataExportSecurity._write_secondFactorLockouts(
    instance.secondFactorLockouts,
  ),
  'failedReauthenticationAttempts':
      ?DataExportSecurity._write_failedReauthenticationAttempts(
        instance.failedReauthenticationAttempts,
      ),
  'reauthenticationWindowStartedAt':
      ?DataExportSecurity._write_reauthenticationWindowStartedAt(
        instance.reauthenticationWindowStartedAt,
      ),
  'reauthenticationPausedUntil':
      ?DataExportSecurity._write_reauthenticationPausedUntil(
        instance.reauthenticationPausedUntil,
      ),
  'accountEmailsSent': ?DataExportSecurity._write_accountEmailsSent(
    instance.accountEmailsSent,
  ),
  'accountEmailWindowEndsAt':
      ?DataExportSecurity._write_accountEmailWindowEndsAt(
        instance.accountEmailWindowEndsAt,
      ),
  'accountEmailLastSentAt': ?DataExportSecurity._write_accountEmailLastSentAt(
    instance.accountEmailLastSentAt,
  ),
};
