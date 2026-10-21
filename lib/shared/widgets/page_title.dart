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

  @override
  Widget build(BuildContext context) {
    // Without a route — a widget pumped on its own — there is nothing above to
    // compete with.
    if (ModalRoute.of(context)?.isCurrent ?? true) {
      unawaited(
        SystemChrome.setApplicationSwitcherDescription(
          ApplicationSwitcherDescription(
            label: '$title - $suffix',
            primaryColor: Theme.of(context).colorScheme.primary.toARGB32(),
          ),
        ),
      );
    }

    return child;
  }
}
