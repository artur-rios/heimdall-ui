import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/result/result.dart';
import '../../../core/state/build_epoch.dart';
import '../../home/presentation/dashboard_controller.dart';
import '../domain/application.dart';
import '../domain/application_repository.dart';

/// How far a create attempt has got.
sealed class ApplicationCreateState {
  const ApplicationCreateState();
}

/// The form is being filled in.
final class ApplicationCreateEditing extends ApplicationCreateState {
  const ApplicationCreateEditing();
}

/// A request is in flight. The form refuses a second submission in this state.
final class ApplicationCreateSending extends ApplicationCreateState {
  const ApplicationCreateSending();
}

/// The application exists. The screen opens its detail from here.
final class ApplicationCreated extends ApplicationCreateState {
  const ApplicationCreated(this.application);

  final Application application;
}

/// AF-21b and AF-21c — the API refused. The form keeps everything typed.
final class ApplicationCreateRejected extends ApplicationCreateState {
  const ApplicationCreateRejected(this.failure);

  final Failure failure;
}

final NotifierProviderFamily<
  ApplicationCreateController,
  ApplicationCreateState,
  String
>
applicationCreateControllerProvider =
    NotifierProvider.family<
      ApplicationCreateController,
      ApplicationCreateState,
      String
    >(ApplicationCreateController.new);

/// Owns one create attempt from filled in to created.
class ApplicationCreateController extends Notifier<ApplicationCreateState>
    with BuildEpoch<ApplicationCreateState> {
  ApplicationCreateController(this.arg);

  /// The family argument this controller was created for.
  final String arg;

  @override
  ApplicationCreateState build() {
    startEpoch();

    return const ApplicationCreateEditing();
  }

  Future<void> create({required String name, required String ownerId}) async {
    if (state is ApplicationCreateSending) {
      return;
    }

    state = const ApplicationCreateSending();

    final epoch = this.epoch;
    final result = await ref
        .read(applicationRepositoryProvider)
        .create(scopeId: arg, name: name, ownerId: ownerId);

    // Reset since it was asked: the answer is an earlier build's.
    if (!isCurrent(epoch)) {
      return;
    }

    if (result.isSuccess) {
      ref.markHomeDataStale();
    }

    state = result.fold(
      onSuccess: ApplicationCreated.new,
      onFailure: ApplicationCreateRejected.new,
    );
  }
}
