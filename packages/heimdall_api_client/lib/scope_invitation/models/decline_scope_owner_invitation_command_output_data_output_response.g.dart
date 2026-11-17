// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decline_scope_owner_invitation_command_output_data_output_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeclineScopeOwnerInvitationCommandOutputDataOutput$Response
_$DeclineScopeOwnerInvitationCommandOutputDataOutput$ResponseFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['messages', 'errors', 'timestamp', 'success', 'data'],
    disallowNullValues: const ['timestamp', 'success'],
  );
  return DeclineScopeOwnerInvitationCommandOutputDataOutput$Response(
    messages: (json['messages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    errors: (json['errors'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp:
        DeclineScopeOwnerInvitationCommandOutputDataOutput$Response._read_timestamp(
          json['timestamp'],
        ),
    success: json['success'] as bool?,
    data: json['data'] == null
        ? null
        : DeclineScopeOwnerInvitationCommandOutput.fromJson(
            json['data'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic>
_$DeclineScopeOwnerInvitationCommandOutputDataOutput$ResponseToJson(
  DeclineScopeOwnerInvitationCommandOutputDataOutput$Response instance,
) => <String, dynamic>{
  'messages': ?instance.messages,
  'errors': ?instance.errors,
  'timestamp':
      ?DeclineScopeOwnerInvitationCommandOutputDataOutput$Response._write_timestamp(
        instance.timestamp,
      ),
  'success': ?instance.success,
  'data': ?instance.data?.toJson(),
};
