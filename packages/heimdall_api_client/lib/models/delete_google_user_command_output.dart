// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'delete_google_user_command_output.g.dart';

@JsonSerializable()
class DeleteGoogleUserCommandOutput {
  const DeleteGoogleUserCommandOutput({this.id, this.alreadyDeleted});

  factory DeleteGoogleUserCommandOutput.fromJson(Map<String, Object?> json) =>
      _$DeleteGoogleUserCommandOutputFromJson(json);

  final String? id;
  final bool? alreadyDeleted;

  Map<String, Object?> toJson() => _$DeleteGoogleUserCommandOutputToJson(this);
}
