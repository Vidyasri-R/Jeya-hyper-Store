import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../pick_file.dart';

/// A plain <input type=file>. file_picker's web version treats the window getting focus back as
/// "cancelled"; Safari fires that focus as the dialog opens, so the chosen file was ignored.
/// Here only the input's own change / cancel events count.
Future<PickedFile?> pickFile(List<String> extensions) {
  final done = Completer<PickedFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = extensions.map((e) => '.$e').join(',')
    ..style.display = 'none';
  web.document.body!.append(input);

  void finish(PickedFile? file) {
    input.remove();
    if (!done.isCompleted) done.complete(file);
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final file = input.files?.item(0);
      if (file == null) return finish(null);
      file.arrayBuffer().toDart.then(
        (buffer) => finish((name: file.name, bytes: buffer.toDart.asUint8List())),
        onError: (Object e, StackTrace s) {
          input.remove();
          if (!done.isCompleted) done.completeError(e, s);
        },
      );
    }).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return done.future;
}
