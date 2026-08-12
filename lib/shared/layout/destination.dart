import 'package:flutter/material.dart';

/// One entry in the application's navigation.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}
