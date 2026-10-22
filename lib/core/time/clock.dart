import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time, as a provider so a test can move it instead of waiting.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);
