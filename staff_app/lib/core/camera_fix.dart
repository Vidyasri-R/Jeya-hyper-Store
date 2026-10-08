import 'camera_fix/camera_fix_io.dart' if (dart.library.js_interop) 'camera_fix/camera_fix_web.dart' as impl;

/// Website: the barcode scanner's camera preview stayed black on some browsers (iPhone Safari needs
/// `playsinline`, autoplay needs `muted`). Marks the page's camera <video> so it plays in place.
void fixCameraPreview() => impl.fixCameraPreview();
