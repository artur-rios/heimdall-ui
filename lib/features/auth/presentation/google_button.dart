/// The control Google renders for itself, on the targets that insist on it.
library;

export 'google_button_io.dart'
    if (dart.library.js_interop) 'google_button_web.dart';
