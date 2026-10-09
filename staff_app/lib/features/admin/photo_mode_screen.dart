import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/camera_fix.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'products_screen.dart';

/// Photo mode: scan the barcode on a product (the store's POS label or the maker's barcode), and its
/// photo sheet opens — take the picture, the app cuts it out onto white, done; scan the next one.
class PhotoModeScreen extends ConsumerStatefulWidget {
  const PhotoModeScreen({super.key});

  @override
  ConsumerState<PhotoModeScreen> createState() => _PhotoModeScreenState();
}

class _PhotoModeScreenState extends ConsumerState<PhotoModeScreen> {
  final _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.all]);
  /// Website: a USB barcode scanner (it types the code + Enter) or typing it by hand.
  final _typed = TextEditingController();
  Timer? _cameraFix;
  bool _busy = false;
  int _done = 0;
  String? _last;

  @override
  void initState() {
    super.initState();
    // The camera <video> appears a moment after the screen opens (and again after a restart).
    if (kIsWeb) _cameraFix = Timer.periodic(const Duration(milliseconds: 700), (_) => fixCameraPreview());
  }

  @override
  void dispose() {
    _cameraFix?.cancel();
    _typed.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.map((b) => b.rawValue?.trim()).whereType<String>().firstWhere((c) => c.isNotEmpty, orElse: () => '');
    if (code == _last) return;
    await _lookup(code);
  }

  Future<void> _lookup(String code) async {
    if (_busy || code.isEmpty) return;
    setState(() {
      _busy = true;
      _last = code;
    });
    await _scanner.stop();
    if (!mounted) return;
    try {
      final product = await guard(context, () => ref.read(repositoryProvider).productByBarcode(code));
      if (!mounted) return;
      if (product == null) {
        showSnack(context, 'No product with barcode $code — upload today’s stock file, or find it in Products', error: true);
      } else {
        final changed = await showProductSheet(context, ref, product, photoOnly: !(ref.read(currentStaffProvider)?.isAdmin ?? false));
        if (changed == true && mounted) setState(() => _done++);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _scanner.start();
        // Let the same product be scanned again after a short pause.
        Future<void>.delayed(const Duration(seconds: 2), () => mounted ? setState(() => _last = null) : null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Photo mode')),
      body: Column(children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            MobileScanner(
              controller: _scanner,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    kIsWeb
                        ? 'Camera not available (${error.errorCode.name}). Allow the camera for this site (the icon at the left of the address bar), close other apps using the camera, then reopen this page — or type the barcode below.'
                        : 'Camera not available: ${error.errorCode.name}. Allow camera access for Jeya Staff in your phone settings.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 280,
                  height: 160,
                  decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            if (_busy) const ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator(color: Colors.white))),
            Positioned(
              right: 12,
              top: 12,
              child: IconButton.filledTonal(onPressed: () => _scanner.toggleTorch(), tooltip: 'Torch', icon: const Icon(Icons.flashlight_on_outlined)),
            ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Point at the barcode on the product or its price label.', style: text.titleSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextField(
                controller: _typed,
                autofocus: kIsWeb,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.keyboard_alt_outlined),
                  hintText: 'Or type the barcode / use a USB barcode scanner',
                ),
                onSubmitted: (value) {
                  final code = value.trim();
                  _typed.clear();
                  _lookup(code);
                },
              ),
              const SizedBox(height: 4),
              Text(
                _done == 0 ? 'Then take the photo inside the light box. Switch on "Clean up background" in the photo sheet to make it pure white.' : '$_done photo${_done == 1 ? '' : 's'} saved in this session.',
                style: text.bodySmall?.copyWith(color: _done == 0 ? null : AppColors.green700),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
