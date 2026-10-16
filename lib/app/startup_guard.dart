import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import 'theme.dart';

/// The root to run: the application from [app], or, when this build must not
/// start, a screen that says why.
///
/// A release build of the installed apps refuses a cleartext API
/// ([AppConfig.requireSecureApi]). Throwing before `runApp` would leave a
/// blank window with the reason only in the log; this writes the same line to
/// the log through [log] (`debugPrint` by default) and shows it on screen.
Widget guardStartup(
  AppConfig config,
  Widget Function() app, {
  bool release = kReleaseMode,
  bool web = kIsWeb,
  void Function(String line)? log,
}) {
  try {
    config.requireSecureApi(release: release, web: web);
  } on InsecureApiBaseUrlError catch (error) {
    (log ?? debugPrint)(error.toString());

    return StartupErrorApp(reason: error.toString());
  }

  return app();
}

/// What a build that must not start shows instead of the application.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.reason, super.key});

  /// The reason, as written to the log.
  final String reason;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Heimdall',
    debugShowCheckedModeBanner: false,
    theme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    home: Builder(
      builder: (context) {
        final theme = Theme.of(context);

        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Heimdall cannot start',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      reason,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
