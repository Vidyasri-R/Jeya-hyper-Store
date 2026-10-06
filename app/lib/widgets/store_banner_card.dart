import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../core/store_banner.dart';
import '../core/theme.dart';

/// One admin-managed banner in the Home carousel (Admin → Home banners).
/// Picture only → the image is the banner; picture + text → text over the picture with a
/// shade for contrast; text only → a card in the chosen (or brand) colour.
class StoreBannerCard extends StatelessWidget {
  const StoreBannerCard(this.banner, {super.key});
  final StoreBanner banner;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.xl);
    final b = banner;
    final bg = b.background ?? AppColors.brand50;
    final onPhoto = b.image != null;
    final darkCard = !onPhoto && bg.computeLuminance() < 0.4;
    final ink = onPhoto || darkCard ? Colors.white : AppColors.brand900;
    final body = onPhoto || darkCard ? Colors.white.withValues(alpha: 0.92) : AppColors.ink;

    Widget? image;
    if (b.image != null) {
      image = CachedNetworkImage(
        imageUrl: b.image!,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => ColoredBox(color: AppColors.brand100),
        errorWidget: (_, _, _) => ColoredBox(color: AppColors.brand100),
      );
    }

    final content = b.imageOnly
        ? image!
        : Stack(fit: StackFit.expand, children: [
            if (image != null) ...[
              image,
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xCC000000), Color(0x66000000), Color(0x00000000)], stops: [0, 0.55, 1]),
                ),
              ),
            ] else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [bg, Color.lerp(bg, AppColors.brand100, 0.35)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (b.tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: onPhoto ? Colors.white : AppColors.brand700, borderRadius: BorderRadius.circular(20)),
                    child: Text(b.tag!.toUpperCase(),
                        style: text.labelSmall?.copyWith(color: onPhoto ? AppColors.brand800 : Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  ),
                if (b.tag != null) const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(b.title!, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleLarge?.copyWith(height: 1.1, color: ink, fontWeight: FontWeight.w800)),
                ),
                if (b.subtitle != null) ...[
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(b.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: body)),
                  ),
                ],
                const Spacer(),
                if (b.cta != null && b.route != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: onPhoto ? Colors.white : AppColors.brand800, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(b.cta!, style: text.labelLarge?.copyWith(color: onPhoto ? AppColors.brand800 : Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: onPhoto ? AppColors.brand800 : Colors.white),
                    ]),
                  ),
              ]),
            ),
          ]);

    return Semantics(
      button: b.route != null,
      label: [b.tag, b.title, b.subtitle].whereType<String>().join(', ').ifEmpty('Offer banner'),
      child: Material(
        color: bg,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: b.route == null ? null : () => openRoute(context, b.route!), child: content),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
