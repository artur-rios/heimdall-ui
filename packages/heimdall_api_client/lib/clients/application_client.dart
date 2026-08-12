// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/application_output_data_output.dart';
import '../models/application_output_paginated_output.dart';
import '../models/create_application_command.dart';
import '../models/create_application_command_output_data_output.dart';
import '../models/delete_application_command_output_data_output.dart';
import '../models/hard_delete_application_command_output_data_output.dart';
import '../models/update_application_command.dart';
import '../models/update_application_command_output_data_output.dart';

part 'application_client.g.dart';

@RestApi()
abstract class ApplicationClient {
  factory ApplicationClient(Dio dio, {String? baseUrl}) = _ApplicationClient;

  /// Registers an application within a scope (UC-16, FR-AP-01/02/03). Only a System Admin or a.
  /// Scope Admin may call it: FR-AP-03 restricts ownership to a `ScopeAdmin` who owns the.
  /// scope, so a `User` has nothing to create here and the attribute refuses them. The.
  /// remaining rules depend on data the attribute cannot see and are enforced by the handler —.
  /// the acting Scope Admin must own the scope (AF-16e) and may only name themself (AF-16c),.
  /// and the named owner must satisfy FR-AP-03 (AF-16b).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scopes/{scopeId}/applications')
  Future<CreateApplicationCommandOutputDataOutput> applicationCreate({
    @Path('scopeId') required String scopeId,
    @Body() CreateApplicationCommand? body,
  });

  /// Lists the applications of a scope (UC-17, FR-AP-05/09). A System Admin sees every.
  /// application in the scope; a Scope Admin must own the scope (AF-17b) and sees only the.
  /// applications they own. Both narrowings are enforced by the handler from the acting user.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @GET('/api/scopes/{scopeId}/applications')
  Future<ApplicationOutputPaginatedOutput> applicationList({
    @Path('scopeId') required String scopeId,
    @Query('ScopeId') String? scopeIdFilter,
    @Query('Name') String? name,
    @Query('OwnerId') String? ownerId,
    @Query('IncludeDeleted') bool? includeDeleted,
    @Query('ActingPersonId') String? actingPersonId,
    @Query('ActingRole') int? actingRole,
    @Query('PageNumber') int? pageNumber,
    @Query('PageSize') int? pageSize,
  });

  /// Retrieves a single application by its public identifier within the scope (UC-17,.
  /// FR-AP-04/09). A `User` can own no application (FR-AP-03) and so is refused by the.
  /// attribute; among the remaining actors the rule is data-dependent and lives in the handler —.
  /// a System Admin sees any application, a Scope Admin only the ones they own (AF-17b).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @GET('/api/scopes/{scopeId}/applications/{id}')
  Future<ApplicationOutputDataOutput> applicationGetById({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
    @Query('includeDeleted') bool? includeDeleted = false,
  });

  /// Updates an application's name and owner (UC-18, FR-AP-06). A `User` can own no.
  /// application (FR-AP-03) and so is refused by the attribute; among the remaining actors the.
  /// rule is data-dependent and lives in the handler — a System Admin updates any application, a.
  /// Scope Admin only the ones they own (AF-18c). The handler also resolves the application.
  /// inside the addressed scope (AF-18a) and, when the owner changes, checks the new owner.
  /// against FR-AP-03 (AF-18b).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @PUT('/api/scopes/{scopeId}/applications/{id}')
  Future<UpdateApplicationCommandOutputDataOutput> applicationUpdate({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
    @Body() UpdateApplicationCommand? body,
  });

  /// Logically deletes an application by setting `IsDeleted = true` (UC-19, FR-AP-07). A.
  /// `User` can own no application (FR-AP-03) and so is refused by the attribute; among the.
  /// remaining actors the rule is data-dependent and lives in the handler — a System Admin.
  /// deletes any application, a Scope Admin only the ones they own (AF-19c). The handler also.
  /// resolves the application inside the addressed scope (AF-19a) and answers an already-deleted.
  /// application idempotently (AF-19b).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @DELETE('/api/scopes/{scopeId}/applications/{id}')
  Future<DeleteApplicationCommandOutputDataOutput> applicationDelete({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
  });

  /// Permanently (hard) deletes an application, removing the record from the database (UC-20,.
  /// FR-AP-08). Restricted to System Admins: a Scope Admin may logically delete an application.
  /// they own (UC-19), but never purge it, so the attribute settles authorization on its own and.
  /// the handler applies no further rule. The handler resolves the application inside the.
  /// addressed scope in any deletion state and reports AF-20a when it does not exist — which.
  /// includes a repeated call, as the removal leaves nothing to find. Nothing cascades: the.
  /// application's scope and owner are untouched.
  ///
  /// **Requires role:** System Admin.
  @DELETE('/api/scopes/{scopeId}/applications/{id}/hard')
  Future<HardDeleteApplicationCommandOutputDataOutput> applicationHardDelete({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
  });
}
