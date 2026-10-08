// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_erasure_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestErasureCommand _$RequestErasureCommandFromJson(
  Map<String, dynamic> json,
) => RequestErasureCommand(
  password: json['password'] as String?,
  idToken: json['idToken'] as String?,
);

Map<String, dynamic> _$RequestErasureCommandToJson(
  RequestErasureCommand instance,
) => <String, dynamic>{
  'password': instance.password,
  'idToken': instance.idToken,
};
