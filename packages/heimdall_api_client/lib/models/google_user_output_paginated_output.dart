// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'google_user_output.dart';

part 'google_user_output_paginated_output.g.dart';

@JsonSerializable()
class GoogleUserOutputPaginatedOutput {
  const GoogleUserOutputPaginatedOutput({
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

  factory GoogleUserOutputPaginatedOutput.fromJson(Map<String, Object?> json) =>
      _$GoogleUserOutputPaginatedOutputFromJson(json);

  final List<String>? messages;
  final List<String>? errors;
  final DateTime? timestamp;
  final bool? success;
  final List<GoogleUserOutput>? data;
  final int? pageNumber;
  final int? pageSize;
  final int? totalItems;
  final int? totalPages;

  Map<String, Object?> toJson() =>
      _$GoogleUserOutputPaginatedOutputToJson(this);
}
