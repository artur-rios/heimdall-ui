/// The platform's start-up step for the entry address, chosen at compile time.
///
/// Only a browser has an address bar to read and tidy; on every other target
/// there is nothing to take.
library;

export 'platform_entry_link_io.dart'
    if (dart.library.js_interop) 'platform_entry_link_web.dart';
