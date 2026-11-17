// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'json_web_key_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JsonWebKeyDocument _$JsonWebKeyDocumentFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const ['kty', 'crv', 'x', 'y', 'kid', 'use', 'alg'],
  );
  return JsonWebKeyDocument(
    kty: json['kty'] as String?,
    crv: json['crv'] as String?,
    x: json['x'] as String?,
    y: json['y'] as String?,
    kid: json['kid'] as String?,
    use: json['use'] as String?,
    alg: json['alg'] as String?,
  );
}

Map<String, dynamic> _$JsonWebKeyDocumentToJson(JsonWebKeyDocument instance) =>
    <String, dynamic>{
      'kty': ?instance.kty,
      'crv': ?instance.crv,
      'x': ?instance.x,
      'y': ?instance.y,
      'kid': ?instance.kid,
      'use': ?instance.use,
      'alg': ?instance.alg,
    };
