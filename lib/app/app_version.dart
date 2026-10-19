import 'package:flutter/material.dart';

/// The release this build is, as `pubspec.yaml`'s `version:` names it.
///
/// Kept as a constant rather than read from the platform at runtime, so every
/// target shows it synchronously and the web build needs no `version.json`
/// round trip. `test/app/app_version_test.dart` fails when it, `pubspec.yaml`,
/// and the newest release in CHANGELOG.md disagree — which is what keeps the
/// three in step when a release is finalized.
const String appVersion = '1.9.0';

/// How the version is written wherever it is shown.
const String appVersionLabel = 'Heimdall UI v$appVersion';

/// The slim strip at the bottom of every screen that says which release is
/// running — the first thing to ask when someone reports a problem.
class AppVersionFooter extends StatelessWidget {
  const AppVersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Text(
            appVersionLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
