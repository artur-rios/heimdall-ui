// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'remove_scope_owner_command_output.g.dart';

@JsonSerializable()
class RemoveScopeOwnerCommandOutput {
  const RemoveScopeOwnerCommandOutput({this.scopeId, this.personId});

  factory RemoveScopeOwnerCommandOutput.fromJson(Map<String, Object?> json) =>
      _$RemoveScopeOwnerCommandOutputFromJson(json);

  final String? scopeId;
  final String? personId;

  Map<String, Object?> toJson() => _$RemoveScopeOwnerCommandOutputToJson(this);
}
