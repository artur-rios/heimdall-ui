// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_scope_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateScopeCommand _$UpdateScopeCommandFromJson(Map<String, dynamic> json) =>
    UpdateScopeCommand(
      name: json['name'] as String?,
      description: json['description'] as String?,
      defaultLegalBasis: (json['defaultLegalBasis'] as num?)?.toInt(),
      privacyNoticeUri: json['privacyNoticeUri'] as String?,
    );

Map<String, dynamic> _$UpdateScopeCommandToJson(UpdateScopeCommand instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'defaultLegalBasis': instance.defaultLegalBasis,
      'privacyNoticeUri': instance.privacyNoticeUri,
    };
