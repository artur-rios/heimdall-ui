/// How long a logically deleted person or Google user is kept before it is
/// anonymised and can no longer be restored.
///
/// Mirrors `DataRetentionOptions.DefaultAdministrativeDeletionWindow` in
/// heimdall-api, which `AnonymiseExpiredDeletionsCommand` applies. The API does
/// not publish the value, so a change there has to be made here too.
const Duration administrativeDeletionWindow = Duration(days: 90);

/// [administrativeDeletionWindow] as the user reads it, such as "90 days".
String get administrativeDeletionWindowText =>
    '${administrativeDeletionWindow.inDays} days';
