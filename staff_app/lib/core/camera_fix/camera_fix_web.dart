import 'dart:js_interop';

import 'package:web/web.dart' as web;

void fixCameraPreview() {
  final videos = web.document.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    final video = videos.item(i) as web.HTMLVideoElement?;
    if (video == null) continue;
    video
      ..muted = true
      ..autoplay = true
      ..playsInline = true
      ..setAttribute('playsinline', '')
      ..setAttribute('muted', '');
    if (video.paused && video.srcObject != null) video.play().toDart.ignore();
  }
}
