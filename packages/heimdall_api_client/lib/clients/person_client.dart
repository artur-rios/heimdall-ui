// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/add_scope_owner_command_output_data_output.dart';
import '../models/create_admin_command.dart';
import '../models/create_person_command_output_data_output.dart';
import '../models/create_scope_owner_command.dart';
import '../models/create_user_command.dart';
import '../models/delete_person_command_output_data_output.dart';
import '../models/hard_delete_person_command_output_data_output.dart';
import '../models/person_output_data_output.dart';
import '../models/person_output_paginated_output.dart';
import '../models/promote_scope_user_command_output_data_output.dart';
import '../models/remove_scope_owner_command_output_data_output.dart';
import '../models/update_person_command.dart';
import '../models/update_person_command_output_data_output.dart';

part 'person_client.g.dart';

@RestApi()
abstract class PersonClient {
  factory PersonClient(Dio dio, {String? baseUrl}) = _PersonClient;

  /// Creates a `ScopeAdmin` or `SystemAdmin` person with no scope (UC-06 path b).
  /// Restricted to System Admins (AF-06c).
  ///
  /// **Requires role:** System Admin.
  @POST('/api/persons')
  Future<CreatePersonCommandOutputDataOutput> personCreateAdmin({
    @Body() CreateAdminCommand? body,
  });

  /// Creates a `User` within a scope (UC-06 path a). A System Admin or an owner of the scope.
  /// may call it; the ownership check (AF-06e) is enforced by the handler from the acting user.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scopes/{scopeId}/persons')
  Future<CreatePersonCommandOutputDataOutput> personCreateUser({
    @Path('scopeId') required String scopeId,
    @Body() CreateUserCommand? body,
  });

  /// Lists the `User` persons of a scope (UC-07, FR-PE-04). A System Admin or an owner of.
  /// the scope may call it; the ownership check (AF-07b) is enforced by the handler from the.
  /// acting user.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @GET('/api/scopes/{scopeId}/persons')
  Future<PersonOutputPaginatedOutput> personListScopePersons({
    @Path('scopeId') required String scopeId,
    @Query('Name') String? name,
    @Query('Email') String? email,
    @Query('IncludeDeleted') bool? includeDeleted,
    @Query('PageNumber') int? pageNumber,
    @Query('PageSize') int? pageSize,
  });

  /// Creates a brand-new `ScopeAdmin` person directly as a co-owner of a scope (UC-06 path.
  /// c, FR-SC-12). A System Admin or an owner of the scope may call it; the ownership check.
  /// (AF-06e) is enforced by the handler from the acting user.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scopes/{scopeId}/owners')
  Future<CreatePersonCommandOutputDataOutput> personCreateScopeOwner({
    @Path('scopeId') required String scopeId,
    @Body() CreateScopeOwnerCommand? body,
  });

  /// Lists the `ScopeAdmin` owners of a scope (UC-07, FR-PE-04). A System Admin or an.
  /// owner of the scope may call it; the ownership check (AF-07b) is enforced by the handler.
  /// from the acting user.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @GET('/api/scopes/{scopeId}/owners')
  Future<PersonOutputPaginatedOutput> personListScopeOwners({
    @Path('scopeId') required String scopeId,
    @Query('Name') String? name,
    @Query('Email') String? email,
    @Query('IncludeDeleted') bool? includeDeleted,
    @Query('PageNumber') int? pageNumber,
    @Query('PageSize') int? pageSize,
  });

  /// Adds an existing `ScopeAdmin` person as an additional owner of a scope (UC-21,.
  /// FR-SC-08/FR-SC-09). The attribute keeps a `User` out — they can never be a System.
  /// Admin nor an existing owner — while the rules that depend on data it cannot see are the.
  /// handler's: whether the acting Scope Admin owns this scope (AF-21c), whether the scope is.
  /// active (AF-21a), whether the named person is a usable `ScopeAdmin` (AF-21b), and.
  /// whether they already own it (AF-21d).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scopes/{scopeId}/owners/{personId}')
  Future<AddScopeOwnerCommandOutputDataOutput> personAddScopeOwner({
    @Path('scopeId') required String scopeId,
    @Path('personId') required String personId,
  });

  /// Removes a person's ownership of a scope (UC-22, FR-SC-08/FR-SC-10). The attribute keeps a.
  /// `User` out — they can never be a System Admin nor an existing owner — while the rules.
  /// that depend on data it cannot see are the handler's: whether the acting Scope Admin owns.
  /// this scope (AF-22c), whether the scope is active and the named person actually owns it.
  /// (AF-22a), and whether the scope would be left without an owner (AF-22b, NFR-12).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @DELETE('/api/scopes/{scopeId}/owners/{personId}')
  Future<RemoveScopeOwnerCommandOutputDataOutput> personRemoveScopeOwner({
    @Path('scopeId') required String scopeId,
    @Path('personId') required String personId,
  });

  /// Promotes an existing `User` of a scope to `ScopeAdmin`, making them a co-owner of.
  /// that scope (UC-23, FR-SC-08/FR-SC-13/FR-RO-03). The attribute keeps a `User` out —.
  /// they can never be a System Admin nor an existing owner — while the rules that depend on.
  /// data it cannot see are the handler's: whether the acting Scope Admin owns this scope.
  /// (AF-23c), whether the scope is active (AF-23a), whether the named person is a `User`.
  /// of it (AF-23b), and whether they already hold the role (AF-23d).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scopes/{scopeId}/users/{personId}/promote')
  Future<PromoteScopeUserCommandOutputDataOutput> personPromoteScopeUser({
    @Path('scopeId') required String scopeId,
    @Path('personId') required String personId,
  });

  /// Updates a person's name and email, and — for a System Admin — their role (UC-08). Open to.
  /// any authenticated actor because a User may update their own record; the per-actor rule and.
  /// the role-change restriction (AF-08c) are enforced by the handler.
  ///
  /// **Any authenticated caller** — the handler decides who may act, so no role is required at the door.
  @PUT('/api/persons/{id}')
  Future<UpdatePersonCommandOutputDataOutput> personUpdate({
    @Path('id') required String id,
    @Body() UpdatePersonCommand? body,
  });

  /// Logically deletes a person by setting `IsDeleted = true` (UC-09, FR-PE-06). The.
  /// attribute keeps a plain `User` out; the owner rule (AF-09c) is data-dependent and is.
  /// therefore enforced by the handler, as are the self-deletion (AF-09d) and last-owner.
  /// (AF-09e) refusals.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @DELETE('/api/persons/{id}')
  Future<DeletePersonCommandOutputDataOutput> personDelete({
    @Path('id') required String id,
  });

  /// Retrieves a single person by their public identifier (UC-07, FR-PE-03). Open to any.
  /// authenticated actor; the per-actor visibility rule (AF-07b) is data-dependent and is.
  /// therefore enforced by the handler.
  ///
  /// **Any authenticated caller** — the handler decides who may act, so no role is required at the door.
  @GET('/api/persons/{id}')
  Future<PersonOutputDataOutput> personGetById({
    @Path('id') required String id,
    @Query('includeDeleted') bool? includeDeleted = false,
  });

  /// Permanently (hard) deletes a person, removing the applications they own, their password.
  /// reset and email verification tokens, and their scope membership/ownership rows (UC-10,.
  /// FR-PE-07). Restricted to System Admins; the self-deletion refusal (AF-10c) and the.
  /// last-owner guard (AF-10b) are enforced by the handler.
  ///
  /// **Requires role:** System Admin.
  @DELETE('/api/persons/{id}/hard')
  Future<HardDeletePersonCommandOutputDataOutput> personHardDelete({
    @Path('id') required String id,
  });
}
