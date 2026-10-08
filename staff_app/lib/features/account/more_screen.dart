import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin tools (admins) + the signed-in account (everyone).
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(currentStaffProvider);
    final alerts = ref.watch(boardProvider.select((s) => s.summary));
    final text = Theme.of(context).textTheme;
    if (staff == null) return const SizedBox.shrink();

    Widget tile(IconData icon, String title, String subtitle, VoidCallback onTap, {Widget? trailing}) => ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Icon(icon, color: AppColors.green700),
      ),
      title: Text(title, style: text.titleSmall),
      subtitle: Text(subtitle, style: text.bodySmall),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: Text(staff.isAdmin ? 'More' : 'Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.green100,
                  child: Text(staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?', style: text.titleLarge?.copyWith(color: AppColors.green800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staff.name, style: text.titleMedium),
                      Text('@${staff.username}', style: text.bodySmall),
                    ],
                  ),
                ),
                Pill(
                  staff.isAdmin ? 'Admin' : (staff.isPhotoHelper ? 'Photo helper' : 'Staff'),
                  fg: staff.isAdmin ? AppColors.brandBlue : AppColors.green700,
                  bg: staff.isAdmin ? AppColors.brandBlueSoft : AppColors.green50,
                ),
              ],
            ),
          ),
          if (staff.isAdmin) ...[
            const SizedBox(height: 20),
            Text('Store admin', style: text.titleSmall?.copyWith(color: AppColors.inkMuted)),
            const SizedBox(height: 6),
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  tile(Icons.account_balance_outlined, 'Finance (online)', 'Sales, margin, expenses and profit', () => context.go('/more/finance')),
                  tile(Icons.workspace_premium_outlined, 'Premium customers', 'Free delivery or a discount, by mobile number', () => context.go('/more/members')),
                  tile(
                    Icons.upload_file_rounded,
                    'Upload stock file',
                    'Daily GoFrugal “Current Stock Detail” CSV: products, prices, stock',
                    () => context.go('/more/stock'),
                  ),
                  tile(
                    Icons.add_a_photo_outlined,
                    'Photo work',
                    'Products without photos — hand them out and track progress',
                    () => context.go('/more/photo-work'),
                  ),
                  tile(
                    Icons.account_balance_wallet_outlined,
                    'Usage & bills',
                    'Render, Supabase, R2 and Razorpay this month',
                    () => context.go('/more/usage'),
                    trailing: (alerts?.alertsOpen ?? 0) > 0
                        ? Badge(label: Text('${alerts!.alertsOpen}'), backgroundColor: levelColors(alerts.alertsWorst).$1)
                        : null,
                  ),
                  tile(Icons.badge_outlined, 'Staff accounts', 'Add people, reset passwords, disable', () => context.go('/more/staff')),
                  tile(Icons.storefront_outlined, 'Store settings', 'Festival theme, delivery fees, payments, contact', () => context.go('/more/settings')),
                  tile(Icons.star_outline_rounded, 'Home: offers & popular', 'Pick the products for "Today\'s offers" and "Popular in your store"', () => context.go('/more/home-lists')),
                  tile(Icons.category_outlined, 'Category photos', 'Shown on products that have no photo yet', () => context.go('/more/categories')),
                  tile(Icons.view_carousel_outlined, 'Home banners', 'Offer pictures and text at the top of the customer app', () => context.go('/more/banners')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Account', style: text.titleSmall?.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: 6),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                tile(Icons.password_rounded, 'Change password', 'Signs out your other devices', () => context.push('/password')),
                if (!staff.isPhotoHelper)
                  tile(
                    Icons.volume_up_outlined,
                    'Test new-order sound',
                    'Check the phone volume',
                    () => ref.read(boardProvider.notifier).chime(),
                    trailing: const Icon(Icons.play_arrow_rounded),
                  ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.offerRedSoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: const Icon(Icons.logout_rounded, color: AppColors.offerRed),
                  ),
                  title: Text('Sign out', style: text.titleSmall?.copyWith(color: AppColors.offerRed)),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Sign out?'),
                        content: const Text('You will stop hearing new orders on this device.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
                        ],
                      ),
                    );
                    if (ok == true) await ref.read(sessionProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text('${AppConfig.appName} · ${AppConfig.storeName}', style: text.labelSmall)),
        ],
      ),
    );
  }
}
