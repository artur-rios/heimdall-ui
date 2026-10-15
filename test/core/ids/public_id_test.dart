import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/ids/public_id.dart';

void main() {
  for (final id in <String>[
    '6f1d3a00-0000-0000-0000-000000000001',
    '6F1D3A00-ABCD-EF01-2345-6789ABCDEF01',
  ]) {
    test('GivenAGuid_WhenChecked_ThenItIsAPublicId $id', () {
      // Given / When
      final valid = isPublicId(id);

      // Then
      expect(valid, isTrue);
    });
  }

  for (final id in <String>[
    '',
    'scope-1',
    'new',
    '..',
    '../../persons/6f1d3a00-0000-0000-0000-000000000001?x=',
    '{6f1d3a00-0000-0000-0000-000000000001}',
    '6f1d3a00-0000-0000-0000-000000000001\n',
    ' 6f1d3a00-0000-0000-0000-000000000001',
    '6f1d3a00000000000000000000000001',
    '6f1d3a00-0000-0000-0000-00000000000g',
    '6f1d3a00-0000-0000-0000-0000000000011',
  ]) {
    test('GivenAnythingElse_WhenChecked_ThenItIsNotAPublicId "$id"', () {
      // Given / When
      final valid = isPublicId(id);

      // Then
      expect(valid, isFalse);
    });
  }
}
