import 'package:flutter/material.dart';

/// One entry in the application's navigation.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.route,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;

  /// The filled variant shown while this destination is the current one, so
  /// the selection reads by shape as well as by color.
  final IconData? selectedIcon;
  final String route;
}
