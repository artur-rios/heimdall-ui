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
}
