// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/accept_scope_owner_invitation_command_output_data_output.dart';
import '../models/decline_scope_owner_invitation_command_output_data_output.dart';
import '../models/my_scope_invitation_output_paginated_output.dart';
import '../models/scope_owner_invitation_output_paginated_output.dart';

part 'scope_invitation_client.g.dart';

@RestApi()
abstract class ScopeInvitationClient {
  factory ScopeInvitationClient(Dio dio, {String? baseUrl}) =
      _ScopeInvitationClient;

  /// Lists the scope's open owner invitations (UC-58, FR-SC-15), newest first: each one's id, the invitee's.
  /// id, name and address, the inviter's name, and when it was made and expires. A System Admin or an.
  /// owner of the scope may call it; the attribute keeps a `User` out, and the handler checks the.
  /// scope (AF-58a) and the ownership (AF-58b).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @GET('/api/scopes/{scopeId}/owner-invitations')
  Future<ScopeOwnerInvitationOutputPaginatedOutput>
  scopeInvitationListForScope({
    @Path('scopeId') required String scopeId,
    @Query('PageNumber') int? pageNumber,
    @Query('PageSize') int? pageSize,
  });

  /// Withdraws an open owner invitation of the scope (UC-58, FR-SC-15): 204 with no body. An ended,.
  /// expired or unknown invitation, or another scope's, answers 404 "The invitation was not found or is.
  /// no longer open." (AF-58c). Same actors as the listing.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @DELETE('/api/scopes/{scopeId}/owner-invitations/{invitationId}')
  Future<void> scopeInvitationWithdraw({
    @Path('scopeId') required String scopeId,
    @Path('invitationId') required String invitationId,
  });

  /// Lists the caller's own open scope owner invitations (UC-59, FR-SC-16), soonest to expire first: each.
  /// one's id, the scope's id and name, the inviter's name, and when it was made and expires. Any signed-in.
  /// Scope Admin or System Admin may call it; a `User` cannot be invited, so the attribute keeps them.
  /// out.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @GET('/api/persons/me/scope-invitations')
  Future<MyScopeInvitationOutputPaginatedOutput> scopeInvitationListMine({
    @Query('PageNumber') int? pageNumber,
    @Query('PageSize') int? pageSize,
  });

  /// Accepts a scope owner invitation (UC-60, FR-SC-17): the invitation ends as accepted and the caller.
  /// becomes an owner of the scope, together. Only the invitee may; everybody else, and an ended or expired.
  /// invitation, gets 404 "The invitation was not found or is no longer open." (AF-60a). An invitation whose.
  /// scope was deleted, or whose invitee is no longer an unrestricted administrator, is voided and answered.
  /// the same (AF-60b).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scope-invitations/{invitationId}/accept')
  Future<AcceptScopeOwnerInvitationCommandOutputDataOutput>
  scopeInvitationAccept({@Path('invitationId') required String invitationId});

  /// Declines a scope owner invitation (UC-61, FR-SC-17). Same caller and refusals as UC-60 (AF-61a).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scope-invitations/{invitationId}/decline')
  Future<DeclineScopeOwnerInvitationCommandOutputDataOutput>
  scopeInvitationDecline({@Path('invitationId') required String invitationId});
}
