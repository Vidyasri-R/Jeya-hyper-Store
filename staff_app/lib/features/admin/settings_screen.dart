import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Store settings the customer app reads (within a minute of saving).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic>? _settings;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await ref.read(repositoryProvider).settings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<bool> _save(String key, Object? value, String done) async {
    final saved = await guard(context, () => ref.read(repositoryProvider).saveSetting(key, value));
    if (saved == null && value != null) return false;
    if (!mounted) return true;
    setState(() => _settings = {...?_settings, key: saved});
    showSnack(context, done);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Store settings')),
      body: s == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StoreInfoCard(value: Map<String, dynamic>.from(s['store.info'] as Map), onSave: (v) => _save('store.info', v, 'Store details saved')),
                const SizedBox(height: 14),
                _DeliveryCard(
                  value: Map<String, dynamic>.from(s['delivery.rules'] as Map),
                  onSave: (v) => _save('delivery.rules', v, 'Delivery charges saved'),
                ),
                const SizedBox(height: 14),
                _PaymentsCard(
                  value: Map<String, dynamic>.from(s['checkout.payment_methods'] as Map),
                  onSave: (v) => _save('checkout.payment_methods', v, 'Payment options saved'),
                ),
                const SizedBox(height: 14),
                _MaintenanceCard(value: Map<String, dynamic>.from(s['app.maintenance'] as Map), onSave: (v) => _save('app.maintenance', v, 'Saved')),
                const SizedBox(height: 14),
                _DemoLoginCard(
                  enabled: s['auth.demo_login_enabled'] == true,
                  onSave: (v) => _save('auth.demo_login_enabled', v, v ? 'Reviewer login ON' : 'Reviewer login OFF'),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleMedium),
          Text(subtitle, style: text.bodySmall),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

final _money = [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,6}(\.\d{0,2})?'))];
final _decimal = [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,1})?'))];

String _asMoney(String text) {
  final t = text.trim();
  if (t.isEmpty) return '0.00';
  final parts = t.split('.');
  return '${parts[0].isEmpty ? '0' : parts[0]}.${(parts.length > 1 ? parts[1] : '').padRight(2, '0').substring(0, 2)}';
}

String _plainMoney(Object? value) {
  final s = value?.toString() ?? '';
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

class _StoreInfoCard extends StatefulWidget {
  const _StoreInfoCard({required this.value, required this.onSave});
  final Map<String, dynamic> value;
  final Future<bool> Function(Map<String, dynamic>) onSave;

  @override
  State<_StoreInfoCard> createState() => _StoreInfoCardState();
}

class _StoreInfoCardState extends State<_StoreInfoCard> {
  late final _name = TextEditingController(text: widget.value['name'] as String? ?? '');
  late final _city = TextEditingController(text: widget.value['city'] as String? ?? '');
  late final _phone = TextEditingController(text: _local(widget.value['supportPhone']));
  late final _whatsapp = TextEditingController(text: _local(widget.value['supportWhatsApp']));
  late final _address = TextEditingController(text: widget.value['address'] as String? ?? '');
  late final _hours = TextEditingController(text: widget.value['openingHours'] as String? ?? '');
  bool _busy = false;

  static String _local(Object? phone) {
    final p = phone?.toString() ?? '';
    return p.startsWith('91') && p.length == 12 ? p.substring(2) : p;
  }

  @override
  void dispose() {
    for (final c in [_name, _city, _phone, _whatsapp, _address, _hours]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Card(
    title: 'Store details',
    subtitle: 'Shown on the customer app\'s Help and order screens.',
    children: [
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Store name'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _city,
        decoration: const InputDecoration(labelText: 'City'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Support phone', prefixText: '+91 '),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _whatsapp,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'WhatsApp number', prefixText: '+91 '),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _address,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Store address (optional)'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _hours,
        decoration: const InputDecoration(labelText: 'Opening hours (optional)', hintText: 'e.g. 7 AM – 10 PM, all days'),
      ),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                await widget.onSave({
                  'name': _name.text.trim(),
                  'city': _city.text.trim(),
                  'supportPhone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                  'supportWhatsApp': _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
                  'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
                  'openingHours': _hours.text.trim().isEmpty ? null : _hours.text.trim(),
                });
                if (mounted) setState(() => _busy = false);
              },
        child: const Text('Save store details'),
      ),
    ],
  );
}

class _DeliveryCard extends StatefulWidget {
  const _DeliveryCard({required this.value, required this.onSave});
  final Map<String, dynamic> value;
  final Future<bool> Function(Map<String, dynamic>) onSave;

  @override
  State<_DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<_DeliveryCard> {
  late final _freeAbove = TextEditingController(text: _plainMoney(widget.value['freeDeliveryAbove']));
  late final _minOrder = TextEditingController(text: _plainMoney(widget.value['minOrderAmount']));
  late final _maxKm = TextEditingController(text: '${widget.value['maxDistanceKm'] ?? ''}');
  late final List<(TextEditingController, TextEditingController)> _tiers = [
    for (final t in (widget.value['tiers'] as List? ?? const []))
      (TextEditingController(text: '${(t as Map)['upToKm']}'), TextEditingController(text: _plainMoney(t['fee']))),
  ];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_freeAbove, _minOrder, _maxKm]) {
      c.dispose();
    }
    for (final (a, b) in _tiers) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? _build() {
    final tiers = <Map<String, dynamic>>[];
    double last = 0;
    for (final (km, fee) in _tiers) {
      final upTo = double.tryParse(km.text.trim());
      if (upTo == null || upTo <= last) {
        _error = 'Distances must go up: e.g. 3, 6, 10 km';
        return null;
      }
      last = upTo;
      tiers.add({'upToKm': upTo, 'fee': _asMoney(fee.text)});
    }
    final maxKm = double.tryParse(_maxKm.text.trim());
    if (tiers.isEmpty || maxKm == null || maxKm <= 0) {
      _error = 'Add at least one distance band and the maximum distance';
      return null;
    }
    _error = null;
    return {
      ...widget.value,
      'freeDeliveryAbove': _freeAbove.text.trim().isEmpty ? null : _asMoney(_freeAbove.text),
      'minOrderAmount': _asMoney(_minOrder.text),
      'maxDistanceKm': maxKm,
      'tiers': tiers,
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Card(
      title: 'Delivery charges',
      subtitle: 'Free above the amount below; otherwise by road distance from the shop.',
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _freeAbove,
                inputFormatters: _money,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Free delivery above', prefixText: '₹ '),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _minOrder,
                inputFormatters: _money,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minimum order', prefixText: '₹ '),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Charge by distance', style: text.titleSmall),
        const SizedBox(height: 6),
        for (final (i, (km, fee)) in _tiers.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: km,
                    inputFormatters: _decimal,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: i == 0 ? 'Up to (km)' : 'Up to (km)', suffixText: 'km', isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: fee,
                    inputFormatters: _money,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Fee', prefixText: '₹ ', isDense: true),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove band',
                  onPressed: _tiers.length <= 1 ? null : () => setState(() => _tiers.removeAt(i)),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _tiers.add((TextEditingController(), TextEditingController()))),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add distance band'),
          ),
        ),
        TextField(
          controller: _maxKm,
          inputFormatters: _decimal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Don\'t deliver beyond', suffixText: 'km'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: text.bodySmall?.copyWith(color: AppColors.offerRed)),
          ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final value = _build();
                  if (value == null) return setState(() {});
                  setState(() => _busy = true);
                  await widget.onSave(value);
                  if (mounted) setState(() => _busy = false);
                },
          child: const Text('Save delivery charges'),
        ),
      ],
    );
  }
}

class _PaymentsCard extends StatefulWidget {
  const _PaymentsCard({required this.value, required this.onSave});
  final Map<String, dynamic> value;
  final Future<bool> Function(Map<String, dynamic>) onSave;

  @override
  State<_PaymentsCard> createState() => _PaymentsCardState();
}

class _PaymentsCardState extends State<_PaymentsCard> {
  late bool _cod = widget.value['cod'] == true;
  late bool _online = widget.value['online'] == true;

  Future<void> _set({bool? cod, bool? online}) async {
    final next = {'cod': cod ?? _cod, 'online': online ?? _online};
    if (await widget.onSave(next) && mounted) {
      setState(() {
        _cod = next['cod']!;
        _online = next['online']!;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _Card(
    title: 'Payment options',
    subtitle: 'What customers can choose at checkout. Keep at least one on.',
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _cod,
        onChanged: (v) => _set(cod: v),
        title: const Text('Cash on delivery'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _online,
        onChanged: (v) => _set(online: v),
        title: const Text('Pay online (UPI, cards — Razorpay)'),
      ),
    ],
  );
}

class _MaintenanceCard extends StatefulWidget {
  const _MaintenanceCard({required this.value, required this.onSave});
  final Map<String, dynamic> value;
  final Future<bool> Function(Map<String, dynamic>) onSave;

  @override
  State<_MaintenanceCard> createState() => _MaintenanceCardState();
}

class _MaintenanceCardState extends State<_MaintenanceCard> {
  late bool _enabled = widget.value['enabled'] == true;
  late final _message = TextEditingController(text: widget.value['message'] as String? ?? '');

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Card(
    title: 'Pause orders',
    subtitle: 'Shows a message in the customer app and stops checkout (holidays, stock-taking).',
    children: [
      TextField(
        controller: _message,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Message to customers', hintText: 'e.g. Closed today for Pongal. Back tomorrow!'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _enabled,
        title: Text(_enabled ? 'Orders are paused' : 'Orders are open'),
        onChanged: (v) async {
          if (await widget.onSave({'enabled': v, 'message': _message.text.trim()}) && mounted) setState(() => _enabled = v);
        },
      ),
    ],
  );
}

class _DemoLoginCard extends StatelessWidget {
  const _DemoLoginCard({required this.enabled, required this.onSave});
  final bool enabled;
  final Future<bool> Function(bool) onSave;

  @override
  Widget build(BuildContext context) => _Card(
    title: 'App store reviewer login',
    subtitle: 'Lets Apple/Google reviewers sign in with 99999 99999 / OTP 123456. Turn OFF after the apps are approved.',
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: enabled,
        onChanged: onSave,
        title: Text(enabled ? 'Reviewer login is ON' : 'Reviewer login is OFF'),
      ),
    ],
  );
}
