import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/unload/platform_unload_guard_io.dart';

void main() {
  // Off the web there is no tab to close: an application window's close is
  // the platform's own, and the guard has nothing to hook.
  test(
    'GivenANonWebTarget_WhenRegisteredAndUnregistered_ThenNothingHappens',
    () {
      // Given
      final guard = platformUnloadGuard();

      // When / Then
      expect(() {
        guard
          ..register()
          ..register()
          ..unregister()
          ..unregister();
      }, returnsNormally);
    },
  );
}
