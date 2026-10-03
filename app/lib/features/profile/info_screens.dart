import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

final _storeInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final config = await ref.watch(publicConfigProvider.future);
  return (config['store.info'] as Map<String, dynamic>?) ?? const {};
});

final _versionProvider = FutureProvider((_) => PackageInfo.fromPlatform());

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(_storeInfoProvider).valueOrNull ?? const {};
    final phone = info['supportPhone'] as String?;
    final whatsapp = info['supportWhatsApp'] as String?;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('We’re here to help', style: text.titleLarge),
        const SizedBox(height: 4),
        Text('Questions about an order, payment or refund? Reach Jeya Hyper Store directly.', style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
        const SizedBox(height: 16),
        if (phone != null)
          _Contact(icon: Icons.call_rounded, title: 'Call the store', subtitle: phone, onTap: () => launchUrl(Uri.parse('tel:$phone'))),
        if (whatsapp != null)
          _Contact(
            icon: Icons.chat_rounded,
            title: 'WhatsApp us',
            subtitle: whatsapp,
            onTap: () => launchUrl(Uri.parse('https://wa.me/${whatsapp.replaceAll(RegExp(r'\D'), '')}'), mode: LaunchMode.externalApplication),
          ),
        _Contact(
          icon: Icons.mail_outline_rounded,
          title: 'Email',
          subtitle: AppConfig.supportEmail,
          onTap: () => launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}?subject=Help with my order')),
        ),
        const SizedBox(height: 16),
        Text('Common questions', style: text.titleSmall),
        _Faq(
          'When will my order arrive?',
          '${ref.watch(deliverySpeedProvider).headline} across Trichy — checkout shows the expected date. You can follow each step in Orders.',
        ),
        const _Faq('How do refunds work?', 'If you cancel a paid order before we start packing, the full amount is refunded to your original payment method in 3–5 working days.'),
        const _Faq('Is delivery free?', 'Delivery is free on orders of ₹999 and above. Below that, the charge depends on your distance from the store.'),
      ]),
    );
  }
}

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(_storeInfoProvider).valueOrNull ?? const {};
    final version = ref.watch(_versionProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Image.asset('assets/brand/logo_full.png', height: 150),
        const SizedBox(height: 16),
        Text('${info['name'] ?? AppConfig.storeName}, ${info['city'] ?? 'Tiruchirappalli'}', style: text.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Your neighbourhood supermarket — fresh groceries, daily essentials and household needs, delivered ${ref.watch(deliverySpeedProvider).phrase}.',
            textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
        const SizedBox(height: 24),
        if (version != null) Text('Version ${version.version} (${version.buildNumber})', textAlign: TextAlign.center, style: text.labelSmall),
      ]),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: AppColors.green50,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        child: ListTile(leading: Icon(icon, color: AppColors.green700), title: Text(title), subtitle: Text(subtitle), onTap: onTap),
      );
}

class _Faq extends StatelessWidget {
  const _Faq(this.q, this.a);
  final String q;
  final String a;
  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(q, style: Theme.of(context).textTheme.labelLarge),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedAlignment: Alignment.centerLeft,
        children: [Text(a, style: Theme.of(context).textTheme.bodySmall)],
      );
}
