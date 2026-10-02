import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Single product photo (one image per product, served from Cloudflare R2).
/// Until photos are uploaded, shows a tasteful branded placeholder instead of a broken box.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url, required this.name, this.size, this.radius = AppRadius.md, this.fit = BoxFit.contain});

  final String? url;
  final String name;
  final double? size;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(name: name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url!.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url!,
                fit: fit,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, _) => Container(color: AppColors.green50),
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name});
  final String name;

  static const _tints = [
    (Color(0xFFEFF8F1), Color(0xFF1B7A3E)),
    (Color(0xFFFFF4DC), Color(0xFFB7791F)),
    (Color(0xFFE8EEFA), Color(0xFF1E4FA8)),
    (Color(0xFFFDE8E8), Color(0xFFC53030)),
    (Color(0xFFF3EAFB), Color(0xFF6B46C1)),
  ];

  @override
  Widget build(BuildContext context) {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0])).toList();
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
    final (bg, fg) = _tints[name.hashCode.abs() % _tints.length];
    return Container(
      color: bg,
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, c) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_basket_outlined, color: fg.withValues(alpha: 0.35), size: c.maxWidth * 0.34),
            if (c.maxWidth > 70)
              Text(initials, style: TextStyle(color: fg.withValues(alpha: 0.7), fontWeight: FontWeight.w800, fontSize: c.maxWidth * 0.14)),
          ],
        ),
      ),
    );
  }
}
