// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_sign_in_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleSignInCommand _$GoogleSignInCommandFromJson(Map<String, dynamic> json) =>
    GoogleSignInCommand(
      scopeId: json['scopeId'] as String?,
      idToken: json['idToken'] as String?,
    );

Map<String, dynamic> _$GoogleSignInCommandToJson(
  GoogleSignInCommand instance,
) => <String, dynamic>{
  'scopeId': instance.scopeId,
  'idToken': instance.idToken,
};
