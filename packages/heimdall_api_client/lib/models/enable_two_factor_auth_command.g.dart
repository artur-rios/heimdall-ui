// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enable_two_factor_auth_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EnableTwoFactorAuthCommand _$EnableTwoFactorAuthCommandFromJson(
  Map<String, dynamic> json,
) => EnableTwoFactorAuthCommand(
  methods: (json['methods'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$EnableTwoFactorAuthCommandToJson(
  EnableTwoFactorAuthCommand instance,
) => <String, dynamic>{'methods': instance.methods};
