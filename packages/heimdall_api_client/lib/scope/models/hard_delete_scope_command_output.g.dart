// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hard_delete_scope_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HardDeleteScopeCommandOutput _$HardDeleteScopeCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'userCount',
      'googleUserCount',
      'applicationCount',
      'scopePermissionCount',
    ],
    disallowNullValues: const [
      'id',
      'userCount',
      'googleUserCount',
      'applicationCount',
      'scopePermissionCount',
    ],
  );
  return HardDeleteScopeCommandOutput(
    id: json['id'] as String?,
    userCount: HardDeleteScopeCommandOutput._read_userCount(json['userCount']),
    googleUserCount: HardDeleteScopeCommandOutput._read_googleUserCount(
      json['googleUserCount'],
    ),
    applicationCount: HardDeleteScopeCommandOutput._read_applicationCount(
      json['applicationCount'],
    ),
    scopePermissionCount:
        HardDeleteScopeCommandOutput._read_scopePermissionCount(
          json['scopePermissionCount'],
        ),
  );
}

Map<String, dynamic> _$HardDeleteScopeCommandOutputToJson(
  HardDeleteScopeCommandOutput instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'userCount': ?HardDeleteScopeCommandOutput._write_userCount(
    instance.userCount,
  ),
  'googleUserCount': ?HardDeleteScopeCommandOutput._write_googleUserCount(
    instance.googleUserCount,
  ),
  'applicationCount': ?HardDeleteScopeCommandOutput._write_applicationCount(
    instance.applicationCount,
  ),
  'scopePermissionCount':
      ?HardDeleteScopeCommandOutput._write_scopePermissionCount(
        instance.scopePermissionCount,
      ),
};
