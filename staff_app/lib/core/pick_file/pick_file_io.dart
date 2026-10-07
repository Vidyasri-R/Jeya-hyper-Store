import 'package:file_picker/file_picker.dart';

import '../pick_file.dart';

Future<PickedFile?> pickFile(String extension) async {
  final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: [extension]);
  if (picked.isEmpty) return null;
  return (name: picked.single.name, bytes: await picked.single.readAsBytes());
}
