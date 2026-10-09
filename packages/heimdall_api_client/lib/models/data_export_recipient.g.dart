// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_export_recipient.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataExportRecipient _$DataExportRecipientFromJson(Map<String, dynamic> json) =>
    DataExportRecipient(
      name: json['name'] as String?,
      purpose: json['purpose'] as String?,
      location: json['location'] as String?,
    );

Map<String, dynamic> _$DataExportRecipientToJson(
  DataExportRecipient instance,
) => <String, dynamic>{
  'name': instance.name,
  'purpose': instance.purpose,
  'location': instance.location,
};
