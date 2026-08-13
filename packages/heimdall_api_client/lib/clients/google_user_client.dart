// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/delete_google_user_command_output_data_output.dart';
import '../models/google_user_output_data_output.dart';
import '../models/google_user_output_paginated_output.dart';
import '../models/hard_delete_google_user_command_output_data_output.dart';

part 'google_user_client.g.dart';

@RestApi()
abstract class GoogleUserClient {
  factory GoogleUserClient(Dio dio, {String? baseUrl}) = _GoogleUserClient;

  /// Lists the Google Users of a scope, with pagination and optional name/email filters (UC-27,.
  /// FR-GO-14). A System Admin or an owner of the scope may call it; the ownership check.
  /// (AF-27b) is enforced by the handler from the acting caller.
  ///
  /// Unlike M:ArturRios.Heimdall.WebApi.Controllers.GoogleUserController.GetById(System.Guid,System.Guid,System.Boolean) this does carry a `RoleRequirement`: the authorization.
  /// matrix grants a Google User a read of themselves, never a listing, so every `User` is.
  /// refused here before the handler runs.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @GET('/api/scopes/{scopeId}/google-users')
  Future<GoogleUserOutputPaginatedOutput> googleUserList({
    @Path('scopeId') required String scopeId,
    @Query('Name') String? name,
    @Query('Email') String? email,
    @Query('IncludeDeleted') bool? includeDeleted,
    @Query('PageNumber') int? pageNumber,
    @Query('PageSize') int? pageSize,
  });

  /// Retrieves a single Google User by its public identifier within a scope (UC-27, FR-GO-14).
  ///
  /// Open to any authenticated actor, deliberately. UC-27 names a Google User as one of its.
  /// three actors — they may read their own record — and a Google User's token carries the.
  /// `User` role (FR-GO-04), so any attribute strong enough to keep other Users out would.
  /// lock out the actor the use case grants. The per-actor rule (AF-27b) is data-dependent and.
  /// is therefore the handler's, as UC-07's by-id read is.
  ///
  /// **Any authenticated caller** — the handler decides who may act, so no role is required at the door.
  @GET('/api/scopes/{scopeId}/google-users/{id}')
  Future<GoogleUserOutputDataOutput> googleUserGetById({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
    @Query('includeDeleted') bool? includeDeleted = false,
  });

  /// Logically deletes a Google User by setting `IsDeleted = true` (UC-28, FR-GO-15). The.
  /// attribute keeps every `User` out — the authorization matrix withholds this from them,.
  /// Google or password alike — while the rule that depends on data it cannot see is the.
  /// handler's: whether the acting Scope Admin owns the Google User's scope (AF-28c).
  ///
  /// Unlike M:ArturRios.Heimdall.WebApi.Controllers.GoogleUserController.GetById(System.Guid,System.Guid,System.Boolean) there is no actor a role attribute would wrongly exclude.
  /// here, which is why this one carries the attribute the by-id read cannot.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @DELETE('/api/scopes/{scopeId}/google-users/{id}')
  Future<DeleteGoogleUserCommandOutputDataOutput> googleUserDelete({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
  });

  /// Permanently (hard) deletes a Google User, removing the record for good (UC-29, FR-GO-16).
  /// Restricted to System Admins — the authorization matrix withholds this even from an owning.
  /// Scope Admin, who may only delete logically (UC-28).
  ///
  /// The one Google User endpoint where the attribute is the whole authorization rule: UC-29.
  /// names a single actor and nothing about the decision depends on data, so the handler applies.
  /// none and the command carries no acting person. Nothing cascades either — a Google User owns.
  /// no dependent row.
  ///
  /// **Requires role:** System Admin.
  @DELETE('/api/scopes/{scopeId}/google-users/{id}/hard')
  Future<HardDeleteGoogleUserCommandOutputDataOutput> googleUserHardDelete({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
  });
}
