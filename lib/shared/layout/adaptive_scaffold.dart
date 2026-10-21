import 'package:flutter/material.dart';

import 'breakpoints.dart';
import 'destination.dart';

/// The application shell: bottom navigation when the window is narrow, a rail
/// when it is not, and an extended rail when there is room for the labels.
///
/// Screens are handed a [body] and never think about navigation themselves,
/// which is what keeps one layout decision in one place.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.title,
    this.leading,
    this.actions,
    this.floatingActionButton,
    super.key,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final Widget? title;

  /// What sits before the title — a way back, on a screen below a destination.
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final appBar = (title != null || actions != null || leading != null)
        ? AppBar(leading: leading, title: title, actions: actions)
        : null;

    // One destination is not navigation, and both Material controls assert on
    // fewer than two. A plain User is offered only their own profile, so this
    // is an ordinary case rather than a defensive one.
    if (destinations.length < 2) {
      return Scaffold(
        appBar: appBar,
        body: SafeArea(child: body),
        floatingActionButton: floatingActionButton,
      );
    }

    if (breakpoint == Breakpoint.compact) {
      return Scaffold(
        appBar: appBar,
        body: SafeArea(child: body),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: <Widget>[
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(
                  destination.selectedIcon ?? destination.icon,
                ),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Row(
          children: <Widget>[
            // A scrolling rail must not take the route's primary controller:
            // on iOS and Android the body's list inherits it too, and a
            // keyboard scroll then finds two positions and throws.
            PrimaryScrollController.none(
              child: NavigationRail(
                extended: breakpoint == Breakpoint.expanded,
                // The breakpoints read only the width: a short window, or a
                // soft keyboard taking the bottom of a tall one, can leave less
                // height than a System Admin's destinations need, so the rail
                // scrolls rather than overflowing and clipping the last ones.
                scrollable: true,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                // An extended rail shows its labels beside the icons already;
                // asking for them twice throws.
                labelType: breakpoint == Breakpoint.expanded
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: <NavigationRailDestination>[
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(
                        destination.selectedIcon ?? destination.icon,
                      ),
                      label: Text(destination.label),
                      // The rail's own height is 44, under the 48 a tap
                      // target needs; two more each side makes it so.
                      padding: const EdgeInsets.symmetric(vertical: 2),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
