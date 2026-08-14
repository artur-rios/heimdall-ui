import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google;

/// Google's own Sign-In button.
///
/// The web SDK will not be driven from an arbitrary widget — it answers
/// `supportsAuthenticate()` false and requires this button — so what the user
/// presses here is Google's, and the account arrives on the gateway's stream
/// rather than as the result of a call.
Widget buildPlatformGoogleButton() => google.renderButton();
