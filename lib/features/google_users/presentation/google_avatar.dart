import 'package:flutter/material.dart';

import '../domain/google_user.dart';

/// A Google User's picture, or their initials when there is none to show.
///
/// AF-28d and FR-GU-03: a missing picture and an unreachable one are the same
/// thing to a reader, so both fall back to the initials rather than leaving a
/// hole in the row. The fallback is also what renders first, so a slow image
/// never leaves blank space behind it.
class GoogleAvatar extends StatelessWidget {
  const GoogleAvatar({required this.user, this.radius = 20, super.key});

  final GoogleUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = user.profilePictureUrl;
    final picture = (url == null || url.isEmpty) ? null : NetworkImage(url);

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      // The initials sit underneath: `foregroundImage` draws over them when it
      // loads and leaves them alone when it fails, so an unreachable picture
      // needs no error handling of its own.
      foregroundImage: picture,
      // An image that will not load is not worth reporting to the user; the
      // initials already say who this is. The handler may only be given
      // alongside an image, which is why it is conditional too.
      onForegroundImageError: picture == null ? null : (_, _) {},
      child: Text(user.initials),
    );
  }
}
