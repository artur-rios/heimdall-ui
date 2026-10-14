import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../domain/erasure_request_repository.dart';
import '../domain/outstanding_erasure.dart';
import 'erasure_request_list_controller.dart';

/// Where the re-apply dialog is.
sealed class ReconciliationState {
  const ReconciliationState();
}

/// The paste is being written or corrected.
final class ReconciliationEditing extends ReconciliationState {
  const ReconciliationEditing({
    this.invalid = const <String>[],
    this.empty = false,
    this.failure,
  });

  /// AF-32d — entries that are not identifiers. Nothing is sent while any are.
  final List<String> invalid;

  /// AF-32e — nothing was pasted. The API refuses an empty run on purpose: it
  /// almost always means the ledger was not loaded.
  final bool empty;

  /// AF-32g / AF-32h — the API refused, or could not be reached.
  final Failure? failure;
}

final class ReconciliationSending extends ReconciliationState {
  const ReconciliationSending();
}

final class ReconciliationDone extends ReconciliationState {
  const ReconciliationDone(this.outcome);

  final ReconciliationOutcome outcome;
}

final NotifierProvider<ReconciliationController, ReconciliationState>
reconciliationControllerProvider =
    NotifierProvider.autoDispose<ReconciliationController, ReconciliationState>(
      ReconciliationController.new,
    );

/// The Operations runbook step after a restore: re-apply every erasure the
/// anonymisation pass has logged since the backup was taken.
class ReconciliationController extends Notifier<ReconciliationState> {
  @override
  ReconciliationState build() => const ReconciliationEditing();

  /// The paste, when it can be sent; otherwise `null`, with the reason in the
  /// state.
  ParsedSubjectIds? check(String text) {
    final parsed = parseSubjectIds(text);

    if (parsed.ids.isEmpty && parsed.invalid.isEmpty) {
      state = const ReconciliationEditing(empty: true);

      return null;
    }

    if (parsed.invalid.isNotEmpty) {
      state = ReconciliationEditing(invalid: parsed.invalid);

      return null;
    }

    state = const ReconciliationEditing();

    return parsed;
  }

  Future<void> send(List<String> ids) async {
    if (state is ReconciliationSending) {
      return;
    }

    state = const ReconciliationSending();

    // Taken before the await: the run is real once the API has it, so the
    // queue is refreshed whether or not this provider outlives the call.
    final list = ref.read(erasureRequestListControllerProvider.notifier);
    final result = await ref
        .read(erasureRequestRepositoryProvider)
        .reapply(ids);

    if (ref.mounted) {
      state = result.fold<ReconciliationState>(
        onSuccess: ReconciliationDone.new,
        onFailure: (failure) => ReconciliationEditing(failure: failure),
      );
    }

    // A restored identity anonymised again leaves the queue; show it gone.
    if (result.isSuccess) {
      await list.load();
    }
  }
}
