import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/outstanding_erasure.dart';

const _a = '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c';
const _b = '0a9b8c7d-6e5f-4a3b-8c2d-1e0f9a8b7c6d';

void main() {
  test('GivenIdsOnLines_WhenParsed_ThenEachIsKept', () {
    // Given / When
    final parsed = parseSubjectIds('$_a\n$_b\n');

    // Then
    expect(parsed.ids, <String>[_a, _b]);
    expect(parsed.invalid, isEmpty);
  });

  test('GivenCommasAndSpaces_WhenParsed_ThenTheyAllSeparate', () {
    // Given / When
    final parsed = parseSubjectIds(' $_a ,  $_b\t');

    // Then
    expect(parsed.ids, <String>[_a, _b]);
  });

  test('GivenRepeatsInMixedCase_WhenParsed_ThenEachIsKeptOnceLowercased', () {
    // Given / When
    final parsed = parseSubjectIds('$_a ${_a.toUpperCase()} $_a');

    // Then
    expect(parsed.ids, <String>[_a]);
  });

  test('GivenNonIdentifiers_WhenParsed_ThenTheyAreListedAsInvalid', () {
    // Given / When
    final parsed = parseSubjectIds('$_a not-an-id 1234');

    // Then
    expect(parsed.ids, <String>[_a]);
    expect(parsed.invalid, <String>['not-an-id', '1234']);
  });

  test('GivenRepeatedInvalidEntries_WhenParsed_ThenEachIsListedOnce', () {
    // Given / When
    final parsed = parseSubjectIds('bad $_a worse bad worse other');

    // Then
    expect(parsed.invalid, <String>['bad', 'worse', 'other']);
  });

  test('GivenOnlyWhitespace_WhenParsed_ThenNothingIsFound', () {
    // Given / When
    final parsed = parseSubjectIds(' \n , \t ');

    // Then
    expect(parsed.isEmpty, isTrue);
  });
}
