import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});
  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _valid => RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text);

  Future<void> _continue() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).requestOtp(_phone.text);
      if (!mounted) return;
      final from = widget.from != null ? '&from=${Uri.encodeComponent(widget.from!)}' : '';
      context.push('/otp?phone=${_phone.text}$from');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: context.canPop() ? const BackButton() : null,
        actions: [if (!context.canPop()) TextButton(onPressed: () => context.go('/home'), child: const Text('Skip'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Center(child: Image.asset('assets/brand/logo_full.png', height: 150)),
            const SizedBox(height: 28),
            Text('Login or sign up', style: text.headlineMedium),
            const SizedBox(height: 6),
            Text('Enter your mobile number to get an OTP', style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
            const SizedBox(height: 24),
            TextField(
              controller: _phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              style: text.titleMedium?.copyWith(letterSpacing: 1.2),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _continue(),
              decoration: InputDecoration(
                hintText: 'Mobile number',
                errorText: _error,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('+91', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    Container(width: 1, height: 22, color: AppColors.line),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _valid && !_busy ? _continue : null,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Continue'),
            ),
            const SizedBox(height: 18),
            Text(
              'By continuing, you agree to our Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
