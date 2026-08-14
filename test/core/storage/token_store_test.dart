import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';

void main() {
  test('GivenEmptyStore_WhenRead_ThenReturnsNull', () async {
    // Given
    final store = InMemoryTokenStore();

    // When
    final token = await store.read();

    // Then
    expect(token, isNull);
  });

  test('GivenWrittenToken_WhenRead_ThenReturnsTheSameToken', () async {
    // Given
    final store = InMemoryTokenStore();
    final token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030));

    // When
    await store.write(token);
    final read = await store.read();

    // Then
    expect(read?.value, 'jwt');
    expect(read?.expiresAt, DateTime.utc(2030));
  });

  test('GivenWrittenToken_WhenCleared_ThenReadReturnsNull', () async {
    // Given
    final store = InMemoryTokenStore();
    await store.write(AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)));

    // When
    await store.clear();

    // Then
    expect(await store.read(), isNull);
  });

  test('GivenPastExpiry_WhenInspected_ThenTokenIsExpired', () {
    // Given
    final token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2000));

    // When
    final expired = token.isExpired;

    // Then
    expect(expired, isTrue);
  });

  test('GivenFutureExpiry_WhenInspected_ThenTokenIsNotExpired', () {
    // Given
    final token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030));

    // When
    final expired = token.isExpired;

    // Then
    expect(expired, isFalse);
  });

  test('GivenToken_WhenRoundTrippedThroughJson_ThenItSurvives', () {
    // Given
    final token = AuthToken(
      value: 'jwt',
      expiresAt: DateTime.utc(2030, 5, 4, 3, 2, 1),
    );

    // When
    final restored = AuthToken.fromJson(token.toJson());

    // Then
    expect(restored.value, token.value);
    expect(restored.expiresAt, token.expiresAt);
  });

  // UI-06 — sign-out has to tell Google about a Google session, including one
  // restored from storage, so where it came from is stored with it.
  test('GivenAGoogleToken_WhenRoundTrippedThroughJson_ThenItStaysGoogle', () {
    // Given
    final token = AuthToken(
      value: 'jwt',
      expiresAt: DateTime.utc(2030),
      viaGoogle: true,
    );

    // When
    final restored = AuthToken.fromJson(token.toJson());

    // Then
    expect(restored.viaGoogle, isTrue);
  });

  // AF-05e — the API reports this with the token, and a restored session needs
  // it as much as a fresh one does.
  test('GivenAnUnverifiedToken_WhenRoundTrippedThroughJson_ThenItStays', () {
    // Given
    final token = AuthToken(
      value: 'jwt',
      expiresAt: DateTime.utc(2030),
      emailVerified: false,
    );

    // When
    final restored = AuthToken.fromJson(token.toJson());

    // Then
    expect(restored.emailVerified, isFalse);
  });

  // A token stored before the API reported it says nothing, which is not the
  // same as saying the address is unverified.
  test('GivenAStoredTokenWithoutTheAnswer_WhenRead_ThenItIsVerified', () {
    // Given
    final json = <String, dynamic>{
      'value': 'jwt',
      'expiresAt': '2030-01-01T00:00:00.000Z',
    };

    // When
    final restored = AuthToken.fromJson(json);

    // Then
    expect(restored.emailVerified, isTrue);
  });

  test('GivenAnUnverifiedToken_WhenMarkedVerified_ThenOnlyThatChanges', () {
    // Given
    final token = AuthToken(
      value: 'jwt',
      expiresAt: DateTime.utc(2030),
      viaGoogle: true,
      emailVerified: false,
    );

    // When
    final verified = token.asVerified();

    // Then
    expect(verified.emailVerified, isTrue);
    expect(verified.value, token.value);
    expect(verified.expiresAt, token.expiresAt);
    expect(verified.viaGoogle, isTrue);
  });

  // Anything written before UI-06 was password-only and carries no such key.
  test('GivenAStoredTokenWithoutTheFlag_WhenRead_ThenItIsNotGoogle', () {
    // Given
    final json = <String, dynamic>{
      'value': 'jwt',
      'expiresAt': '2030-01-01T00:00:00.000Z',
    };

    // When
    final restored = AuthToken.fromJson(json);

    // Then
    expect(restored.viaGoogle, isFalse);
  });
}
