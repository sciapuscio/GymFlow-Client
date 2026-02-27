/// Conditional scanner import — picks the real library on mobile, stub on desktop/web.
///
/// Dart conditional imports use `dart.library.io` (available on mobile/desktop) and
/// `dart.library.html` (available on web). We use this to swap in the stub on 
/// non-mobile platforms so mobile_scanner's C++ native code doesn't compile on Windows.
export 'scanner_stub.dart'
    if (dart.library.io) 'scanner_io.dart';
