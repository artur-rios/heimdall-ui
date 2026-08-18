import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../domain/google_user.dart';
import '../domain/google_user_repository.dart';

/// Which Google User a detail screen is showing.
class GoogleUserRef {
  const GoogleUserRef({required this.scopeId, required this.googleUserId});

  final String scopeId;
  final String googleUserId;

  @override
  bool operator ==(Object other) =>
      other is GoogleUserRef &&
      other.scopeId == scopeId &&
      other.googleUserId == googleUserId;

  @override
  int get hashCode => Object.hash(scopeId, googleUserId);
}

/// How far the Google user detail has got.
sealed class GoogleUserDetailState {
  const GoogleUserDetailState();
}

/// The record is being read.
final class GoogleUserDetailLoading extends GoogleUserDetailState {
  const GoogleUserDetailLoading();
}

/// The record could not be read.
final class GoogleUserDetailUnavailable extends GoogleUserDetailState {
  const GoogleUserDetailUnavailable(this.failure);

  final Failure failure;

  bool get isNotFound => failure.kind == FailureKind.notFound;
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

/// The record is on screen.
///
/// AF-28e: there is nothing to save here. Every field comes from Google, so
/// the state carries no editing of any kind.
final class GoogleUserDetailLoaded extends GoogleUserDetailState {
  const GoogleUserDetailLoaded(this.user);

  final GoogleUser user;
}

final NotifierProviderFamily<
  GoogleUserDetailController,
  GoogleUserDetailState,
  GoogleUserRef
>
googleUserDetailControllerProvider =
    NotifierProvider.family<
      GoogleUserDetailController,
      GoogleUserDetailState,
      GoogleUserRef
    >(GoogleUserDetailController.new);

/// Owns one Google user's detail. Reading it is all there is to do.
class GoogleUserDetailController
    extends FamilyNotifier<GoogleUserDetailState, GoogleUserRef> {
  @override
  GoogleUserDetailState build(GoogleUserRef ref) =>
      const GoogleUserDetailLoading();

  Future<void> load() async {
    state = const GoogleUserDetailLoading();

    final result = await ref
        .read(googleUserRepositoryProvider)
        .getById(scopeId: arg.scopeId, id: arg.googleUserId);

    state = result.fold(
      onSuccess: GoogleUserDetailLoaded.new,
      onFailure: GoogleUserDetailUnavailable.new,
    );
  }
}
