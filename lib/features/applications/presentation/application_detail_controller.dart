import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../domain/application.dart';
import '../domain/application_repository.dart';

/// Which application a detail screen is showing.
///
/// An application is identified by its scope as well as itself, so the family
/// is keyed by both rather than by the identifier alone.
class ApplicationRef {
  const ApplicationRef({required this.scopeId, required this.applicationId});

  final String scopeId;
  final String applicationId;

  @override
  bool operator ==(Object other) =>
      other is ApplicationRef &&
      other.scopeId == scopeId &&
      other.applicationId == applicationId;

  @override
  int get hashCode => Object.hash(scopeId, applicationId);
}

/// How far the application detail has got.
sealed class ApplicationDetailState {
  const ApplicationDetailState();
}

/// The record is being read.
final class ApplicationDetailLoading extends ApplicationDetailState {
  const ApplicationDetailLoading();
}

/// AF-22a and AF-22b — the record could not be read.
final class ApplicationDetailUnavailable extends ApplicationDetailState {
  const ApplicationDetailUnavailable(this.failure);

  final Failure failure;

  bool get isNotFound => failure.kind == FailureKind.notFound;
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

/// The record is on screen.
final class ApplicationDetailLoaded extends ApplicationDetailState {
  const ApplicationDetailLoaded(
    this.application, {
    this.saving = false,
    this.saveFailure,
    this.saved = false,
  });

  final Application application;
  final bool saving;
  final Failure? saveFailure;
  final bool saved;

  /// AF-22d — a logically deleted application is shown, but nothing about it
  /// may be changed from here.
  bool get isReadOnly => application.isDeleted;

  ApplicationDetailLoaded copyWith({
    Application? application,
    bool? saving,
    Failure? saveFailure,
    bool clearSaveFailure = false,
    bool? saved,
  }) => ApplicationDetailLoaded(
    application ?? this.application,
    saving: saving ?? this.saving,
    saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
    saved: saved ?? this.saved,
  );
}

final NotifierProviderFamily<
  ApplicationDetailController,
  ApplicationDetailState,
  ApplicationRef
>
applicationDetailControllerProvider =
    NotifierProvider.family<
      ApplicationDetailController,
      ApplicationDetailState,
      ApplicationRef
    >(ApplicationDetailController.new);

/// Owns one application's detail: reading it, and saving edits to it.
class ApplicationDetailController
    extends FamilyNotifier<ApplicationDetailState, ApplicationRef> {
  @override
  ApplicationDetailState build(ApplicationRef ref) =>
      const ApplicationDetailLoading();

  Future<void> load() async {
    state = const ApplicationDetailLoading();

    final result = await ref
        .read(applicationRepositoryProvider)
        .getById(scopeId: arg.scopeId, id: arg.applicationId);

    state = result.fold(
      onSuccess: ApplicationDetailLoaded.new,
      onFailure: ApplicationDetailUnavailable.new,
    );
  }

  /// Saves [name] and [ownerId].
  ///
  /// AF-22e is enforced by the screen, which keeps the control disabled until
  /// something differs; the same comparison is repeated here so a submission
  /// from the keyboard obeys it too.
  Future<void> save({required String name, required String ownerId}) async {
    final current = state;

    if (current is! ApplicationDetailLoaded ||
        current.saving ||
        current.isReadOnly) {
      return;
    }

    if (name == current.application.name &&
        ownerId == current.application.ownerId) {
      return;
    }

    state = current.copyWith(
      saving: true,
      clearSaveFailure: true,
      saved: false,
    );

    final result = await ref
        .read(applicationRepositoryProvider)
        .update(
          scopeId: arg.scopeId,
          id: arg.applicationId,
          name: name,
          ownerId: ownerId,
        );

    state = result.fold(
      onSuccess: (application) =>
          ApplicationDetailLoaded(application, saved: true),
      // AF-22c: the refusal is kept as it came back, and the record on screen
      // is still the one the API last confirmed.
      onFailure: (failure) =>
          current.copyWith(saving: false, saveFailure: failure),
    );
  }

  /// Drops the "saved" acknowledgement so a later edit starts clean.
  void acknowledgeSave() {
    if (state case final ApplicationDetailLoaded loaded) {
      state = loaded.copyWith(saved: false);
    }
  }
}
