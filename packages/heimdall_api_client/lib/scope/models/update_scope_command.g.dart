// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_scope_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateScopeCommand _$UpdateScopeCommandFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'name',
      'description',
      'defaultLegalBasis',
      'privacyNoticeUri',
    ],
  );
  return UpdateScopeCommand(
    name: json['name'] as String?,
    description: json['description'] as String?,
    defaultLegalBasis: UpdateScopeCommand._read_defaultLegalBasis(
      json['defaultLegalBasis'],
    ),
    privacyNoticeUri: json['privacyNoticeUri'] as String?,
  );
}

Map<String, dynamic> _$UpdateScopeCommandToJson(UpdateScopeCommand instance) =>
    <String, dynamic>{
      'name': ?instance.name,
      'description': ?instance.description,
      'defaultLegalBasis': ?UpdateScopeCommand._write_defaultLegalBasis(
        instance.defaultLegalBasis,
      ),
      'privacyNoticeUri': ?instance.privacyNoticeUri,
    };
