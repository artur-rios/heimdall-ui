import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/shared/formatting/identifier.dart';

void main() {
  test('GivenAnIdentifierWithSpacesAndCapitals_WhenNormalised_ThenItIsTrimmedAndLowercased', () {
    // Given
    const raw = '  6F1C2B9E-0D4A-4C1E-9A3B-2F6D8E7A1B0C \n';

    // When
    final normalised = normaliseIdentifier(raw);

    // Then
    expect(normalised, '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c');
    expect(isIdentifier(raw), isTrue);
  });

  test('GivenSomethingElse_WhenChecked_ThenItIsNotAnIdentifier', () {
    // Given / When / Then
    expect(isIdentifier('not-a-guid'), isFalse);
    expect(isIdentifier(''), isFalse);
    expect(isIdentifier('6f1c2b9e0d4a4c1e9a3b2f6d8e7a1b0c'), isFalse);
  });
}
