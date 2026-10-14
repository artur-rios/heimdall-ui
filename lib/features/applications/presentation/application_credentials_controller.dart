import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/result/result.dart';
import '../domain/application_credential.dart';
import '../domain/application_credential_repository.dart';

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

  /// At most two may be live (FR-AP-11 in the API); the API decides in the end.
  bool get mayIssue => credentials != null && liveCount < 2 && !busy;

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

  Future<Result<IssuedCredential>> issue({DateTime? expiresAt}) async {
    state = state.copyWith(
      busy: true,
      actionFailure: () => null,
      notice: () => null,
    );
    final result = await _repository.issue(
      arg.scopeId,
      arg.applicationId,
      expiresAt: expiresAt,
    );

    if (!ref.mounted) {
      return result;
    }

    if (result.failureOrNull case final Failure failure) {
      state = state.copyWith(busy: false, actionFailure: () => failure);
    } else {
      state = state.copyWith(busy: false);
    }

    // Reloaded either way: on success to show the new row; on AF-37b because
    // somebody else's credential is why it was refused; on a transport failure
    // because the request may have landed (AF-37g).
    await load();

    return result;
  }

  Future<void> revoke(ApplicationCredential credential) async {
    state = state.copyWith(
      busy: true,
      actionFailure: () => null,
      notice: () => null,
    );
    final result = await _repository.revoke(
      arg.scopeId,
      arg.applicationId,
      credential.id,
    );

    if (!ref.mounted) {
      return;
    }

    state = result.fold(
      onSuccess: (_) =>
          state.copyWith(busy: false, notice: () => 'Credential revoked.'),
      onFailure: (failure) =>
          state.copyWith(busy: false, actionFailure: () => failure),
    );

    await load();
  }
}
