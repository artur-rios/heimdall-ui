// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/create_scope_permission_command.dart';
import '../models/create_scope_permission_command_output_data_output.dart';
import '../models/delete_scope_permission_command_output_data_output.dart';
import '../models/hard_delete_scope_permission_command_output_data_output.dart';
import '../models/scope_permission_output_data_output.dart';
import '../models/scope_permission_output_paginated_output.dart';
import '../models/update_scope_permission_command.dart';
import '../models/update_scope_permission_command_output_data_output.dart';

part 'scope_permission_client.g.dart';

@RestApi()
abstract class ScopePermissionClient {
  factory ScopePermissionClient(Dio dio, {String? baseUrl}) =
      _ScopePermissionClient;

  /// Creates a scope-specific permission within a scope (UC-31, FR-SP-01/02). Only a System Admin.
  /// or a Scope Admin may call it: the endpoint's `[RoleRequirement]` refuses a `User`,.
  /// who has no standing to manage a scope's permissions. The remaining rules depend on data the.
  /// attribute cannot see and are enforced by the handler — the target scope must exist and be.
  /// active (AF-31a), the input must be well-formed (AF-31d), and an acting Scope Admin must own.
  /// the scope (AF-31e). A scope permission has no owner of its own, so owning the scope is the.
  /// whole of the authorization.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scopes/{scopeId}/permissions')
  Future<CreateScopePermissionCommandOutputDataOutput> scopePermissionCreate({
    @Path('scopeId') required String scopeId,
    @Body() CreateScopePermissionCommand? body,
  });

  /// Lists the permissions of a scope (UC-32, FR-SP-05/09). A System Admin sees every.
  /// permission in the scope; a Scope Admin must own the scope (AF-32e) and then sees every.
  /// permission in it — a scope permission has no owner of its own, so there is no per-owner.
  /// narrowing. Both the ownership gate and the scope lookup are enforced by the handler from.
  /// the acting user; a missing or logically deleted scope reuses AF-31a.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @GET('/api/scopes/{scopeId}/permissions')
  Future<ScopePermissionOutputPaginatedOutput> scopePermissionList({
    @Path('scopeId') required String scopeId,
    @Query('Name') String? name,
    @Query('IncludeDeleted') bool? includeDeleted,
    @Query('PageNumber') int? pageNumber,
    @Query('PageSize') int? pageSize,
  });

  /// Retrieves a single scope permission by its public identifier within the scope (UC-32,.
  /// FR-SP-04/09). A `User` is refused by the attribute; among the remaining actors the.
  /// rule is data-dependent and lives in the handler — a System Admin sees any permission, a.
  /// Scope Admin only one whose scope they own (AF-32e). A permission that does not exist under.
  /// the addressed scope, or that is logically deleted and was not explicitly requested, is.
  /// AF-32a.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @GET('/api/scopes/{scopeId}/permissions/{id}')
  Future<ScopePermissionOutputDataOutput> scopePermissionGetById({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
    @Query('includeDeleted') bool? includeDeleted = false,
  });

  /// Updates a scope permission's name, description, and JWT-claim flag (UC-33, FR-SP-06). A.
  /// `User` is refused by the attribute; among the remaining actors the rule is.
  /// data-dependent and lives in the handler — a System Admin updates any permission, a Scope.
  /// Admin only one whose scope they own (AF-33e). The handler resolves the permission inside.
  /// the addressed scope (AF-33a) and validates the input shape, reusing UC-31's messages.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @PUT('/api/scopes/{scopeId}/permissions/{id}')
  Future<UpdateScopePermissionCommandOutputDataOutput> scopePermissionUpdate({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
    @Body() UpdateScopePermissionCommand? body,
  });

  /// Logically deletes a scope permission by setting `IsDeleted = true` (UC-34, FR-SP-07).
  /// A `User` is refused by the attribute; among the remaining actors the rule is.
  /// data-dependent and lives in the handler — a System Admin deletes any permission, a Scope.
  /// Admin only one whose scope they own (AF-34e). The handler resolves the permission inside.
  /// the addressed scope (AF-34a) and answers an already-deleted permission idempotently.
  /// (AF-34b). Nothing cascades: a scope permission owns no dependent row.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @DELETE('/api/scopes/{scopeId}/permissions/{id}')
  Future<DeleteScopePermissionCommandOutputDataOutput> scopePermissionDelete({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
  });

  /// Permanently (hard) deletes a scope permission, removing the record from the database.
  /// (UC-35, FR-SP-08). Restricted to System Admins: a Scope Admin may logically delete a.
  /// permission in a scope they own (UC-34), but never purge it, so the attribute settles.
  /// authorization on its own and the handler applies no further rule. The handler resolves the.
  /// permission inside the addressed scope in any deletion state and reports AF-35a when it.
  /// does not exist — which includes a repeated call, as the removal leaves nothing to find.
  /// Nothing cascades: the permission's scope is untouched.
  ///
  /// **Requires role:** System Admin.
  @DELETE('/api/scopes/{scopeId}/permissions/{id}/hard')
  Future<HardDeleteScopePermissionCommandOutputDataOutput>
  scopePermissionHardDelete({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
  });
}
