// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reapply_erasures_command_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReapplyErasuresCommandOutput _$ReapplyErasuresCommandOutputFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'anonymised',
      'alreadyAnonymised',
      'notFound',
      'scopeOwnerInvitationsVoided',
    ],
    disallowNullValues: const [
      'anonymised',
      'alreadyAnonymised',
      'scopeOwnerInvitationsVoided',
    ],
  );
  return ReapplyErasuresCommandOutput(
    anonymised: ReapplyErasuresCommandOutput._read_anonymised(
      json['anonymised'],
    ),
    alreadyAnonymised: ReapplyErasuresCommandOutput._read_alreadyAnonymised(
      json['alreadyAnonymised'],
    ),
    notFound: (json['notFound'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    scopeOwnerInvitationsVoided:
        ReapplyErasuresCommandOutput._read_scopeOwnerInvitationsVoided(
          json['scopeOwnerInvitationsVoided'],
        ),
  );
}

Map<String, dynamic> _$ReapplyErasuresCommandOutputToJson(
  ReapplyErasuresCommandOutput instance,
) => <String, dynamic>{
  'anonymised': ?ReapplyErasuresCommandOutput._write_anonymised(
    instance.anonymised,
  ),
  'alreadyAnonymised': ?ReapplyErasuresCommandOutput._write_alreadyAnonymised(
    instance.alreadyAnonymised,
  ),
  'notFound': ?instance.notFound,
  'scopeOwnerInvitationsVoided':
      ?ReapplyErasuresCommandOutput._write_scopeOwnerInvitationsVoided(
        instance.scopeOwnerInvitationsVoided,
      ),
};
