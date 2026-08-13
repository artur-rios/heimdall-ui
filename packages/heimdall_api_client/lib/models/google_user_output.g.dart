// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_user_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleUserOutput _$GoogleUserOutputFromJson(Map<String, dynamic> json) =>
    GoogleUserOutput(
      id: json['id'] as String?,
      googleId: json['googleId'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      emailVerified: json['emailVerified'] as bool?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      isDeleted: json['isDeleted'] as bool?,
      scopeId: json['scopeId'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$GoogleUserOutputToJson(GoogleUserOutput instance) =>
    <String, dynamic>{
      'id': instance.id,
      'googleId': instance.googleId,
      'name': instance.name,
      'email': instance.email,
      'emailVerified': instance.emailVerified,
      'profilePictureUrl': instance.profilePictureUrl,
      'isDeleted': instance.isDeleted,
      'scopeId': instance.scopeId,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
