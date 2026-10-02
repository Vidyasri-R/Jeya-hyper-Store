import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

/// First-login step: ask for the customer's name (shown on orders and to the delivery staff).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) return setState(() => _error = 'Please enter your name');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(repositoryProvider).updateProfile(name: name);
      ref.read(authProvider.notifier).userUpdated(user);
      if (mounted) context.go('/home');
    } on ApiException catch (e) {
      setState(() => _error = e.details['reason'] == null && e.code == 'VALIDATION_FAILED' ? 'Name can only contain letters and spaces' : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Center(child: Image.asset('assets/brand/logo_mark.png', height: 84)),
            const SizedBox(height: 24),
            Text('Welcome to Jeya Hyper Store!', style: text.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('What should we call you?', style: text.bodyMedium?.copyWith(color: AppColors.inkMuted), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(hintText: 'Your full name', errorText: _error, prefixIcon: const Icon(Icons.person_outline_rounded)),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Start Shopping'),
            ),
          ],
        ),
      ),
    );
  }
}
