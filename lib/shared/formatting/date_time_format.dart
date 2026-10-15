import 'package:flutter/material.dart';

/// An instant as the reader's local date and time of day, in the locale's
/// words — for records where the time matters, such as audit entries.
String formatDateTime(BuildContext context, DateTime at) {
  final localizations = MaterialLocalizations.of(context);
  final local = at.toLocal();
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  return '${localizations.formatShortDate(local)} $time';
}
