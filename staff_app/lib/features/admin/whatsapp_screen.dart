import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → WhatsApp login: the shop's WhatsApp number and login_code template, a test message to
/// your own phone, and the switch that sends customer login codes by WhatsApp.
class WhatsAppScreen extends ConsumerStatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  ConsumerState<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends ConsumerState<WhatsAppScreen> {
  Map<String, dynamic>? _status;
  String? _error;
  bool _sending = false;
  bool _switching = false;
  String? _lastTestCode;
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await ref.read(repositoryProvider).whatsappStatus();
      if (mounted) setState(() => _status = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _sendTest() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty) return;
    setState(() => _sending = true);
    final r = await guard(context, () => ref.read(repositoryProvider).whatsappTest(phone));
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (r != null) _lastTestCode = r['code'] as String?;
    });
    if (r != null) showSnack(context, 'Sent — check WhatsApp on that phone');
  }

  Future<void> _setLogin(bool on) async {
    setState(() => _switching = true);
    final r = await guard(context, () => ref.read(repositoryProvider).setWhatsappLogin(on));
    if (!mounted) return;
    setState(() {
      _switching = false;
      if (r != null) _status = {...?_status, 'loginOn': r};
    });
    if (r != null) showSnack(context, on ? 'Customers now get their login code on WhatsApp' : 'WhatsApp login codes switched off');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = _status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp login'),
        actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          if (_error != null)
            ErrorView(message: _error!, onRetry: _load)
          else if (s == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else ...[
            _SetupCard(status: s),
            const SizedBox(height: 12),
            if (s['configured'] == true) ...[
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('1. Send yourself a test code', style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text('Uses the real login_code message. The code in it can’t be used to sign in.', style: text.bodySmall),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                        decoration: const InputDecoration(labelText: 'Mobile number', hintText: '98765 43210', isDense: true),
                        onSubmitted: (_) => _sendTest(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _sending ? null : _sendTest,
                      icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
                      label: const Text('Send'),
                    ),
                  ]),
                  if (_lastTestCode != null) ...[
                    const SizedBox(height: 8),
                    Text('Sent code $_lastTestCode — the WhatsApp message should show the same number.', style: text.bodySmall?.copyWith(color: AppColors.green700)),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              SectionCard(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: s['loginOn'] == true,
                  onChanged: _switching ? null : _setLogin,
                  title: const Text('2. Send customer login codes by WhatsApp'),
                  subtitle: Text(
                    s['loginOn'] == true
                        ? 'On — customers get their 6-digit code on WhatsApp (about ₹0.12–0.15 each).'
                        : 'Off — customers can’t receive a login code. Switch on after the test message arrives.',
                    style: text.bodySmall,
                  ),
                ),
              ),
            ],
          ],
        ]),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.status});
  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (status['configured'] != true) {
      return SectionCard(
        color: AppColors.amberSoft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Not connected yet', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Add WHATSAPP_TOKEN, WHATSAPP_PHONE_NUMBER_ID and WHATSAPP_BUSINESS_ACCOUNT_ID in Render → Environment, '
            'save, and wait for the deploy to finish. Then refresh this page.',
            style: text.bodySmall,
          ),
        ]),
      );
    }
    final account = status['account'] as Map?;
    final number = account?['number'] as Map?;
    final templates = [for (final t in (account?['templates'] as List? ?? const [])) Map<String, dynamic>.from(t as Map)];
    final approved = templates.any((t) => t['status'] == 'APPROVED');
    final problem = status['problem'] as String?;
    Widget row(String label, String? value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(label, style: text.bodySmall?.copyWith(color: AppColors.inkMuted))),
        Expanded(child: Text(value ?? '—', style: text.bodyMedium?.copyWith(color: color, fontWeight: color != null ? FontWeight.w700 : null))),
      ]),
    );
    return SectionCard(
      color: problem != null ? AppColors.offerRedSoft : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WhatsApp Business', style: text.titleSmall),
        const SizedBox(height: 6),
        if (problem != null) Text(problem, style: text.bodyMedium?.copyWith(color: AppColors.offerRed)),
        if (number != null) ...[
          row('Sends from', number['displayPhoneNumber'] as String?),
          row('Name', [number['verifiedName'], if (number['nameStatus'] != null) '(${(number['nameStatus'] as String).toLowerCase().replaceAll('_', ' ')})'].whereType<String>().join(' ')),
          row('Quality', (number['qualityRating'] as String?)?.toLowerCase()),
        ],
        row(
          'Template',
          templates.isEmpty ? '${status['template']} — not found' : [for (final t in templates) '${t['name']} (${t['language']}): ${(t['status'] as String).toLowerCase()}'].join(', '),
          color: templates.isEmpty ? AppColors.offerRed : (approved ? AppColors.green700 : AppColors.amber),
        ),
      ]),
    );
  }
}
