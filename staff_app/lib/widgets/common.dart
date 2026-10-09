import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api/api_client.dart';
import '../core/theme.dart';

final _time = DateFormat('h:mm a');
final _dayTime = DateFormat('d MMM, h:mm a');
final _day = DateFormat('d MMM');

/// "5 min ago", "2:15 PM" (today), "3 Oct, 2:15 PM" — or just "3 Oct" when [short] (order cards).
String ago(DateTime at, {bool short = false}) {
  final diff = DateTime.now().difference(at);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  final now = DateTime.now();
  if (at.year == now.year && at.month == now.month && at.day == now.day) return _time.format(at);
  return short ? _day.format(at) : _dayTime.format(at);
}

String dayTime(DateTime at) => _dayTime.format(at);

String formatBytes(num bytes) {
  if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(2)} GB';
  if (bytes >= 1e6) return '${(bytes / 1e6).toStringAsFixed(1)} MB';
  if (bytes >= 1e3) return '${(bytes / 1e3).round()} KB';
  return '${bytes.round()} B';
}

String formatCount(num n) => NumberFormat.decimalPattern('en_IN').format(n);

/// "EAN 8906021121972 ⧉": tap to copy the code (to search for the product's picture by barcode).
class CopyChip extends StatelessWidget {
  const CopyChip({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ActionChip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        avatar: const Icon(Icons.copy_rounded, size: 16),
        label: Text('$label $value', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        tooltip: 'Copy $label',
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) showSnack(context, '$label copied: $value');
        },
      );
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? AppColors.offerRed : AppColors.ink));
}

/// Runs [action], showing the API's message on failure. Returns null on error.
Future<T?> guard<T>(BuildContext context, Future<T> Function() action) async {
  try {
    return await action();
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.friendly, error: true);
  } catch (_) {
    if (context.mounted) showSnack(context, 'Something went wrong. Please try again.', error: true);
  }
  return null;
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.dense = false});
  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = StatusStyle.colors(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        StatusStyle.label(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.fg = AppColors.inkMuted, this.bg = AppColors.line, this.icon});
  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.line),
    ),
    child: child,
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.inkFaint),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
        ],
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(color: AppColors.green50, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: AppColors.green700),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[const SizedBox(height: 6), Text(subtitle!, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)],
        ],
      ),
    ),
  );
}

class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, required this.url, this.placeholderUrl, this.size = 52});
  final String? url;
  /// No photo yet: the category's general photo, marked "No photo" so it is never mistaken for one.
  final String? placeholderUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.green50,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: AppColors.green600, size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.contain, placeholder: (_, _) => placeholder, errorWidget: (_, _, _) => placeholder)
            : placeholderUrl == null
                ? placeholder
                : Stack(fit: StackFit.expand, children: [
                    Opacity(
                      opacity: 0.75,
                      child: CachedNetworkImage(imageUrl: placeholderUrl!, fit: BoxFit.cover, placeholder: (_, _) => placeholder, errorWidget: (_, _, _) => placeholder),
                    ),
                    if (size >= 44)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          color: const Color(0xB3000000),
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: const Text('No photo', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ]),
      ),
    );
  }
}

/// Bottom sheet scaffold with a title, keyboard-safe. Text fields named in [fields] (key → initial
/// text) get controllers owned by the sheet itself, disposed only once the sheet is fully closed —
/// disposing them when the sheet's Future completes would pull them out from under the closing
/// animation and crash.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required String title,
  Map<String, String> fields = const {},
  required Widget Function(BuildContext context, StateSetter setState, Map<String, TextEditingController> fields) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // Over the whole app — inside a tab the bottom navigation bar would cover the sheet's buttons.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _ActionSheet(title: title, fields: fields, builder: builder),
  );
}

class _ActionSheet extends StatefulWidget {
  const _ActionSheet({required this.title, required this.fields, required this.builder});
  final String title;
  final Map<String, String> fields;
  final Widget Function(BuildContext, StateSetter, Map<String, TextEditingController>) builder;

  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<_ActionSheet> {
  late final Map<String, TextEditingController> _controllers = {for (final entry in widget.fields.entries) entry.key: TextEditingController(text: entry.value)};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          widget.builder(context, setState, _controllers),
        ],
      ),
    ),
  );
}

/// The content type of a picked photo (JPG, PNG or WebP), or null for anything else.
String? imageTypeOf(Uint8List bytes) {
  if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'image/jpeg';
  if (bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
  if (bytes.length > 12 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') return 'image/webp';
  return null;
}
