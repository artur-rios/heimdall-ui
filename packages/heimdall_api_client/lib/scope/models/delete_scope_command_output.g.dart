// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_scope_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteScopeCommandOutput _$DeleteScopeCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'userCount',
      'googleUserCount',
      'applicationCount',
    ],
    disallowNullValues: const [
      'id',
      'userCount',
      'googleUserCount',
      'applicationCount',
    ],
  );
  return DeleteScopeCommandOutput(
    id: json['id'] as String?,
    userCount: DeleteScopeCommandOutput._read_userCount(json['userCount']),
    googleUserCount: DeleteScopeCommandOutput._read_googleUserCount(
      json['googleUserCount'],
    ),
    applicationCount: DeleteScopeCommandOutput._read_applicationCount(
      json['applicationCount'],
    ),
  );
}

Map<String, dynamic> _$DeleteScopeCommandOutputToJson(
  DeleteScopeCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'userCount': ?DeleteScopeCommandOutput._write_userCount(instance.userCount),
  'googleUserCount': ?DeleteScopeCommandOutput._write_googleUserCount(
    instance.googleUserCount,
  ),
  'applicationCount': ?DeleteScopeCommandOutput._write_applicationCount(
    instance.applicationCount,
  ),
};
