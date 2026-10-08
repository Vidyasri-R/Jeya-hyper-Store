import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../image_drop.dart';

const supported = true;

/// Page-wide listeners: a picture dropped anywhere on the page, or pasted, is read and handed on.
/// Returns a function that removes them.
void Function() listen({required void Function(DroppedImage) onImage, required void Function(bool) onDragging}) {
  var depth = 0; // dragenter / dragleave fire for every element crossed

  Future<void> read(web.File file) async {
    if (!file.type.startsWith('image/')) return;
    final buffer = await file.arrayBuffer().toDart;
    onImage((bytes: buffer.toDart.asUint8List(), type: file.type));
  }

  bool hasFiles(web.DragEvent e) {
    final types = e.dataTransfer?.types.toDart ?? const [];
    return types.any((t) => t.toDart == 'Files');
  }

  final onEnter = ((web.DragEvent e) {
    if (!hasFiles(e)) return;
    depth++;
    onDragging(true);
  }).toJS;
  final onOver = ((web.DragEvent e) {
    if (hasFiles(e)) e.preventDefault(); // allow dropping here instead of the browser opening the file
  }).toJS;
  final onLeave = ((web.DragEvent e) {
    if (!hasFiles(e)) return;
    depth = depth > 0 ? depth - 1 : 0;
    if (depth == 0) onDragging(false);
  }).toJS;
  final onDrop = ((web.DragEvent e) {
    if (!hasFiles(e)) return;
    e.preventDefault();
    depth = 0;
    onDragging(false);
    final file = e.dataTransfer?.files.item(0);
    if (file != null) read(file);
  }).toJS;
  final onPaste = ((web.ClipboardEvent e) {
    final items = e.clipboardData?.items;
    if (items == null) return;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.kind == 'file' && item.type.startsWith('image/')) {
        final file = item.getAsFile();
        if (file != null) {
          e.preventDefault();
          read(file);
          return;
        }
      }
    }
  }).toJS;

  web.document.addEventListener('dragenter', onEnter);
  web.document.addEventListener('dragover', onOver);
  web.document.addEventListener('dragleave', onLeave);
  web.document.addEventListener('drop', onDrop);
  web.document.addEventListener('paste', onPaste);
  return () {
    web.document.removeEventListener('dragenter', onEnter);
    web.document.removeEventListener('dragover', onOver);
    web.document.removeEventListener('dragleave', onLeave);
    web.document.removeEventListener('drop', onDrop);
    web.document.removeEventListener('paste', onPaste);
  };
}
