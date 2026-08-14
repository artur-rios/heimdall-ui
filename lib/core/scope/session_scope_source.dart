/// The platform's [ScopeSource], chosen at compile time.
///
/// On the web the calling application writes the scope into session storage
/// before sending the user here; on every other target there is no such caller,
/// so the build-time value is all there is.
library;

export 'session_scope_source_io.dart'
    if (dart.library.js_interop) 'session_scope_source_web.dart';
