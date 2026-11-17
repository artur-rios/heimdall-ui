// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hard_delete_person_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HardDeletePersonCommandOutput _$HardDeletePersonCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['id', 'deletedApplicationCount', 'deletedTokenCount'],
    disallowNullValues: const [
      'id',
      'deletedApplicationCount',
      'deletedTokenCount',
    ],
  );
  return HardDeletePersonCommandOutput(
    id: json['id'] as String?,
    deletedApplicationCount:
        HardDeletePersonCommandOutput._read_deletedApplicationCount(
          json['deletedApplicationCount'],
        ),
    deletedTokenCount: HardDeletePersonCommandOutput._read_deletedTokenCount(
      json['deletedTokenCount'],
    ),
  );
}

Map<String, dynamic> _$HardDeletePersonCommandOutputToJson(
  HardDeletePersonCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'deletedApplicationCount':
      ?HardDeletePersonCommandOutput._write_deletedApplicationCount(
        instance.deletedApplicationCount,
      ),
  'deletedTokenCount': ?HardDeletePersonCommandOutput._write_deletedTokenCount(
    instance.deletedTokenCount,
  ),
};
