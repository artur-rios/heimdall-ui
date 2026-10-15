/// The platform's [ScopeSource], chosen at compile time.
///
/// On the web the scope the calling application handed over is in session
/// storage; on every other target there is no such caller, so the build-time
/// value is all there is.
library;

export 'session_scope_source_io.dart'
    if (dart.library.js_interop) 'session_scope_source_web.dart';
