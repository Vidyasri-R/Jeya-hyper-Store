import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

/// Shown right after the first sign-in (temporary password) and from Account → Change password.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});
  final bool forced;

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _localProblem() {
    final next = _next.text;
    if (_current.text.isEmpty) return widget.forced ? 'Enter the temporary password you were given' : 'Enter your current password';
    if (next.length < 8) return 'New password must be at least 8 characters';
    if (!RegExp('[A-Za-z]').hasMatch(next) || !RegExp('[0-9]').hasMatch(next)) return 'Use at least one letter and one number';
    if (next != _confirm.text) return 'The new passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    final problem = _localProblem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).changePassword(_current.text, _next.text);
      if (!mounted) return;
      if (!widget.forced) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed. Other devices were signed out.')));
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final staff = ref.watch(currentStaffProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.forced ? 'Set your password' : 'Change password'),
        automaticallyImplyLeading: !widget.forced,
        actions: [if (widget.forced) TextButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: const Text('Sign out'))],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.forced)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Text(
                      'Welcome${staff != null ? ', ${staff.name}' : ''}! You signed in with a temporary password. Choose your own password to continue — only you will know it.',
                      style: text.bodyMedium,
                    ),
                  ),
                TextField(
                  controller: _current,
                  obscureText: true,
                  decoration: InputDecoration(labelText: widget.forced ? 'Temporary password' : 'Current password'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _next,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password', helperText: '8+ characters with letters and numbers'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: 'Type the new password again'),
                ),
                if (_error != null) ...[const SizedBox(height: 14), Text(_error!, style: text.bodyMedium?.copyWith(color: AppColors.offerRed))],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Save password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
