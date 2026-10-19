// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'scope_owner_invitation_output.dart';

part 'scope_owner_invitation_output_paginated_output.g.dart';

@JsonSerializable()
class ScopeOwnerInvitationOutputPaginatedOutput {
  const ScopeOwnerInvitationOutputPaginatedOutput({
    this.messages,
    this.errors,
    this.timestamp,
    this.success,
    this.data,
    this.pageNumber,
    this.pageSize,
    this.totalItems,
    this.totalPages,
  });

  factory ScopeOwnerInvitationOutputPaginatedOutput.fromJson(
    Map<String, Object?> json,
  ) => _$ScopeOwnerInvitationOutputPaginatedOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final List<ScopeOwnerInvitationOutput>? data;
  final int? pageNumber;
  final int? pageSize;
  final int? totalItems;
  final int? totalPages;

  Map<String, Object?> toJson() =>
      _$ScopeOwnerInvitationOutputPaginatedOutputToJson(this);
}
