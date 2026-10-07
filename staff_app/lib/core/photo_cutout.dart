import 'package:flutter/foundation.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

/// On Android, cut the product out of its background on the phone (Google ML Kit subject
/// segmentation, offline) so the server can place it on pure white. Anywhere else — or if no
/// product is found — the original photo is returned and the server's white-background cleanup
/// does the rest.
Future<(Uint8List bytes, String contentType)> cutOutProduct(String path, Uint8List original, String originalType) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return (original, originalType);
  final segmenter = SubjectSegmenter(
    options: SubjectSegmenterOptions(
      enableForegroundBitmap: true,
      enableForegroundConfidenceMask: false,
      enableMultipleSubjects: SubjectResultOptions(enableConfidenceMask: false, enableSubjectBitmap: false),
    ),
  );
  try {
    final result = await segmenter.processImage(InputImage.fromFilePath(path)).timeout(const Duration(seconds: 20));
    final png = result.foregroundBitmap;
    // A cut-out smaller than ~2 KB is an empty mask: keep the photo as taken.
    if (png == null || png.length < 2048) return (original, originalType);
    return (png, 'image/png');
  } catch (e) {
    debugPrint('cutout skipped: $e');
    return (original, originalType);
  } finally {
    await segmenter.close();
  }
}
