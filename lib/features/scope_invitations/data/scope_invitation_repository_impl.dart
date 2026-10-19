import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/scope_invitation.dart';
import '../domain/scope_invitation_repository.dart';

/// [ScopeInvitationRepository] over the generated client.
class ApiScopeInvitationRepository implements ScopeInvitationRepository {
  const ApiScopeInvitationRepository(this._client);

  final ScopeInvitationClient _client;

  @override
  Future<Result<Page<OwnerInvitation>>> listForScope(
    String scopeId, {
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await _client.scopeInvitationListForScope(
        scopeId: scopeId,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      if (response.success != true) {
        return FailureResult<Page<OwnerInvitation>>(_refusal(response.errors));
      }

      final items = (response.data ?? const <ScopeOwnerInvitationOutput>[])
          .map(_ownerInvitationFrom)
          .toList(growable: false);

      return Success<Page<OwnerInvitation>>(
        Page<OwnerInvitation>(
          items: items,
          pageNumber: response.pageNumber ?? pageNumber,
          pageSize: response.pageSize ?? pageSize,
          totalItems: response.totalItems ?? items.length,
          totalPages: response.totalPages ?? 1,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Page<OwnerInvitation>>(
        failureFromDioException(error),
      );
    }
  }

  @override
  Future<Result<void>> withdraw(String scopeId, String invitationId) async {
    try {
      // 204 with no body: reaching here is the success.
      await _client.scopeInvitationWithdraw(
        scopeId: scopeId,
        invitationId: invitationId,
      );

      return const Success<void>(null);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Page<ScopeInvitation>>> listMine({
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await _client.scopeInvitationListMine(
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      if (response.success != true) {
        return FailureResult<Page<ScopeInvitation>>(_refusal(response.errors));
      }

      final items = (response.data ?? const <MyScopeInvitationOutput>[])
          .map(_scopeInvitationFrom)
          .toList(growable: false);

      return Success<Page<ScopeInvitation>>(
        Page<ScopeInvitation>(
          items: items,
          pageNumber: response.pageNumber ?? pageNumber,
          pageSize: response.pageSize ?? pageSize,
          totalItems: response.totalItems ?? items.length,
          totalPages: response.totalPages ?? 1,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Page<ScopeInvitation>>(
        failureFromDioException(error),
      );
    }
  }

  @override
  Future<Result<void>> accept(String invitationId) async {
    try {
      final response = await _client.scopeInvitationAccept(
        invitationId: invitationId,
      );

      return response.success == true
          ? const Success<void>(null)
          : FailureResult<void>(_refusal(response.errors));
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> decline(String invitationId) async {
    try {
      final response = await _client.scopeInvitationDecline(
        invitationId: invitationId,
      );

      return response.success == true
          ? const Success<void>(null)
          : FailureResult<void>(_refusal(response.errors));
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }
}

Failure _refusal(List<String>? errors) =>
    Failure(kind: FailureKind.validation, errors: errors ?? const <String>[]);

OwnerInvitation _ownerInvitationFrom(ScopeOwnerInvitationOutput o) =>
    OwnerInvitation(
      id: o.id ?? '',
      inviteeId: o.inviteeId ?? '',
      inviteeName: o.inviteeName ?? '',
      inviteeEmail: o.inviteeEmail ?? '',
      invitedByName: o.invitedByName,
      createdAt: o.createdAt,
      expiresAt: o.expiresAt,
    );

ScopeInvitation _scopeInvitationFrom(MyScopeInvitationOutput o) =>
    ScopeInvitation(
      id: o.id ?? '',
      scopeId: o.scopeId ?? '',
      scopeName: o.scopeName ?? '',
      invitedByName: o.invitedByName,
      createdAt: o.createdAt,
      expiresAt: o.expiresAt,
    );
