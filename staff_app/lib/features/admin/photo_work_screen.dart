import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → Photo work: how many products still need photos, who is working on which, and
/// "give N more" in priority order (fast movers and daily needs first).
class PhotoWorkScreen extends ConsumerStatefulWidget {
  const PhotoWorkScreen({super.key});

  @override
  ConsumerState<PhotoWorkScreen> createState() => _PhotoWorkScreenState();
}

class _PhotoWorkScreenState extends ConsumerState<PhotoWorkScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(repositoryProvider).photoWork();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _assign(Map<String, dynamic> person) async {
    final count = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Give ${person['name']} more products'),
        children: [
          for (final n in [25, 50, 100, 200])
            SimpleDialogOption(onPressed: () => Navigator.pop(context, n), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('$n products (most important first)'))),
        ],
      ),
    );
    if (count == null || !mounted) return;
    final n = await guard(context, () => ref.read(repositoryProvider).assignPhotos(person['staffId'] as String, count));
    if (n == null || !mounted) return;
    showSnack(context, n == 0 ? 'No unassigned products left' : '$n products given to ${person['name']}');
    await _load();
  }

  Future<void> _release(Map<String, dynamic> person) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Take back ${person['name']}\'s unfinished products?'),
        content: const Text('Their open products go back to the unassigned list. Photos already added stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Take back')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final n = await guard(context, () => ref.read(repositoryProvider).unassignPhotos(person['staffId'] as String));
    if (n != null && mounted) showSnack(context, '$n products are unassigned again');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo work'),
        actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))],
      ),
      body: d == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _Totals(totals: Map<String, dynamic>.from(d['totals'] as Map)),
                const SizedBox(height: 16),
                Text('People', style: text.titleMedium),
                Text('Give each person a batch; they see it under Photos → My photos and the list shrinks as they add pictures.', style: text.bodySmall),
                const SizedBox(height: 8),
                for (final raw in d['people'] as List)
                  _PersonCard(
                    person: Map<String, dynamic>.from(raw as Map),
                    onAssign: () => _assign(Map<String, dynamic>.from(raw)),
                    onRelease: () => _release(Map<String, dynamic>.from(raw)),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go('/more/staff'),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add a photo helper (Staff accounts → role "Photo helper")'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => context.go('/my-photos'), icon: const Icon(Icons.photo_camera_outlined), label: const Text('My own photo list')),
              ]),
            ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals});
  final Map<String, dynamic> totals;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    int n(String k) => (totals[k] as num? ?? 0).toInt();
    final active = n('active'), withPhoto = n('withPhoto');
    final pct = active == 0 ? 0.0 : withPhoto / active;
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${(pct * 100).toStringAsFixed(1)}% of products have photos', style: text.titleMedium),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: pct, minHeight: 10, backgroundColor: AppColors.line, color: AppColors.green700)),
        const SizedBox(height: 10),
        Wrap(spacing: 18, runSpacing: 6, children: [
          _Stat('With photo', withPhoto, AppColors.green700),
          _Stat('Without photo', n('withoutPhoto'), AppColors.offerRed),
          _Stat('Not given to anyone', n('unassigned'), AppColors.inkMuted),
          _Stat('Added today', n('today'), AppColors.brandBlue),
        ]),
        const SizedBox(height: 6),
        Text('Products without photos show their category picture in the shop meanwhile.', style: text.bodySmall),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(NumberFormat.decimalPattern('en_IN').format(value), style: text.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
      Text(label, style: text.bodySmall),
    ]);
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.onAssign, required this.onRelease});
  final Map<String, dynamic> person;
  final VoidCallback onAssign;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    int n(String k) => (person[k] as num? ?? 0).toInt();
    final open = n('open'), done = n('done'), today = n('doneToday');
    final last = DateTime.tryParse(person['lastPhotoAt'] as String? ?? '')?.toLocal();
    final role = switch (person['role']) { 'admin' => 'Admin', 'photos' => 'Photo helper', _ => 'Staff' };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${person['name']}', style: text.titleSmall)),
            Pill(role, fg: AppColors.inkMuted, bg: AppColors.bg),
          ]),
          const SizedBox(height: 4),
          Text(
            [
              open == 0 ? 'Nothing open' : '$open to do',
              '$done done',
              if (today > 0) '$today today',
              if (last != null) 'last ${DateFormat('d MMM, h:mm a').format(last)}',
            ].join(' · '),
            style: text.bodySmall,
          ),
          Wrap(children: [
            TextButton.icon(onPressed: onAssign, icon: const Icon(Icons.playlist_add_rounded), label: const Text('Give more')),
            if (open > 0) TextButton.icon(onPressed: onRelease, icon: const Icon(Icons.undo_rounded), label: const Text('Take back')),
          ]),
        ]),
      ),
    );
  }
}
