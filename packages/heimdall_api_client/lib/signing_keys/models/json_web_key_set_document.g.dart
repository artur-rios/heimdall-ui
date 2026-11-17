// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'json_web_key_set_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JsonWebKeySetDocument _$JsonWebKeySetDocumentFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(json, allowedKeys: const ['keys']);
  return JsonWebKeySetDocument(
    keys: (json['keys'] as List<dynamic>?)
        ?.map((e) => JsonWebKeyDocument.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _$JsonWebKeySetDocumentToJson(
  JsonWebKeySetDocument instance,
) => <String, dynamic>{'keys': ?instance.keys?.map((e) => e.toJson()).toList()};
