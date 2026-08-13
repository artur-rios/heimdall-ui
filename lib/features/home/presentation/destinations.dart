import 'package:flutter/material.dart';

import '../../../shared/layout/destination.dart';
import '../../auth/domain/session.dart';

/// The navigation a [principal] is offered.
///
/// This is a usability decision, not a security one: the API refuses whatever
/// the role may not do, whether or not the interface offered it.
List<AppDestination> destinationsFor(Principal principal) => <AppDestination>[
  if (principal.administersAnything) ...<AppDestination>[
    const AppDestination(
      label: 'Scopes',
      icon: Icons.domain_outlined,
      route: '/scopes',
    ),
  ],
  const AppDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    route: '/profile',
  ),
  if (principal.isSystemAdmin)
    const AppDestination(
      label: 'Health',
      icon: Icons.monitor_heart_outlined,
      route: '/health',
    ),
];
