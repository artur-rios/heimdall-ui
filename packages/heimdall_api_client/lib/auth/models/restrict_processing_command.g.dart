// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restrict_processing_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RestrictProcessingCommand _$RestrictProcessingCommandFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['ground'],
    disallowNullValues: const ['ground'],
  );
  return RestrictProcessingCommand(
    ground: RestrictProcessingCommand._read_ground(json['ground']),
  );
}

Map<String, dynamic> _$RestrictProcessingCommandToJson(
  RestrictProcessingCommand instance,
) => <String, dynamic>{
  'ground': ?RestrictProcessingCommand._write_ground(instance.ground),
};
