import 'dart:typed_data';

import 'pick_file/pick_file_io.dart' if (dart.library.js_interop) 'pick_file/pick_file_web.dart' as impl;

/// A picked file: its name and contents.
typedef PickedFile = ({String name, Uint8List bytes});

/// Lets the user choose one file with the given extension (e.g. 'csv') or any of [also]; null if they cancel.
Future<PickedFile?> pickFile(String extension, {List<String> also = const []}) => impl.pickFile([extension, ...also]);
