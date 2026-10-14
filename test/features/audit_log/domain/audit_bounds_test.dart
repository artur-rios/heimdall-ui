import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/audit_log/domain/audit_entry.dart';

void main() {
  test('GivenADayPickedWestOfUtc_WhenBounded_ThenTheBoundsCoverTheLocalDay', () {
    // Given — the picker hands back local midnights for the chosen days
    final firstDay = DateTime(2026, 10, 14);
    final lastDay = DateTime(2026, 10, 14);

    // When
    final bounds = auditBoundsFor(firstDay, lastDay);

    // Then — exactly the local day, expressed in UTC whatever the test zone is
    expect(bounds.from.isUtc, isTrue);
    expect(bounds.to.isUtc, isTrue);
    expect(bounds.from, DateTime(2026, 10, 14).toUtc());
    expect(bounds.to, DateTime(2026, 10, 14, 23, 59, 59, 999).toUtc());
    // A late-evening local entry is inside, the previous local day is not.
    final lateEvening = DateTime(2026, 10, 14, 22, 30).toUtc();
    final dayBefore = DateTime(2026, 10, 13, 23, 0).toUtc();
    expect(
      !lateEvening.isBefore(bounds.from) && !lateEvening.isAfter(bounds.to),
      isTrue,
    );
    expect(dayBefore.isBefore(bounds.from), isTrue);
  });

  test('GivenATimeOfDayOnThePickedDays_WhenBounded_ThenOnlyTheDatesCount', () {
    // Given
    final firstDay = DateTime(2026, 10, 1, 15, 45);
    final lastDay = DateTime(2026, 10, 3, 8, 10);

    // When
    final bounds = auditBoundsFor(firstDay, lastDay);

    // Then
    expect(bounds.from, DateTime(2026, 10, 1).toUtc());
    expect(bounds.to, DateTime(2026, 10, 3, 23, 59, 59, 999).toUtc());
  });
}
