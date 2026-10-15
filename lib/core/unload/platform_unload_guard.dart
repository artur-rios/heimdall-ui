/// The platform's [UnloadGuard], chosen at compile time.
///
/// Only a browser tab can be closed or refreshed under the application; on
/// every other target the guard does nothing.
library;

export 'platform_unload_guard_io.dart'
    if (dart.library.js_interop) 'platform_unload_guard_web.dart';
