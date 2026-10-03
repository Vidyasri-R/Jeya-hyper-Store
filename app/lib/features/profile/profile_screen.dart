import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently removes your profile, saved addresses and cart. Past order invoices are kept as required by law. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.offerRed), onPressed: () => Navigator.pop(c, true), child: const Text('Delete account')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authProvider.notifier).deleteAccount();
      if (context.mounted) {
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your account has been deleted')));
      }
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final text = Theme.of(context).textTheme;

    if (auth is! SignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Image.asset('assets/brand/logo_full.png', height: 140),
          const SizedBox(height: 20),
          Text('Login to see your orders, saved addresses and more.', textAlign: TextAlign.center, style: text.bodyMedium),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => context.push('/login'), child: const Text('Login / Sign up')),
          const SizedBox(height: 24),
          _Tile(icon: Icons.support_agent_rounded, title: 'Help & Support', onTap: () => context.push('/help')),
          _Tile(icon: Icons.info_outline_rounded, title: 'About Jeya Hyper Store', onTap: () => context.push('/about')),
        ]),
      );
    }

    final user = auth.user;
    final initial = (user.name?.isNotEmpty == true ? user.name![0] : 'J').toUpperCase();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(26))),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Row(children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white,
                    child: Text(initial, style: text.headlineSmall?.copyWith(color: AppColors.brand700, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.name ?? 'Jeya customer', style: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      Text(user.displayPhone, style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                      if (user.email != null) Text(user.email!, style: text.bodySmall?.copyWith(color: Colors.white70)),
                    ]),
                  ),
                  IconButton(onPressed: () => context.push('/profile/edit'), icon: const Icon(Icons.edit_outlined, color: Colors.white)),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: LinearGradient(colors: [AppColors.brandBlueSoft, AppColors.brand50]),
              ),
              child: Row(children: [
                Image.asset('assets/brand/logo_mark.png', height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Jeya Membership', style: text.titleSmall?.copyWith(color: AppColors.brandBlue, fontWeight: FontWeight.w800)),
                    Text('Member benefits are coming soon to the app', style: text.labelSmall),
                  ]),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(child: _QuickAction(icon: Icons.receipt_long_rounded, title: 'My Orders', subtitle: 'Track & reorder', onTap: () => context.go('/orders'))),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(icon: Icons.location_on_outlined, title: 'Addresses', subtitle: 'Home, work…', onTap: () => context.push('/addresses'))),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
            child: Column(children: [
              _Tile(icon: Icons.person_outline_rounded, title: 'Edit Profile', subtitle: 'Name and email', onTap: () => context.push('/profile/edit')),
              _Tile(icon: Icons.support_agent_rounded, title: 'Help & Support', subtitle: 'Questions about orders or payments', onTap: () => context.push('/help')),
              _Tile(icon: Icons.info_outline_rounded, title: 'About Jeya Hyper Store', subtitle: 'Store details, policies', onTap: () => context.push('/about')),
              _Tile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/home');
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _confirmDelete(context, ref),
              style: TextButton.styleFrom(foregroundColor: AppColors.offerRed),
              child: const Text('Delete my account'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
          child: Row(children: [
            Icon(icon, color: AppColors.brand700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: text.titleSmall),
                Text(subtitle, style: text.labelSmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.ink),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: subtitle == null ? null : Text(subtitle!, style: Theme.of(context).textTheme.labelSmall),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        onTap: onTap,
      );
}
