/// The platform's [FileSaver], chosen at compile time.
///
/// On the web a file can only be offered to the browser as a download; on
/// every other target it is written to disk.
library;

export 'platform_file_saver_io.dart'
    if (dart.library.js_interop) 'platform_file_saver_web.dart';
