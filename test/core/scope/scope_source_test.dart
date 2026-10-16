import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/scope/scope_source.dart';
import 'package:heimdall_ui/core/scope/session_scope_source.dart';

void main() {
  test('GivenAConfiguredScope_WhenRead_ThenItIsReturned', () {
    // Given
    const source = FixedScopeSource('scope-public-id');

    // When
    final scopeId = source.read();

    // Then
    expect(scopeId, 'scope-public-id');
  });

  // An undefined `String.fromEnvironment` reads as the empty string, which
  // means the same thing as absent.
  test('GivenAnEmptyScope_WhenRead_ThenNothingIsReturned', () {
    // Given
    const source = FixedScopeSource('');

    // When
    final scopeId = source.read();

    // Then
    expect(scopeId, isNull);
  });

  test('GivenNoScope_WhenRead_ThenNothingIsReturned', () {
    // Given
    const source = FixedScopeSource(null);

    // When
    final scopeId = source.read();

    // Then
    expect(scopeId, isNull);
  });

  // Off the web there is no calling application to read from, so the
  // build-time value is the whole answer.
  test('GivenTheHostPlatform_WhenSourceBuilt_ThenTheFallbackIsUsed', () {
    // Given / When
    final source = sessionScopeSource(fallback: 'scope-public-id');

    // Then
    expect(source.read(), 'scope-public-id');
  });

  // The key the calling application writes, which is part of this
  // application's contract with its callers.
  test('GivenTheStorageKey_WhenRead_ThenItIsTheAgreedOne', () {
    // Given / When / Then
    expect(scopeStorageKey, 'heimdall.scopeId');
  });

  // The scope kept in session storage, whether start-up copied it from the URL
  // or a caller on the UI's origin wrote it, is held to the same rule as the
  // URL's: a PublicId, or nothing.
  const guid = '6f1d3a00-0000-0000-0000-0000000000aa';

  test('GivenAStoredGuid_WhenRead_ThenItIsReturned', () {
    // Given
    final source = StoredScopeSource(() => guid, fallback: 'fallback-id');

    // When
    final scopeId = source.read();

    // Then
    expect(scopeId, guid);
  });

  for (final stored in <String>['..%2Fpersons', 'scope-1', '$guid\n']) {
    test('GivenAStoredNonGuid_WhenRead_ThenTheFallbackIsUsed "$stored"', () {
      // Given
      final source = StoredScopeSource(() => stored, fallback: 'fallback-id');

      // When
      final scopeId = source.read();

      // Then
      expect(scopeId, 'fallback-id');
    });
  }

  for (final stored in <String?>[null, '']) {
    test('GivenNothingStored_WhenRead_ThenTheFallbackIsUsed "$stored"', () {
      // Given
      final source = StoredScopeSource(() => stored, fallback: 'fallback-id');

      // When
      final scopeId = source.read();

      // Then
      expect(scopeId, 'fallback-id');
    });
  }

  // Read on every use: a caller may change it between one attempt and the
  // next.
  test('GivenAChangedStoredScope_WhenReadAgain_ThenTheNewOneIsReturned', () {
    // Given
    var stored = guid;
    final source = StoredScopeSource(() => stored);
    source.read();

    // When
    stored = '6f1d3a00-0000-0000-0000-0000000000bb';

    // Then
    expect(source.read(), stored);
  });
}
