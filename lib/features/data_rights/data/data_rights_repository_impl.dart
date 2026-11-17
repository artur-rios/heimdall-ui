import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:heimdall_api_client/api.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/data_rights.dart';
import '../domain/data_rights_repository.dart';

/// [DataRightsRepository] over the generated client.
///
/// The endpoints live on the API's auth controller, so this wraps the same
/// [AuthClient] the session does, over [_transport], the [Dio] it was built
/// on.
class ApiDataRightsRepository implements DataRightsRepository {
  const ApiDataRightsRepository(this._client, this._transport);

  final AuthClient _client;
  final Dio _transport;

  /// The export is asked for on [_transport] rather than through
  /// [AuthClient.authExportMyData], whose model only gives back what it
  /// declares and drops every `null` when written out again: the file must be
  /// the document the API sent, `"x": null` keys included (UI-30). The model
  /// still reads the answer, so one it refuses fails here as any other
  /// unreadable answer does.
  @override
  Future<Result<DataExport>> exportMyData() async {
    try {
      // Decoded as the generated client decodes it, refusals included, but
      // kept whole.
      final answer = await _transport.post<Object?>(
        '/api/auth/data-export',
        options: Options(
          headers: const <String, Object>{'Accept': 'application/json'},
        ),
      );
      final json = answer.data as Map<String, dynamic>;
      final response = DataExportCommandOutputDataOutput$Response.fromJson(
        json,
      );

      if (response.success != true) {
        return FailureResult<DataExport>(_rejected(response.errors));
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<DataExport>(_incompleteResponse);
      }

      return Success<DataExport>(
        DataExport(
          document: const JsonEncoder.withIndent('  ').convert(json['data']),
          exportedAt: data.exportedAt,
        ),
      );
    } catch (error, stackTrace) {
      return FailureResult<DataExport>(failureFromRequest(error, stackTrace));
    }
  }

  @override
  Future<Result<ErasureRequest>> requestErasure(
    ErasureCredential credential,
  ) async {
    try {
      final response = await _client.authRequestErasure(
        body: switch (credential) {
          PasswordCredential(:final password) => RequestErasureCommand(
            password: password,
          ),
          GoogleIdTokenCredential(:final idToken) => RequestErasureCommand(
            idToken: idToken,
          ),
        },
      );

      if (response.success != true) {
        return FailureResult<ErasureRequest>(_rejected(response.errors));
      }

      final data = response.data;

      return Success<ErasureRequest>(
        ErasureRequest(
          requestedAt: data?.requestedAt,
          dueAt: data?.dueAt,
          // AF-42d answers successfully: the request is recorded whether or
          // not something blocks it, which is the point of answering 200.
          blocked: data?.blocked ?? false,
          blockedReason: data?.blockedReason,
        ),
      );
    } catch (error, stackTrace) {
      // AF-42a's wrong credential arrives as a 401 the envelope helpers read
      // as a rejected input, not a rejected session — so it is shown, and the
      // person stays signed in to try again.
      return FailureResult<ErasureRequest>(
        failureFromRequest(error, stackTrace),
      );
    }
  }

  @override
  Future<Result<void>> restrictProcessing(RestrictionGround ground) async {
    try {
      // The body carries the ground and nothing else: the API reads the
      // subject from the bearer token.
      final response = await _client.authRestrictProcessing(
        body: RestrictProcessingCommand(ground: _groundNumber(ground)),
      );

      if (response.success != true) {
        return FailureResult<void>(_rejected(response.errors));
      }

      return const Success<void>(null);
    } catch (error, stackTrace) {
      // AF-44a's 409 arrives here, read by the envelope helpers as a conflict
      // with the API's own words.
      return FailureResult<void>(failureFromRequest(error, stackTrace));
    }
  }

  /// The API's numbers for the grounds of GDPR Art. 18(1), in its order.
  static int _groundNumber(RestrictionGround ground) => switch (ground) {
    RestrictionGround.accuracyContested => 1,
    RestrictionGround.unlawfulButErasureOpposed => 2,
    RestrictionGround.neededForLegalClaim => 3,
    RestrictionGround.objectionPending => 4,
  };

  @override
  Future<Result<void>> liftOwnRestriction() async {
    try {
      // An empty body names nobody, which the API reads as the caller.
      final response = await _client.authLiftProcessingRestriction(
        body: const LiftProcessingRestrictionCommand(),
      );

      if (response.success != true) {
        return FailureResult<void>(_rejected(response.errors));
      }

      return const Success<void>(null);
    } catch (error, stackTrace) {
      return FailureResult<void>(failureFromRequest(error, stackTrace));
    }
  }

  static Failure _rejected(List<String>? errors) =>
      Failure(kind: FailureKind.validation, errors: errors ?? const <String>[]);
}

/// A successful envelope that nonetheless lacks what the flow needs.
const Failure _incompleteResponse = Failure(
  kind: FailureKind.unknown,
  errors: <String>['The API returned an incomplete response.'],
);
