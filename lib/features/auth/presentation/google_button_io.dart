import 'package:flutter/widgets.dart';

/// No target off the web renders its own control, so there is nothing to place
/// here. The screen only reaches this when it should show nothing anyway.
Widget buildPlatformGoogleButton() => const SizedBox.shrink();
