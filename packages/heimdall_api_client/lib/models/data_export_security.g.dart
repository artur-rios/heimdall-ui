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
    );

Map<String, dynamic> _$DataExportSecurityToJson(DataExportSecurity instance) =>
    <String, dynamic>{
      'passwordSet': instance.passwordSet,
      'twoFactorActive': instance.twoFactorActive,
      'twoFactorAppEnabled': instance.twoFactorAppEnabled,
      'twoFactorEmailEnabled': instance.twoFactorEmailEnabled,
      'unusedRecoveryCodes': instance.unusedRecoveryCodes,
      'failedLoginAttempts': instance.failedLoginAttempts,
      'lockedOutUntil': instance.lockedOutUntil?.toIso8601String(),
    };
