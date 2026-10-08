import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../image_drop.dart';

const supported = false;

void Function() listen({required void Function(DroppedImage) onImage, required void Function(bool) onDragging}) => () {};

const _channel = MethodChannel('jeya/clipboard');

/// Android: a picture copied elsewhere ("Copy image" in Chrome or Gallery), or null.
Future<DroppedImage?> readClipboardImage() async {
  if (defaultTargetPlatform != TargetPlatform.android) return null;
  final found = await _channel.invokeMapMethod<String, Object?>('readImage');
  final bytes = found?['bytes'];
  if (bytes is! Uint8List) return null;
  return (bytes: bytes, type: found?['type'] as String? ?? 'image/jpeg');
}

const canPaste = true;
