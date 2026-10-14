import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights_repository.dart';
import 'package:heimdall_ui/features/data_rights/presentation/restrict_processing_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataRightsRepository extends Mock implements DataRightsRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

/// A full session's token, shaped as the API mints one.
String _userJwt() {
  String segment(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  return '${segment(<String, Object>{'alg': 'HS256'})}.'
      '${segment(<String, Object>{'id': 'person-1', 'role': '3'})}.'
      'signature';
}

const Failure _alreadyRestricted = Failure(
  kind: FailureKind.conflict,
  errors: <String>['Processing of this account is already restricted.'],
);

void main() {
  late _MockDataRightsRepository repository;
  late InMemoryTokenStore store;
  late ProviderContainer container;

  Future<RestrictProcessingController> controllerUnderTest() async {
    await store.write(
      AuthToken(value: _userJwt(), expiresAt: DateTime.utc(2030)),
    );
    container = ProviderContainer(
      overrides: <Override>[
        dataRightsRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    // Keeps the auto-dispose provider alive between calls.
    container.listen(restrictProcessingControllerProvider, (_, _) {});

    return container.read(restrictProcessingControllerProvider.notifier);
  }

  RestrictProcessingState currentState() =>
      container.read(restrictProcessingControllerProvider);

  setUpAll(() {
    registerFallbackValue(RestrictionGround.accuracyContested);
  });

  setUp(() {
    repository = _MockDataRightsRepository();
    store = InMemoryTokenStore();
  });

  test('GivenTheDialog_WhenOpened_ThenNoGroundIsChosen', () async {
    // Given
    await controllerUnderTest();

    // When
    final state = currentState();

    // Then
    expect(state.ground, isNull);
    expect(state.canConfirm, isFalse);
  });

  test('GivenNoGround_WhenRestricted_ThenNothingIsSent', () async {
    // Given
    final controller = await controllerUnderTest();

    // When
    await controller.restrict();

    // Then
    verifyNever(() => repository.restrictProcessing(any()));
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  test('GivenAGround_WhenChosen_ThenItCanBeConfirmed', () async {
    // Given
    final controller = await controllerUnderTest();

    // When
    controller.choose(RestrictionGround.neededForLegalClaim);

    // Then
    expect(currentState().ground, RestrictionGround.neededForLegalClaim);
    expect(currentState().canConfirm, isTrue);
  });

  // UI-33 main flow — restricted, then signed out with the reason.
  test('GivenAGround_WhenRestricted_ThenTheSessionEndsWithTheReason', () async {
    // Given
    when(() => repository.restrictProcessing(any()))
        .thenAnswer((_) async => const Success<void>(null));
    final controller = await controllerUnderTest();
    controller.choose(RestrictionGround.objectionPending);

    // When
    final restricted = await controller.restrict();

    // Then
    expect(restricted, isTrue);
    verify(
      () => repository.restrictProcessing(RestrictionGround.objectionPending),
    ).called(1);
    final session = container.read(sessionControllerProvider);
    expect((session as Unauthenticated).processingRestricted, isTrue);
    expect(await store.read(), isNull);
  });

  // AF-33b — already restricted: the API's words, and the session stays.
  test(
    'GivenAnAlreadyRestrictedAccount_WhenRestricted_ThenTheConflictIsKept',
    () async {
      // Given
      when(
        () => repository.restrictProcessing(any()),
      ).thenAnswer((_) async => const FailureResult<void>(_alreadyRestricted));
      final controller = await controllerUnderTest();
      controller.choose(RestrictionGround.accuracyContested);

      // When
      final restricted = await controller.restrict();

      // Then
      expect(restricted, isFalse);
      expect(currentState().failure?.errors, _alreadyRestricted.errors);
      expect(currentState().sending, isFalse);
      expect(currentState().ground, RestrictionGround.accuracyContested);
      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    },
  );

  // AF-33d — a transport failure; the person may try again.
  test('GivenATransportFailure_WhenRestricted_ThenTheFailureIsKept', () async {
    // Given
    when(() => repository.restrictProcessing(any())).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = await controllerUnderTest();
    controller.choose(RestrictionGround.accuracyContested);

    // When
    await controller.restrict();

    // Then
    expect(currentState().failure?.kind, FailureKind.network);
    expect(currentState().canConfirm, isTrue);
  });

  test(
    'GivenAFailure_WhenRestrictedAgain_ThenTheOldFailureIsCleared',
    () async {
      // Given
      final pending = Completer<Result<void>>();
      when(
        () => repository.restrictProcessing(any()),
      ).thenAnswer((_) async => const FailureResult<void>(_alreadyRestricted));
      final controller = await controllerUnderTest();
      controller.choose(RestrictionGround.accuracyContested);
      await controller.restrict();
      when(() => repository.restrictProcessing(any()))
          .thenAnswer((_) => pending.future);

      // When
      final second = controller.restrict();

      // Then
      expect(currentState().failure, isNull);
      expect(currentState().sending, isTrue);
      pending.complete(const Success<void>(null));
      await second;
    },
  );

  test('GivenARequestInFlight_WhenRestrictedAgain_ThenOnlyOneIsSent', () async {
    // Given
    final pending = Completer<Result<void>>();
    when(() => repository.restrictProcessing(any()))
        .thenAnswer((_) => pending.future);
    final controller = await controllerUnderTest();
    controller.choose(RestrictionGround.unlawfulButErasureOpposed);
    final first = controller.restrict();

    // When
    await controller.restrict();
    controller.choose(RestrictionGround.accuracyContested);

    // Then
    expect(currentState().canConfirm, isFalse);
    expect(currentState().ground, RestrictionGround.unlawfulButErasureOpposed);
    pending.complete(const Success<void>(null));
    await first;
    verify(() => repository.restrictProcessing(any())).called(1);
  });
}
