import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights.dart';

void main() {
  test('GivenAnExportTime_WhenNamed_ThenTheFileIsDatedByIt', () {
    // Given
    final export = DataExport(
      document: '{}',
      exportedAt: DateTime.utc(2026, 10, 1, 9, 5, 7),
    );

    // When
    final name = export.fileName;

    // Then
    expect(name, 'heimdall-data-export-20261001-090507.json');
  });

  test('GivenNoExportTime_WhenNamed_ThenItIsStillAJsonFile', () {
    // Given
    const export = DataExport(document: '{}');

    // When
    final name = export.fileName;

    // Then
    expect(name, matches(RegExp(r'^heimdall-data-export-\d{8}-\d{6}\.json$')));
  });
}
