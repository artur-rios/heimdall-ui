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
}
