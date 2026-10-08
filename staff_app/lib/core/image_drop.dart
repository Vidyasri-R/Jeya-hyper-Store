import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Right-click (website) or long-press (phone) on [child] → "Paste photo": reads a picture copied
/// elsewhere ("Copy image" in a browser, a screenshot, Gallery) and hands it to [onImage].
class PastePhotoTarget extends StatefulWidget {
  const PastePhotoTarget({super.key, required this.child, required this.onImage, this.onError, this.enabled = true});
  final Widget child;
  final void Function(DroppedImage image) onImage;
  /// Shown to the user, e.g. when the clipboard holds no picture.
  final void Function(String message)? onError;
  final bool enabled;

  @override
  State<PastePhotoTarget> createState() => _PastePhotoTargetState();
}

class _PastePhotoTargetState extends State<PastePhotoTarget> {
  @override
  void initState() {
    super.initState();
    // Our menu instead of the browser's on right-click.
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
  }

  @override
  void dispose() {
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    super.dispose();
  }

  Future<void> _menu(Offset at) async {
    if (!widget.enabled) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      items: const [
        PopupMenuItem(value: 'paste', child: ListTile(dense: true, leading: Icon(Icons.content_paste_rounded), title: Text('Paste photo'))),
      ],
    );
    if (picked != 'paste' || !mounted) return;
    try {
      final image = await impl.readClipboardImage();
      if (!mounted) return;
      if (image == null) {
        widget.onError?.call('No photo copied yet — long-press a picture and choose "Copy image", then paste here');
      } else {
        widget.onImage(image);
      }
    } catch (_) {
      if (mounted) widget.onError?.call('Couldn\'t read the copied photo. Allow clipboard access, or save it and use Gallery / Upload.');
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (d) => _menu(d.globalPosition),
        onLongPressStart: (d) => _menu(d.globalPosition),
        child: widget.child,
      );
}
