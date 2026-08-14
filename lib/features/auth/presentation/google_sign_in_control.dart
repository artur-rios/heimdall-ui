import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../domain/google_sign_in_gateway.dart';
import 'google_button.dart';
import 'session_controller.dart';

/// The Google sign-in control, in whichever form this target allows.
///
/// Two shapes, one behaviour: where the application may drive the flow it
/// offers its own button; where Google insists on rendering the button itself
/// the ID token arrives on a stream instead, and this listens for it. Either
/// way the exchange, and everything that can go wrong with it, is the same.
class GoogleSignInControl extends ConsumerStatefulWidget {
  const GoogleSignInControl({required this.enabled, super.key});

  /// False while the credentials form is submitting, so the two routes in
  /// cannot be taken at once.
  final bool enabled;

  @override
  ConsumerState<GoogleSignInControl> createState() =>
      _GoogleSignInControlState();
}

class _GoogleSignInControlState extends ConsumerState<GoogleSignInControl> {
  StreamSubscription<GoogleIdTokenObtained>? _tokens;

  Failure? _failure;
  bool _exchanging = false;

  @override
  void initState() {
    super.initState();

    final gateway = ref.read(googleSignInGatewayProvider);

    if (gateway.availability == GoogleSignInAvailability.platformControl) {
      // The SDK must be ready before its button can render, and the button is
      // what starts the flow — so there is nothing to await it beside.
      unawaited(gateway.initialize());
      _tokens = gateway.idTokens.listen(
        (obtained) => unawaited(_exchange(obtained.idToken)),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_tokens?.cancel());
    super.dispose();
  }

  /// Runs the flow ourselves, on a target that permits it.
  Future<void> _signIn() async {
    setState(() {
      _exchanging = true;
      _failure = null;
    });

    final result = await ref
        .read(sessionControllerProvider.notifier)
        .signInWithGoogle();

    if (!mounted) {
      return;
    }

    // AF-06c: a cancellation comes back successful and changes nothing, so the
    // screen is exactly as the user left it.
    setState(() {
      _exchanging = false;
      _failure = result.failureOrNull;
    });
  }

  /// Exchanges a token that arrived from Google's own button.
  Future<void> _exchange(String idToken) async {
    setState(() {
      _exchanging = true;
      _failure = null;
    });

    final result = await ref
        .read(sessionControllerProvider.notifier)
        .exchangeGoogleIdToken(idToken);

    if (!mounted) {
      return;
    }

    setState(() {
      _exchanging = false;
      _failure = result.failureOrNull;
    });
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(googleSignInGatewayProvider).availability;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // AF-06b and AF-06d both land here: what Heimdall said, shown as it
        // came, with the credentials form untouched above it.
        if (_failure case final Failure failure) ...<Widget>[
          ErrorBanner(failure: failure),
          const SizedBox(height: 16),
        ],
        if (_exchanging)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          switch (availability) {
            GoogleSignInAvailability.interactive => OutlinedButton.icon(
              onPressed: widget.enabled ? _signIn : null,
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Continue with Google'),
            ),
            GoogleSignInAvailability.platformControl =>
              buildPlatformGoogleButton(),
            // AF-06e: the screen already withholds this control, so reaching
            // here would be a bug rather than a state to render.
            GoogleSignInAvailability.unsupported => const SizedBox.shrink(),
          },
      ],
    );
  }
}
