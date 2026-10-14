import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/result/result.dart';
import '../domain/application_credential.dart';
import '../domain/application_credential_repository.dart';

/// How many credentials may be live at once (spec §7; the API's limit,
/// FR-AP-10).
const int maxLiveCredentials = 2;

const Failure _unexpected = Failure(
  kind: FailureKind.unknown,
  errors: <String>['The API returned an unexpected response.'],
);

typedef CredentialsKey = ({String scopeId, String applicationId});

/// What the credentials card shows. It never holds a secret: the secret of a
/// newly issued credential goes to the caller of
/// [ApplicationCredentialsController.issue] and nowhere else.
class CredentialsState {
  const CredentialsState({
    this.credentials,
    this.loadFailure,
    this.busy = false,
    this.actionFailure,
    this.notice,
  });

  /// `null` until the first load answers.
  final List<ApplicationCredential>? credentials;
  final Failure? loadFailure;

  /// An issue or a revoke is in flight.
  final bool busy;

  /// AF-37b…e — the API's refusal of the last issue or revoke.
  final Failure? actionFailure;
  final String? notice;

  int get liveCount =>
      credentials?.where((c) => c.status == CredentialStatus.live).length ?? 0;

  /// At most two may be live (FR-AP-10 in the API); the API decides in the end.
  bool get mayIssue =>
      credentials != null && liveCount < maxLiveCredentials && !busy;

  CredentialsState copyWith({
    List<ApplicationCredential>? credentials,
    Failure? Function()? loadFailure,
    bool? busy,
    Failure? Function()? actionFailure,
    String? Function()? notice,
  }) => CredentialsState(
    credentials: credentials ?? this.credentials,
    loadFailure: loadFailure == null ? this.loadFailure : loadFailure(),
    busy: busy ?? this.busy,
    actionFailure: actionFailure == null ? this.actionFailure : actionFailure(),
    notice: notice == null ? this.notice : notice(),
  );
}

final NotifierProviderFamily<
  ApplicationCredentialsController,
  CredentialsState,
  CredentialsKey
>
applicationCredentialsControllerProvider = NotifierProvider.autoDispose
    .family<ApplicationCredentialsController, CredentialsState, CredentialsKey>(
      ApplicationCredentialsController.new,
    );

/// Owns an application's credentials card (UI-37). The secret of a newly
/// issued credential is handed back to the caller and never kept here.
class ApplicationCredentialsController extends Notifier<CredentialsState> {
  ApplicationCredentialsController(this.arg);

  final CredentialsKey arg;

  ApplicationCredentialRepository get _repository =>
      ref.read(applicationCredentialRepositoryProvider);

  @override
  CredentialsState build() => const CredentialsState();

  Future<void> load() async {
    final result = await _repository.list(arg.scopeId, arg.applicationId);

    // The card may have been left while the request was in flight; an
    // auto-disposed provider must not be written to then.
    if (!ref.mounted) {
      return;
    }

    state = result.fold(
      onSuccess: (credentials) =>
          state.copyWith(credentials: credentials, loadFailure: () => null),
      onFailure: (failure) => state.copyWith(loadFailure: () => failure),
    );
  }

  /// Issues a credential and hands its result back. Answers `null`, calling
  /// nothing, when an issue or a revoke is already in flight: the card ignores
  /// that, since the first call is still showing its outcome.
  Future<Result<IssuedCredential>?> issue({DateTime? expiresAt}) async {
    if (state.busy) {
      return null;
    }

    state = state.copyWith(
      busy: true,
      actionFailure: () => null,
      notice: () => null,
    );
    try {
      final Result<IssuedCredential> result;
      try {
        result = await _repository.issue(
          arg.scopeId,
          arg.applicationId,
          expiresAt: expiresAt,
        );
      } on Exception {
        // E.g. a malformed 2xx body, which the generated client rethrows: the
        // request may have landed, so it is a failure like any other (AF-37g).
        return _unexpectedFailure<IssuedCredential>();
      }

      if (!ref.mounted) {
        return result;
      }

      if (result.failureOrNull case final Failure failure) {
        state = state.copyWith(actionFailure: () => failure);
      }

      // Reloaded either way: on success to show the new row; on AF-37b because
      // somebody else's credential is why it was refused; on a transport
      // failure because the request may have landed (AF-37g).
      await load();

      return result;
    } finally {
      // Busy until the list is fresh, so the button is never offered on a
      // stale list; and always cleared, so the dialog can be closed again.
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
    }
  }

  /// Shows the unexpected failure on the card and answers it.
  FailureResult<T> _unexpectedFailure<T>() {
    if (ref.mounted) {
      state = state.copyWith(actionFailure: () => _unexpected);
    }

    return FailureResult<T>(_unexpected);
  }

  /// Revokes [credential]. Ignored while an issue or a revoke is in flight.
  Future<void> revoke(ApplicationCredential credential) async {
    if (state.busy) {
      return;
    }

    state = state.copyWith(
      busy: true,
      actionFailure: () => null,
      notice: () => null,
    );
    try {
      final Result<void> result;
      try {
        result = await _repository.revoke(
          arg.scopeId,
          arg.applicationId,
          credential.id,
        );
      } on Exception {
        _unexpectedFailure<void>();
        return;
      }

      if (!ref.mounted) {
        return;
      }

      state = result.fold(
        onSuccess: (_) => state.copyWith(notice: () => 'Credential revoked.'),
        onFailure: (failure) => state.copyWith(actionFailure: () => failure),
      );

      await load();
    } finally {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
    }
  }
}
