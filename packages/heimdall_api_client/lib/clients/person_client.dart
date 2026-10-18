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
import '../models/person_summary_output_paginated_output.dart';
import '../models/promote_scope_user_command_output_data_output.dart';
import '../models/remove_scope_owner_command_output_data_output.dart';
import '../models/send_person_password_reset_command_output_data_output.dart';
import '../models/send_person_verification_email_command_output_data_output.dart';
import '../models/update_person_command.dart';
import '../models/update_person_command_output_data_output.dart';

part 'person_client.g.dart';

@RestApi()
abstract class PersonClient {
  factory PersonClient(Dio dio, {String? baseUrl}) = _PersonClient;

  /// Creates a `ScopeAdmin` or `SystemAdmin` person with no scope (UC-06 path b).
  /// Restricted to System Admins (AF-06c).
  ///
  /// Derives an Argon2id hash, so it is limited to thirty requests a minute per acting person and.
  /// thirty per address; a rejection answers 429 "Too many requests." with a `Retry-After`.
  /// header.
  ///
  /// **Requires role:** System Admin.
  @POST('/api/persons')
  Future<CreatePersonCommandOutputDataOutput> personCreateAdmin({
    @Body() CreateAdminCommand? body,
  });

  /// Creates a `User` within a scope (UC-06 path a). A System Admin or an owner of the scope.
  /// may call it; the ownership check (AF-06e) is enforced by the handler from the acting user.
  ///
  /// Derives an Argon2id hash, so it is limited to thirty requests a minute per acting person and.
  /// thirty per address; a rejection answers 429 "Too many requests." with a `Retry-After`.
  /// header.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scopes/{scopeId}/persons')
  Future<CreatePersonCommandOutputDataOutput> personCreateUser({
    @Path('scopeId') required String scopeId,
    @Body() CreateUserCommand? body,
  });

  /// Lists the `User` persons of a scope (UC-07, FR-PE-04). A System Admin or an owner of.
  /// the scope may call it; the ownership check (AF-07b) is enforced by the handler from the.
  /// acting user. `ownedScopeIds` is trimmed for a Scope Admin as on.
  /// `GET /api/persons/{id}` (FR-PE-19).
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
  /// Derives an Argon2id hash, so it is limited to thirty requests a minute per acting person and.
  /// thirty per address; a rejection answers 429 "Too many requests." with a `Retry-After`.
  /// header.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scopes/{scopeId}/owners')
  Future<CreatePersonCommandOutputDataOutput> personCreateScopeOwner({
    @Path('scopeId') required String scopeId,
    @Body() CreateScopeOwnerCommand? body,
  });

  /// Lists the owners of a scope (UC-07, FR-PE-04). A System Admin or an.
  /// owner of the scope may call it; the ownership check (AF-07b) is enforced by the handler.
  /// from the acting user. For a Scope Admin each owner's `ownedScopeIds` lists only the.
  /// scopes the caller owns too, this one among them; a System Admin sees them all (FR-PE-19).
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

  /// Adds an existing `ScopeAdmin` or `SystemAdmin` person as an additional owner of a scope.
  /// (UC-21, FR-SC-08/FR-SC-09). A System Admin adds them at once (201, or 200 when they already own.
  /// it). A Scope Admin owning the scope invites them instead (202 "The invitation was sent.", FR-SC-14):.
  /// they own nothing until they accept (UC-60), and a repeat while it is open answers the same and.
  /// mails nothing. The attribute keeps a `User` out; the handler checks the scope (AF-21a), the.
  /// ownership (AF-21c), the person (AF-21b) and an existing ownership (AF-21d).
  ///
  /// It can mail a third party, so it shares the account-creation limit: thirty requests a minute per.
  /// acting person and thirty per address; a rejection answers 429 "Too many requests." with a.
  /// `Retry-After` header.
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
  /// The role is written only while the person is still the `User` the request read.
  /// (#237): when another request changed, promoted or deleted them in the meantime, nothing is.
  /// written and the answer is 409 "Concurrency conflict: the record was modified or removed by.
  /// another process." (AF-23f), or 409 "Conflict: a record with the same unique value already.
  /// exists." when an administrator took the address meanwhile. Read the person again before.
  /// retrying.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scopes/{scopeId}/users/{personId}/promote')
  Future<PromoteScopeUserCommandOutputDataOutput> personPromoteScopeUser({
    @Path('scopeId') required String scopeId,
    @Path('personId') required String personId,
  });

  /// Updates a person's name and email, and — for a System Admin — their role (UC-08). Open to.
  /// any authenticated actor because a User may update their own record; the per-actor rule and.
  /// the role-change restriction (AF-08c) are enforced by the handler. The response's.
  /// `ownedScopeIds` follows FR-PE-19, as `GET /api/persons/{id}` does.
  ///
  /// A caller changing their own email presents `currentPassword`, and `twoFactorCode`.
  /// when their second factor is active (FR-PE-14) — six digits for an authenticator-app code,.
  /// or a recovery code, matched as `2fa/verify` matches one (`XXXX-XXXX-XXXX-XXXX`,.
  /// hyphens, spaces and case ignored, the shorter `XXXX-XXXX` codes still accepted,.
  /// FR-2F-20) — so this action verifies a password like the.
  /// credential endpoints do, and sits under their rate limit (NFR-18), as every.
  /// password-verifying endpoint does. An own email change mails the previous address, so it is.
  /// charged to the person's account-email budget once the credentials are accepted: 429 "An.
  /// email of this kind was sent to you recently. Try again in a few minutes." inside the.
  /// cooldown, 429 "You have reached the limit for account emails. Try again later." once.
  /// the window's five are spent (AF-08j), both with `Retry-After`; nothing changes then, and.
  /// no recovery or email code is spent (an accepted authenticator code's time step is recorded,.
  /// as for any accepted code). While the caller's email sign-in method is enabled, an own.
  /// email change answers 409 "Turn off the email sign-in method before changing your email.
  /// address." (AF-08k), once the credentials are accepted. An address or role change is.
  /// written only while the person still holds the address and role the request read (#237):.
  /// when another request changed or deleted them in the meantime, neither the change nor the.
  /// name is written and the answer is 409 "Concurrency conflict: the record was modified or removed by.
  /// another process." (AF-08l), or 409 "Conflict: a record with the same unique value already.
  /// exists." when the new address was taken meanwhile. As for a failed save, an email change's.
  /// earlier steps stand: the person's tokens are already revoked and their reset and.
  /// verification links retired, and for an own change the account-email budget is charged and.
  /// any recovery or email code presented is spent. Read the person again before retrying.
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
  /// therefore enforced by the handler. `ownedScopeIds` lists every scope the person owns.
  /// for a System Admin and for the person themselves; a Scope Admin reading somebody else sees.
  /// only the scopes they own too (FR-PE-19).
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

  /// Lists the administrators who may own a scope (UC-07 read d, FR-PE-12) — every.
  /// `ScopeAdmin`, and for a System Admin caller every `SystemAdmin` too — projected to.
  /// identifier, name, and email: the source for an owner picker. A System Admin or a Scope.
  /// Admin may call it. Optionally excludes the current owners of a named scope, in which case.
  /// the handler requires the caller to be entitled to manage that scope.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @GET('/api/persons/scope-admins')
  Future<PersonSummaryOutputPaginatedOutput> personListScopeAdmins({
    @Query('Name') String? name,
    @Query('Email') String? email,
    @Query('ExcludeOwnersOfScopeId') String? excludeOwnersOfScopeId,
    @Query('PageNumber') int? pageNumber,
    @Query('PageSize') int? pageSize,
  });

  /// Lists the system's `SystemAdmin` persons (UC-07 read e, FR-PE-13), projected to.
  /// identifier, name, and email: who else holds full access to the deployment. System Admin.
  /// only.
  ///
  /// A Scope Admin is deliberately excluded: a System Admin's address is not tenant-facing,.
  /// which is also why `GET /api/persons/scope-admins` offers System Admins only to a.
  /// System Admin caller.
  ///
  /// **Requires role:** System Admin.
  @GET('/api/persons/system-admins')
  Future<PersonSummaryOutputPaginatedOutput> personListSystemAdmins({
    @Query('Name') String? name,
    @Query('Email') String? email,
    @Query('PageNumber') int? pageNumber,
    @Query('PageSize') int? pageSize,
  });

  /// Has a fresh verification link mailed to a person's own address (UC-51, FR-EV-06): outstanding.
  /// links are retired first, as UC-15 does, and the link uses the scope's verification URL. A.
  /// System Admin may ask for any person; a Scope Admin only for a `User` of a scope they own.
  /// (AF-51b). No body; the token is never returned.
  ///
  /// Refused when the person is deleted or restricted (409, AF-51c) or already verified (400,.
  /// AF-51d), and with 429 when an email of this kind went to them within the cooldown,.
  /// `HEIMDALL_ADMIN_EMAIL_COOLDOWN_IN_SECONDS` (five minutes by default, AF-51e). 200 means.
  /// the email was handed to the sender.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/persons/{id}/verification-email')
  Future<SendPersonVerificationEmailCommandOutputDataOutput>
  personSendVerificationEmail({@Path('id') required String id});

  /// Has a password-reset link mailed to a person's own address (UC-52, FR-PR-05). A System Admin.
  /// may ask for any person; a Scope Admin only for a `User` of a scope they own (AF-52b). No.
  /// body; neither a token nor a password is accepted or returned.
  ///
  /// Eligibility is UC-12's: refused (409) when the person is deleted or restricted (AF-52c) or.
  /// their account could not sign in — a User whose scope is deleted, a Scope Admin with no live.
  /// scope (AF-52d). 429 when a reset went to them within the cooldown (AF-52e). Unlike UC-12 the.
  /// send is not queued: the caller is authenticated and owed a real answer. 200 means the email.
  /// was handed to the sender.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/persons/{id}/password-reset')
  Future<SendPersonPasswordResetCommandOutputDataOutput>
  personSendPasswordReset({@Path('id') required String id});
}
