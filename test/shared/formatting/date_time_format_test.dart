import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/shared/formatting/date_time_format.dart';

void main() {
  testWidgets('GivenAnInstant_WhenFormatted_ThenItShowsTheLocalDateAndTime', (
    tester,
  ) async {
    // Given
    final at = DateTime(2026, 10, 14, 9, 5).toUtc();
    late String formatted;

    // When
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(alwaysUse24HourFormat: true),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              formatted = formatDateTime(context, at);

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // Then — the local wall-clock time, not the UTC one
    expect(formatted, contains('09:05'));
    expect(formatted, contains('2026'));
  });
}
