// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_google_sign_in_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetGoogleSignInCommand _$SetGoogleSignInCommandFromJson(
  Map<String, dynamic> json,
) => SetGoogleSignInCommand(
  id: json['id'] as String?,
  enabled: json['enabled'] as bool?,
  actingPersonId: json['actingPersonId'] as String?,
  actingRole: (json['actingRole'] as num?)?.toInt(),
);

Map<String, dynamic> _$SetGoogleSignInCommandToJson(
  SetGoogleSignInCommand instance,
) => <String, dynamic>{
  'id': instance.id,
  'enabled': instance.enabled,
  'actingPersonId': instance.actingPersonId,
  'actingRole': instance.actingRole,
};
