import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → Premium customers: by mobile number, free delivery on every order and/or a discount on
/// the items. Applied automatically at checkout once that number signs in.
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  List<Map<String, dynamic>>? _members;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(repositoryProvider).members();
      if (mounted) setState(() => _members = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _edit([Map<String, dynamic>? member]) async {
    final saved = await showActionSheet<bool>(
      context,
      title: member == null ? 'Add a premium customer' : 'Premium customer',
      fields: {
        'phone': member == null ? '' : (member['phone'] as String).replaceFirst(RegExp(r'^91'), ''),
        'name': (member?['name'] as String?) ?? '',
        'discount': member == null ? '0' : double.parse(member['discountPercent'].toString()).toStringAsFixed(0),
        'note': (member?['note'] as String?) ?? '',
      },
      builder: (context, setState, fields) => _MemberForm(member: member, fields: fields),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final list = _members;
    return Scaffold(
      appBar: AppBar(title: const Text('Premium customers')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.person_add_alt_1_outlined), label: const Text('Add customer')),
      body: list == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
                Text(
                  'Add a customer\'s mobile number to give them free delivery on every order and/or a discount on the items. '
                  'It applies at checkout when they sign in with that number. Give the same discount on their POS bill.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                if (list.isEmpty) const EmptyView(icon: Icons.workspace_premium_outlined, title: 'No premium customers yet', subtitle: 'Tap Add customer.'),
                for (final m in list)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _edit(m),
                      leading: Icon(Icons.workspace_premium_rounded, color: m['isActive'] == true ? AppColors.amber : AppColors.inkFaint),
                      title: Text((m['name'] as String?) ?? (m['accountName'] as String?) ?? '+${m['phone']}'),
                      subtitle: Text([
                        '+${m['phone']}',
                        if (m['freeDelivery'] == true) 'Free delivery',
                        if (double.parse(m['discountPercent'].toString()) > 0) '${double.parse(m['discountPercent'].toString()).toStringAsFixed(double.parse(m['discountPercent'].toString()) % 1 == 0 ? 0 : 1)}% off',
                        m['hasAccount'] == true ? '${m['orders']} orders' : 'not signed up yet',
                        if (m['isActive'] != true) 'paused',
                      ].join(' · ')),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
              ]),
            ),
    );
  }
}

class _MemberForm extends ConsumerStatefulWidget {
  const _MemberForm({required this.member, required this.fields});
  final Map<String, dynamic>? member;
  final Map<String, TextEditingController> fields;

  @override
  ConsumerState<_MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends ConsumerState<_MemberForm> {
  late bool _freeDelivery = (widget.member?['freeDelivery'] as bool?) ?? true;
  late bool _active = (widget.member?['isActive'] as bool?) ?? true;
  bool _busy = false;

  Future<void> _save() async {
    final f = widget.fields;
    final phone = f['phone']!.text.replaceAll(RegExp(r'\D'), '');
    final discount = double.tryParse(f['discount']!.text.trim().isEmpty ? '0' : f['discount']!.text.trim());
    if (phone.length != 10) return showSnack(context, 'Enter the 10-digit mobile number', error: true);
    if (discount == null || discount < 0 || discount > 50) return showSnack(context, 'Discount must be between 0 and 50%', error: true);
    if (!_freeDelivery && discount == 0) return showSnack(context, 'Give free delivery or a discount', error: true);
    setState(() => _busy = true);
    final ok = await guard(context, () async {
      await ref.read(repositoryProvider).saveMember(
            phone: phone,
            name: f['name']!.text.trim().isEmpty ? null : f['name']!.text.trim(),
            freeDelivery: _freeDelivery,
            discountPercent: discount,
            note: f['note']!.text.trim().isEmpty ? null : f['note']!.text.trim(),
            isActive: _active,
          );
      return true;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok == true) Navigator.pop(context, true);
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    final ok = await guard(context, () async {
      await ref.read(repositoryProvider).removeMember(widget.member!['phone'] as String);
      return true;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fields;
    final editing = widget.member != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: f['phone'],
        enabled: !editing,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 '),
      ),
      const SizedBox(height: 12),
      TextField(controller: f['name'], textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name (optional)')),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _freeDelivery,
        onChanged: (v) => setState(() => _freeDelivery = v),
        title: const Text('Free delivery on every order'),
      ),
      TextField(
        controller: f['discount'],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: const InputDecoration(labelText: 'Discount on items (%)', helperText: '0 for none, up to 50'),
      ),
      const SizedBox(height: 12),
      TextField(controller: f['note'], maxLength: 200, decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. Regular customer since 2015')),
      if (editing)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _active,
          onChanged: (v) => setState(() => _active = v),
          title: const Text('Active'),
          subtitle: const Text('Turn off to pause the perks without deleting'),
        ),
      const SizedBox(height: 8),
      FilledButton(onPressed: _busy ? null : _save, child: Text(editing ? 'Save' : 'Add premium customer')),
      if (editing) TextButton(onPressed: _busy ? null : _remove, style: TextButton.styleFrom(foregroundColor: AppColors.offerRed), child: const Text('Remove from premium')),
    ]);
  }
}
