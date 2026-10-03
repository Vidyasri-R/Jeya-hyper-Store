import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

class StaffAccountsScreen extends ConsumerStatefulWidget {
  const StaffAccountsScreen({super.key});

  @override
  ConsumerState<StaffAccountsScreen> createState() => _StaffAccountsScreenState();
}

class _StaffAccountsScreenState extends ConsumerState<StaffAccountsScreen> {
  List<Staff>? _staff;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final staff = await ref.read(repositoryProvider).staffList();
      if (mounted) {
        setState(() {
          _staff = staff;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = _staff;
    final me = ref.watch(currentStaffProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Staff accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await _createStaff(context, ref);
          if (created == null || !context.mounted) return;
          _load();
          await _showTemporaryPassword(context, created.$1, created.$2, created.$3);
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add staff'),
      ),
      body: staff == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: staff.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final s = staff[index];
                  return SectionCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: s.isActive ? AppColors.green100 : AppColors.line,
                        child: Text(
                          s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                          style: TextStyle(color: s.isActive ? AppColors.green800 : AppColors.inkMuted),
                        ),
                      ),
                      title: Text(
                        '${s.name}${s.id == me?.id ? ' (you)' : ''}',
                        style: text.titleSmall?.copyWith(color: s.isActive ? null : AppColors.inkMuted),
                      ),
                      subtitle: Text(
                        ['@${s.username}', s.lastLoginAt != null ? 'last seen ${ago(s.lastLoginAt!)}' : 'never signed in'].join(' · '),
                        style: text.bodySmall,
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          if (s.isAdmin) const Pill('Admin', fg: AppColors.brandBlue, bg: AppColors.brandBlueSoft),
                          if (!s.isActive) const Pill('Disabled', fg: AppColors.offerRed, bg: AppColors.offerRedSoft),
                          if (s.isLocked) const Pill('Locked', fg: Color(0xFF8A5A00), bg: AppColors.amberSoft),
                          if (s.mustChangePassword && s.isActive) const Pill('New'),
                        ],
                      ),
                      onTap: () async {
                        final result = await _manageStaff(context, ref, s, isMe: s.id == me?.id);
                        if (result == null || !context.mounted) return;
                        _load();
                        if (result is String) await _showTemporaryPassword(context, s.name, s.username, result);
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// Shows a one-time password with a copy button.
Future<void> _showTemporaryPassword(BuildContext context, String name, String username, String password) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Temporary password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Give these to $name. They will set their own password at first sign-in. This password is shown only once.', style: text.bodyMedium),
          const SizedBox(height: 16),
          Text('Username', style: text.labelSmall),
          SelectableText(username, style: text.titleMedium),
          const SizedBox(height: 10),
          Text('Temporary password', style: text.labelSmall),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: SelectableText(password, style: text.headlineMedium?.copyWith(letterSpacing: 1.5, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: 'Jeya Staff\nUsername: $username\nTemporary password: $password'));
            showSnack(context, 'Copied');
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  },
);

/// Returns (name, username, temporary password) for the new account, or null if dismissed.
/// The one-time password dialog is shown by the screen, not from this closing sheet.
Future<(String, String, String)?> _createStaff(BuildContext context, WidgetRef ref) {
  var role = 'staff';
  var busy = false;
  String? error;
  return showActionSheet<(String, String, String)>(
    context,
    title: 'Add a staff member',
    fields: const {'username': '', 'name': '', 'phone': ''},
    builder: (context, setState, fields) {
      final username = fields['username']!;
      final name = fields['name']!;
      final phone = fields['phone']!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: username,
            autocorrect: false,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]')), LowerCaseFormatter()],
            decoration: const InputDecoration(labelText: 'Username', helperText: 'What they type to sign in, e.g. ravi or ravi.packing'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Mobile number (optional)', prefixText: '+91 '),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'staff', label: Text('Staff'), icon: Icon(Icons.inventory_2_outlined)),
              ButtonSegment(value: 'admin', label: Text('Admin'), icon: Icon(Icons.admin_panel_settings_outlined)),
            ],
            selected: {role},
            onSelectionChanged: (s) => setState(() => role = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            role == 'admin' ? 'Admins can also see sales, change settings and manage staff.' : 'Staff handle orders: packing, delivery and cancellations.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(error!, style: const TextStyle(color: AppColors.offerRed)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final (staff, password) = await ref
                          .read(repositoryProvider)
                          .createStaff(username: username.text.trim(), name: name.text.trim(), phone: phone.text.trim(), role: role);
                      if (context.mounted) Navigator.pop(context, (staff.name, staff.username, password));
                    } on ApiException catch (e) {
                      setState(() => error = e.friendly);
                    } finally {
                      if (context.mounted) setState(() => busy = false);
                    }
                  },
            child: const Text('Create account'),
          ),
        ],
      );
    },
  );
}

/// Returns the new temporary password after a reset, true after another change, or null.
Future<Object?> _manageStaff(BuildContext context, WidgetRef ref, Staff staff, {required bool isMe}) {
  return showActionSheet<Object>(
    context,
    title: staff.name,
    builder: (context, setState, _) {
      final repo = ref.read(repositoryProvider);
      Future<void> update(Map<String, dynamic> patch, String done) async {
        final ok = await guard(context, () => repo.updateStaff(staff.id, patch));
        if (ok != null && context.mounted) {
          showSnack(context, done);
          Navigator.pop(context, true);
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('@${staff.username}${staff.phone != null ? ' · +${staff.phone}' : ''}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.key_rounded),
            label: Text(staff.isLocked ? 'Unlock & reset password' : 'Reset password'),
            onPressed: () async {
              final password = await guard(context, () => repo.resetPassword(staff.id));
              if (password != null && context.mounted) Navigator.pop(context, password);
            },
          ),
          if (!isMe) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: Icon(staff.isAdmin ? Icons.inventory_2_outlined : Icons.admin_panel_settings_outlined),
              label: Text(staff.isAdmin ? 'Change to staff (no admin tools)' : 'Make admin'),
              onPressed: () => update({'role': staff.isAdmin ? 'staff' : 'admin'}, staff.isAdmin ? 'Now staff' : 'Now an admin'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: staff.isActive ? AppColors.offerRed : AppColors.green700,
                side: BorderSide(color: staff.isActive ? AppColors.offerRed : AppColors.green700),
              ),
              icon: Icon(staff.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded),
              label: Text(staff.isActive ? 'Disable account (signs them out now)' : 'Enable account'),
              onPressed: () => update({'isActive': !staff.isActive}, staff.isActive ? 'Account disabled' : 'Account enabled'),
            ),
          ],
        ],
      );
    },
  );
}

class LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) => newValue.copyWith(text: newValue.text.toLowerCase());
}
