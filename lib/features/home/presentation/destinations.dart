import 'package:material_ui/material_ui.dart';

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
  if (principal.isSystemAdmin)
    const AppDestination(
      label: 'Erasure requests',
      icon: Icons.person_remove_outlined,
      selectedIcon: Icons.person_remove,
      route: '/erasure-requests',
    ),
  if (principal.isSystemAdmin)
    const AppDestination(
      label: 'Audit log',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      route: '/audit-log',
    ),
];
