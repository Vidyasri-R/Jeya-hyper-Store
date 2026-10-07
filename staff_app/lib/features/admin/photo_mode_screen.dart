import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  bool _busy = false;
  int _done = 0;
  String? _last;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.map((b) => b.rawValue?.trim()).whereType<String>().firstWhere((c) => c.isNotEmpty, orElse: () => '');
    if (_busy || code.isEmpty || code == _last) return;
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
                  child: Text('Camera not available: ${error.errorCode.name}. Allow camera access for Jeya Staff in your phone settings.', textAlign: TextAlign.center),
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
              const SizedBox(height: 4),
              Text(
                _done == 0 ? 'Then take the photo inside the light box — the background is removed automatically.' : '$_done photo${_done == 1 ? '' : 's'} saved in this session.',
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
