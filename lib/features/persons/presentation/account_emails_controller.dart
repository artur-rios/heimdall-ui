import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/result/result.dart';
import '../../profile/presentation/profile_controller.dart';

/// The two emails an administrator may have sent to a person (UC-51, UC-52).
enum AccountEmail { verification, passwordReset }

class AccountEmailsState {
  const AccountEmailsState({this.sending, this.sent, this.failure});

  /// The email being sent now; both actions are disabled meanwhile.
  final AccountEmail? sending;

  /// The email last handed to the sender.
  final AccountEmail? sent;

  /// AF-36a…d — the API's refusal of the last attempt.
  final Failure? failure;
}

final NotifierProviderFamily<
  AccountEmailsController,
  AccountEmailsState,
  String
>
accountEmailsControllerProvider =
    NotifierProvider.family<
      AccountEmailsController,
      AccountEmailsState,
      String
    >(AccountEmailsController.new);

/// Sends a person's account emails for an administrator (UI-36).
class AccountEmailsController extends Notifier<AccountEmailsState> {
  AccountEmailsController(this.arg);

  /// The person's id.
  final String arg;

  @override
  AccountEmailsState build() => const AccountEmailsState();

  /// `true` when the email was handed to the sender. A second request while
  /// one is in flight is ignored rather than queued.
  Future<bool> send(AccountEmail kind) async {
    if (state.sending != null) {
      return false;
    }

    state = AccountEmailsState(sending: kind);
    final repository = ref.read(personRepositoryProvider);
    final result = await switch (kind) {
      AccountEmail.verification => repository.sendVerificationEmail(arg),
      AccountEmail.passwordReset => repository.sendPasswordReset(arg),
    };

    state = result.fold(
      onSuccess: (_) => AccountEmailsState(sent: kind),
      onFailure: (failure) => AccountEmailsState(failure: failure),
    );

    return result.isSuccess;
  }
}
