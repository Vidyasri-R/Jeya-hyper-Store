import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'image_drop/image_drop_io.dart' if (dart.library.js_interop) 'image_drop/image_drop_web.dart' as impl;

/// A dropped or pasted picture: bytes and its type (image/jpeg, image/png, image/webp…).
typedef DroppedImage = ({Uint8List bytes, String type});

/// On the website, a picture can be dragged onto the page or pasted (Ctrl/⌘+V) while [child] is
/// shown; [onImage] gets it. Phones keep the camera / gallery buttons.
class ImageDropZone extends StatefulWidget {
  const ImageDropZone({super.key, required this.child, required this.onImage, this.enabled = true});
  final Widget child;
  final void Function(DroppedImage image) onImage;
  final bool enabled;

  /// Drag & drop and paste work here (the website).
  static bool get supported => impl.supported;

  @override
  State<ImageDropZone> createState() => _ImageDropZoneState();
}

class _ImageDropZoneState extends State<ImageDropZone> {
  void Function()? _detach;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _detach = impl.listen(
      onImage: (image) {
        if (mounted && widget.enabled) widget.onImage(image);
      },
      onDragging: (dragging) {
        if (mounted && dragging != _dragging) setState(() => _dragging = dragging);
      },
    );
  }

  @override
  void dispose() {
    _detach?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        if (_dragging && widget.enabled)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.green50.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.green700, width: 2),
                ),
                alignment: Alignment.center,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.file_download_outlined, size: 44, color: AppColors.green700),
                  const SizedBox(height: 8),
                  Text('Drop the photo here', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.green800)),
                ]),
              ),
            ),
          ),
      ]);
}
