import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, this.from});
  final String phone;
  final String? from;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otp = TextEditingController();
  bool _busy = false;
  String? _error;
  int _resendIn = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer(30);
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn <= 1) t.cancel();
      if (mounted) setState(() => _resendIn--);
    });
  }

  Future<void> _verify() async {
    if (_otp.text.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(repositoryProvider).verifyOtp(widget.phone, _otp.text);
      ref.read(authProvider.notifier).signedIn(result.user);
      // Router redirect sends the user on (profile setup for new users, else back to where they were).
      if (mounted && result.user.profileComplete) context.go(widget.from ?? '/home');
    } on ApiException catch (e) {
      final remaining = e.details['attemptsRemaining'];
      setState(() => _error = remaining is int && remaining > 0 ? '${e.message} ($remaining attempts left)' : e.message);
      _otp.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      final wait = await ref.read(repositoryProvider).requestOtp(widget.phone);
      _startTimer(wait);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent again')));
    } on ApiException catch (e) {
      final retry = e.details['retryAfterSec'];
      if (retry is int) _startTimer(retry);
      setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final masked = '+91 ${widget.phone.substring(0, 5)} ${widget.phone.substring(5)}';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text('Enter OTP', style: text.headlineMedium),
            const SizedBox(height: 6),
            Text.rich(TextSpan(
              style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
              children: [
                const TextSpan(text: 'We sent a 6-digit code to '),
                TextSpan(text: masked, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
              ],
            )),
            const SizedBox(height: 28),
            TextField(
              controller: _otp,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              style: text.headlineSmall?.copyWith(letterSpacing: 14, fontWeight: FontWeight.w700),
              onChanged: (v) {
                setState(() => _error = null);
                if (v.length == 6) _verify();
              },
              decoration: InputDecoration(hintText: '••••••', errorText: _error),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _otp.text.length == 6 && !_busy ? _verify : null,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Verify & Continue'),
            ),
            const SizedBox(height: 12),
            Center(
              child: _resendIn > 0
                  ? Text('Resend OTP in ${_resendIn}s', style: text.bodySmall)
                  : TextButton(onPressed: _resend, child: const Text('Resend OTP')),
            ),
            Center(child: TextButton(onPressed: () => context.pop(), child: const Text('Change number'))),
          ],
        ),
      ),
    );
  }
}
