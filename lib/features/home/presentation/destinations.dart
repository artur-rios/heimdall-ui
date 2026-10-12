import 'package:flutter/material.dart';

import '../../../shared/layout/destination.dart';
import '../../auth/domain/session.dart';

/// The navigation a [principal] is offered.
///
/// This is a usability decision, not a security one: the API refuses whatever
/// the role may not do, whether or not the interface offered it.
List<AppDestination> destinationsFor(Principal principal) => <AppDestination>[
  // Everybody's first stop: the dashboard. It also gives a User, who has no
  // administrative sections, two destinations — so they get navigation too.
  const AppDestination(
    label: 'Home',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard,
    route: '/',
  ),
  if (principal.administersAnything) ...<AppDestination>[
    const AppDestination(
      label: 'Scopes',
      icon: Icons.domain_outlined,
      selectedIcon: Icons.domain,
      route: '/scopes',
    ),
  ],
  const AppDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    route: '/profile',
  ),
  // Full for a System Admin, read-only for a Scope Admin (the Authorization
  // Matrix, and `roleMayReach`): the screen already answers the detailed
  // report's refusal for a Scope Admin with what they may see.
  if (principal.administersAnything)
    const AppDestination(
      label: 'Health',
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
      route: '/health',
    ),
];
