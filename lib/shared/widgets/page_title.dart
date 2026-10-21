import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Names the screen for the browser tab, the history entry and assistive
/// technology: `<title> - Heimdall`.
///
/// Routes nest, so a list sits built underneath the record opened over it, and
/// builds again whenever its own state changes. Only the screen on top may
/// name the page, or the list's rebuild would rename the tab after the record.
/// Watching the route is what makes the title follow the visible screen when
/// the one on top goes away and the one under it is current again.
class PageTitle extends StatelessWidget {
  const PageTitle({required this.title, required this.child, super.key});

  /// The screen's own name, without the application's.
  final String title;
  final Widget child;

  /// The label the application adds after every screen's name.
  static const String suffix = 'Heimdall';

  static String _label = suffix;

  /// What the tab is called now: the screen on top's label, or the
  /// application's own name before any screen has set one.
  ///
  /// The application's title reads this, so that rebuilding it — a theme or
  /// locale change — puts back this label rather than the bare name.
  static String get currentLabel => _label;

  /// Forgets the label set so far. For tests, which share this state.
  @visibleForTesting
  static void reset() => _label = suffix;

  @override
  Widget build(BuildContext context) {
    // Without a route — a widget pumped on its own — there is nothing above to
    // compete with.
    final label = '$title - $suffix';

    // Told to the platform only when it changes, not on every rebuild.
    if ((ModalRoute.of(context)?.isCurrent ?? true) && label != _label) {
      _label = label;
      unawaited(
        SystemChrome.setApplicationSwitcherDescription(
          ApplicationSwitcherDescription(
            label: label,
            primaryColor: Theme.of(context).colorScheme.primary.toARGB32(),
          ),
        ),
      );
    }

    return child;
  }
}
