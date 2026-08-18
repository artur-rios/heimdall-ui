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
    this.actions,
    this.floatingActionButton,
    super.key,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final appBar = (title != null || actions != null)
        ? AppBar(title: title, actions: actions)
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
            NavigationRail(
              extended: breakpoint == Breakpoint.expanded,
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
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
