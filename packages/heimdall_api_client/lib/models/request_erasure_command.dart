// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'request_erasure_command.g.dart';

@JsonSerializable()
class RequestErasureCommand {
  const RequestErasureCommand({this.password, this.idToken});

  factory RequestErasureCommand.fromJson(Map<String, Object?> json) =>
      _$RequestErasureCommandFromJson(json);

  final String? password;
  final String? idToken;

  Map<String, Object?> toJson() => _$RequestErasureCommandToJson(this);
}
