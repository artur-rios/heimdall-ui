// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/create_scope_command.dart';
import '../models/create_scope_command_output_data_output.dart';
import '../models/delete_scope_command_output_data_output.dart';
import '../models/hard_delete_scope_command_output_data_output.dart';
import '../models/scope_output_data_output.dart';
import '../models/scope_output_paginated_output.dart';
import '../models/set_google_sign_in_command.dart';
import '../models/set_google_sign_in_command_output_data_output.dart';
import '../models/update_scope_command.dart';
import '../models/update_scope_command_output_data_output.dart';

part 'scope_client.g.dart';

@RestApi()
abstract class ScopeClient {
  factory ScopeClient(Dio dio, {String? baseUrl}) = _ScopeClient;

  /// Creates a new scope with one or more initial owners (UC-01). Restricted to System Admins.
  ///
  /// **Requires role:** System Admin.
  @POST('/api/scopes')
  Future<CreateScopeCommandOutputDataOutput> scopeCreate({
    @Body() CreateScopeCommand? body,
  });

  /// Lists scopes with pagination and optional filtering (UC-02). Restricted to System Admins.
  ///
  /// **Requires role:** System Admin.
  @GET('/api/scopes')
  Future<ScopeOutputPaginatedOutput> scopeList({
    @Query('Name') String? name,
    @Query('IncludeDeleted') bool? includeDeleted,
    @Query('PageNumber') int? pageNumber,
    @Query('PageSize') int? pageSize,
  });

  /// Updates an existing scope's name and description (UC-03). Restricted to System Admins.
  ///
  /// **Requires role:** System Admin.
  @PUT('/api/scopes/{id}')
  Future<UpdateScopeCommandOutputDataOutput> scopeUpdate({
    @Path('id') required String id,
    @Body() UpdateScopeCommand? body,
  });

  /// Logically deletes a scope, cascading to its Users, Google Users, and applications (UC-04).
  /// Restricted to System Admins.
  ///
  /// **Requires role:** System Admin.
  @DELETE('/api/scopes/{id}')
  Future<DeleteScopeCommandOutputDataOutput> scopeDelete({
    @Path('id') required String id,
  });

  /// Retrieves a single scope by its public identifier (UC-02). Open to any authenticated actor.
  /// because a Scope Admin reads the scopes they own and a User the scope they belong to; that.
  /// per-actor visibility rule (AF-02b) is data-dependent and is therefore enforced by the.
  /// handler.
  ///
  /// **Any authenticated caller** — the handler decides who may act, so no role is required at the door.
  @GET('/api/scopes/{id}')
  Future<ScopeOutputDataOutput> scopeGetById({
    @Path('id') required String id,
    @Query('includeDeleted') bool? includeDeleted = false,
  });

  /// Permanently (hard) deletes a scope, removing its Users, Google Users, applications,.
  /// scope permissions, and ownership/membership join rows (UC-05). Restricted to System.
  /// Admins.
  ///
  /// **Requires role:** System Admin.
  @DELETE('/api/scopes/{id}/hard')
  Future<HardDeleteScopeCommandOutputDataOutput> scopeHardDelete({
    @Path('id') required String id,
  });

  /// Turns Google Sign-In on or off for a scope (UC-24, FR-GO-01/FR-GO-02). The attribute keeps.
  /// a `User` out — they can never be a System Admin nor an existing owner — while the.
  /// rules that depend on data it cannot see are the handler's: whether the acting Scope Admin.
  /// owns this scope (AF-24b) and whether the scope is active (AF-24a).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @PUT('/api/scopes/{id}/google-signin')
  Future<SetGoogleSignInCommandOutputDataOutput> scopeSetGoogleSignIn({
    @Path('id') required String id,
    @Body() SetGoogleSignInCommand? body,
  });
}
