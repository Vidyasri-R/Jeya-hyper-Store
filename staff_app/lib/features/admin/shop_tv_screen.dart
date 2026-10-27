import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/pick_file.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → Shop TV: the ads the shop TV plays between the CCTV pictures (and the shop phone plays
/// through the speakers), the TVs, and the break rules.
class ShopTvScreen extends ConsumerStatefulWidget {
  const ShopTvScreen({super.key});

  @override
  ConsumerState<ShopTvScreen> createState() => _ShopTvScreenState();
}

/// File extension → content type the server accepts.
const _types = {
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
};

class _ShopTvScreenState extends ConsumerState<ShopTvScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  double? _uploading;
  String? _uploadName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await ref.read(repositoryProvider).shopTv();
      if (mounted) setState(() => _data = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _upload() async {
    final file = await pickFile('mp4', also: _types.keys.where((k) => k != 'mp4').toList());
    if (file == null || !mounted) return;
    final ext = file.name.split('.').last.toLowerCase();
    final type = _types[ext];
    if (type == null) return showSnack(context, 'Use an MP4 video, a JPG/PNG poster or an MP3/M4A sound', error: true);
    final title = await _askText(context, title: 'Name for this ad', initial: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''), hint: 'e.g. Deepavali offer');
    if (title == null || !mounted) return;
    setState(() {
      _uploading = 0;
      _uploadName = title;
    });
    final media = await guard(
      context,
      () => ref.read(repositoryProvider).uploadShopMedia(
            file.bytes,
            type,
            title: title,
            kind: type.startsWith('audio/') ? 'announcement' : 'ad',
            onProgress: (p) {
              if (mounted) setState(() => _uploading = p);
            },
          ),
    );
    if (!mounted) return;
    setState(() => _uploading = null);
    if (media != null) {
      showSnack(context, '“$title” added — the TV picks it up within a minute');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shop TV'),
          actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))],
          bottom: const TabBar(tabs: [Tab(text: 'Ads'), Tab(text: 'TVs'), Tab(text: 'Rules')]),
        ),
        floatingActionButton: d == null || _uploading != null
            ? null
            : FloatingActionButton.extended(onPressed: _upload, icon: const Icon(Icons.upload_rounded), label: const Text('Add ad')),
        body: _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : d == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                _AdsTab(data: d, uploading: _uploading, uploadName: _uploadName, onChanged: _load),
                _TvsTab(data: d, onChanged: _load),
                _RulesTab(settings: Map<String, dynamic>.from(d['settings'] as Map), onSaved: _load),
              ]),
      ),
    );
  }
}

/* ── Ads ── */

class _AdsTab extends ConsumerWidget {
  const _AdsTab({required this.data, required this.uploading, required this.uploadName, required this.onChanged});
  final Map<String, dynamic> data;
  final double? uploading;
  final String? uploadName;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final media = [for (final m in data['media'] as List) Map<String, dynamic>.from(m as Map)];
    final next = data['nextBreak'] as Map?;
    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
        if (next != null)
          SectionCard(
            color: AppColors.green50,
            child: Row(children: [
              const Icon(Icons.schedule_rounded, color: AppColors.green700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Next ad break at ${DateFormat('h:mm:ss a').format(DateTime.fromMillisecondsSinceEpoch(next['at'] as int))}',
                  style: text.titleSmall,
                ),
              ),
            ]),
          ),
        if (uploading != null) ...[
          const SizedBox(height: 10),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Uploading “$uploadName”… ${(uploading! * 100).round()}%', style: text.bodyMedium),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: uploading),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'Videos (16:9 or 9:16 Reels), posters and announcements. Each break plays 1–2 of the ads that are on, in turn.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 10),
        if (media.isEmpty)
          const EmptyView(icon: Icons.tv_rounded, title: 'No ads yet', subtitle: 'Tap “Add ad” to upload a video, poster or announcement.'),
        for (var i = 0; i < media.length; i++)
          _AdTile(
            media: media[i],
            first: i == 0,
            last: i == media.length - 1,
            onMove: (up) async {
              final other = media[up ? i - 1 : i + 1];
              final repo = ref.read(repositoryProvider);
              await guard(context, () async {
                await repo.updateShopMedia(media[i]['id'] as String, {'sortOrder': other['sortOrder']});
                await repo.updateShopMedia(other['id'] as String, {'sortOrder': media[i]['sortOrder']});
              });
              onChanged();
            },
            onChanged: onChanged,
          ),
      ]),
    );
  }
}

class _AdTile extends ConsumerWidget {
  const _AdTile({required this.media, required this.first, required this.last, required this.onMove, required this.onChanged});
  final Map<String, dynamic> media;
  final bool first;
  final bool last;
  final ValueChanged<bool> onMove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final type = media['mediaType'] as String;
    final aspect = (media['aspect'] as num?)?.toDouble();
    final ms = media['durationMs'] as int?;
    final details = [
      switch (type) {
        'video' => aspect == null ? 'Video' : (aspect < 1 ? 'Reel 9:16' : 'Video 16:9'),
        'image' => 'Poster',
        _ => 'Announcement (sound)',
      },
      if (ms != null && type != 'image') '${(ms / 1000).round()} s',
      '${((media['bytes'] as int) / 1024 / 1024).toStringAsFixed(1)} MB',
      if (media['startsOn'] != null || media['endsOn'] != null) '${media['startsOn'] ?? '…'} → ${media['endsOn'] ?? '…'}',
    ].join(' · ');
    final repo = ref.read(repositoryProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(children: [
          Icon(
            switch (type) { 'video' => Icons.movie_rounded, 'image' => Icons.image_rounded, _ => Icons.campaign_rounded },
            color: media['isActive'] == true ? AppColors.green700 : AppColors.inkFaint,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(media['title'] as String, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(details, style: text.bodySmall),
            ]),
          ),
          Switch(
            value: media['isActive'] == true,
            onChanged: (on) async {
              await guard(context, () => repo.updateShopMedia(media['id'] as String, {'isActive': on}));
              onChanged();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              switch (action) {
                case 'up' || 'down':
                  onMove(action == 'up');
                case 'rename':
                  final name = await _askText(context, title: 'Rename', initial: media['title'] as String);
                  if (name == null || !context.mounted) return;
                  await guard(context, () => repo.updateShopMedia(media['id'] as String, {'title': name}));
                  onChanged();
                case 'dates':
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    helpText: 'Show this ad between',
                  );
                  if (range == null || !context.mounted) return;
                  final f = DateFormat('yyyy-MM-dd');
                  await guard(context, () => repo.updateShopMedia(media['id'] as String, {'startsOn': f.format(range.start), 'endsOn': f.format(range.end)}));
                  onChanged();
                case 'always':
                  await guard(context, () => repo.updateShopMedia(media['id'] as String, {'startsOn': null, 'endsOn': null}));
                  onChanged();
                case 'delete':
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete this ad?'),
                      content: Text('“${media['title']}” is removed from the TV and the shop phone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  await guard(context, () => repo.deleteShopMedia(media['id'] as String));
                  onChanged();
              }
            },
            itemBuilder: (_) => [
              if (!first) const PopupMenuItem(value: 'up', child: Text('Move up')),
              if (!last) const PopupMenuItem(value: 'down', child: Text('Move down')),
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'dates', child: Text('Show only between dates…')),
              if (media['startsOn'] != null || media['endsOn'] != null) const PopupMenuItem(value: 'always', child: Text('Show every day')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ]),
      ),
    );
  }
}

/* ── TVs ── */

class _TvsTab extends ConsumerWidget {
  const _TvsTab({required this.data, required this.onChanged});
  final Map<String, dynamic> data;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final screens = [for (final s in data['screens'] as List) Map<String, dynamic>.from(s as Map)];
    final repo = ref.read(repositoryProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Add a TV', style: text.titleSmall),
          const SizedBox(height: 4),
          Text('Open the Jeya TV app on the TV. It shows a 6-digit code — type it here.', style: text.bodySmall),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              final code = await _askText(context, title: 'Code shown on the TV', hint: '6 digits', digits: true);
              if (code == null || !context.mounted) return;
              final name = await _askText(context, title: 'Name this TV', initial: screens.isEmpty ? 'Shop TV' : 'Shop TV ${screens.length + 1}');
              if (name == null || !context.mounted) return;
              final ok = await guard(context, () => repo.pairShopTv(code, name).then((_) => true));
              if (ok == true && context.mounted) showSnack(context, '“$name” added — it starts playing in a few seconds');
              onChanged();
            },
            icon: const Icon(Icons.add_to_queue_rounded),
            label: const Text('Add TV'),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      for (final s in screens)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Icon(Icons.tv_rounded, color: s['online'] == true ? AppColors.green700 : AppColors.inkFaint, size: 32),
            title: Text(s['name'] as String),
            subtitle: Text(_tvStatus(s), style: text.bodySmall),
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'rename') {
                  final name = await _askText(context, title: 'Rename', initial: s['name'] as String);
                  if (name == null || !context.mounted) return;
                  await guard(context, () => repo.renameShopTv(s['id'] as String, name));
                } else {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Remove this TV?'),
                      content: const Text('The TV stops playing ads and shows a new pairing code.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
                      ],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  await guard(context, () => repo.removeShopTv(s['id'] as String));
                }
                onChanged();
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'rename', child: Text('Rename')), PopupMenuItem(value: 'remove', child: Text('Remove'))],
            ),
          ),
        ),
    ]);
  }

  String _tvStatus(Map<String, dynamic> s) {
    final status = (s['status'] as Map?) ?? const {};
    final seen = s['lastSeenAt'] == null ? null : DateTime.parse(s['lastSeenAt'] as String).toLocal();
    return [
      s['online'] == true ? 'Online' : 'Offline${seen == null ? '' : ' since ${DateFormat('d MMM, h:mm a').format(seen)}'}',
      if (status['mode'] == 'break') 'Playing: ${status['playing'] ?? 'ad'}' else if (s['online'] == true) 'Showing CCTV',
      if (status['cctvOk'] == false) 'CCTV not connected',
      if (status['cached'] != null) 'Ads saved ${status['cached']}/${status['total']}',
      if (s['appVersion'] != null) 'v${s['appVersion']}',
    ].join(' · ');
  }
}

/* ── Rules ── */

class _RulesTab extends ConsumerStatefulWidget {
  const _RulesTab({required this.settings, required this.onSaved});
  final Map<String, dynamic> settings;
  final VoidCallback onSaved;

  @override
  ConsumerState<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends ConsumerState<_RulesTab> {
  late final Map<String, dynamic> _s = _copy(widget.settings);
  bool _saving = false;

  static Map<String, dynamic> _copy(Map<String, dynamic> m) => {
        for (final e in m.entries) e.key: e.value is Map ? Map<String, dynamic>.from(e.value as Map) : (e.value is List ? List<dynamic>.from(e.value as List) : e.value),
      };

  Map<String, dynamic> _sub(String key) => _s[key] as Map<String, dynamic>;

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await guard(context, () => ref.read(repositoryProvider).setShopTvSettings(_s));
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) {
      showSnack(context, 'Saved — the TV and the shop phone use it within a minute');
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cctv = _sub('cctv');
    final panel = _sub('panel');
    Widget number(String label, int value, ValueChanged<int> onChanged, {int min = 0, int max = 999}) => _NumberField(label: label, value: value, min: min, max: max, onChanged: onChanged);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
      Text('Ad breaks', style: text.titleMedium),
      const SizedBox(height: 8),
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('A break every (minutes, random between)', style: text.bodySmall),
          Row(children: [
            Expanded(child: number('From', _sub('breakEveryMinutes')['min'] as int, (v) => setState(() => _sub('breakEveryMinutes')['min'] = v), min: 1, max: 180)),
            const SizedBox(width: 10),
            Expanded(child: number('To', _sub('breakEveryMinutes')['max'] as int, (v) => setState(() => _sub('breakEveryMinutes')['max'] = v), min: 1, max: 180)),
          ]),
          const SizedBox(height: 12),
          Text('Ads per break', style: text.bodySmall),
          Row(children: [
            Expanded(child: number('From', _sub('itemsPerBreak')['min'] as int, (v) => setState(() => _sub('itemsPerBreak')['min'] = v), min: 1, max: 6)),
            const SizedBox(width: 10),
            Expanded(child: number('To', _sub('itemsPerBreak')['max'] as int, (v) => setState(() => _sub('itemsPerBreak')['max'] = v), min: 1, max: 6)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _TimeField(label: 'Shop opens', value: _s['openTime'] as String, onChanged: (v) => setState(() => _s['openTime'] = v))),
            const SizedBox(width: 10),
            Expanded(child: _TimeField(label: 'Shop closes', value: _s['closeTime'] as String, onChanged: (v) => setState(() => _s['closeTime'] = v))),
          ]),
          const SizedBox(height: 12),
          number('Poster on screen (seconds)', _s['imageSeconds'] as int, (v) => setState(() => _s['imageSeconds'] = v), min: 3, max: 120),
        ]),
      ),
      const SizedBox(height: 16),
      Text('Sound', style: text.titleMedium),
      const SizedBox(height: 8),
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'phone', label: Text('Shop phone')),
              ButtonSegment(value: 'tv', label: Text('TV')),
              ButtonSegment(value: 'both', label: Text('Both')),
            ],
            selected: {_s['adSound'] as String},
            onSelectionChanged: (v) => setState(() => _s['adSound'] = v.first),
          ),
          const SizedBox(height: 6),
          Text('Where the ad sound plays. The shop phone (store app → Shop audio) pauses the music for every break either way.', style: text.bodySmall),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: number('TV volume %', _s['tvVolume'] as int, (v) => setState(() => _s['tvVolume'] = v), max: 100)),
            const SizedBox(width: 10),
            Expanded(child: number('Phone volume %', _s['phoneVolume'] as int, (v) => setState(() => _s['phoneVolume'] = v), max: 100)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Text('CCTV on the TV', style: text.titleMedium),
      const SizedBox(height: 8),
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'pages', label: Text('Camera pages')), ButtonSegment(value: 'composite', label: Text('Recorder grid'))],
            selected: {cctv['mode'] as String},
            onSelectionChanged: (v) => setState(() => cctv['mode'] = v.first),
          ),
          const SizedBox(height: 6),
          Text(
            cctv['mode'] == 'composite'
                ? 'The recorder’s own combined picture (its "zero channel"), like the HDMI screen today.'
                : 'The TV shows a page of cameras and turns to the next page every few seconds.',
            style: text.bodySmall,
          ),
          if (cctv['mode'] == 'pages') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: number('Cameras on the recorder', cctv['channelCount'] as int, (v) => setState(() => cctv['channelCount'] = v), min: 1, max: 64)),
              const SizedBox(width: 10),
              Expanded(child: number('Seconds per page', cctv['pageSeconds'] as int, (v) => setState(() => cctv['pageSeconds'] = v), min: 5, max: 300)),
            ]),
            const SizedBox(height: 12),
            Text('Cameras per page', style: text.bodySmall),
            const SizedBox(height: 4),
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 1, label: Text('1')), ButtonSegment(value: 4, label: Text('4')), ButtonSegment(value: 6, label: Text('6')), ButtonSegment(value: 9, label: Text('9'))],
              selected: {cctv['pageSize'] as int},
              onSelectionChanged: (v) => setState(() => cctv['pageSize'] = v.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: (cctv['cameras'] as List).join(', '),
              decoration: const InputDecoration(labelText: 'Only these cameras, in order (empty = all)', hintText: 'e.g. 1, 2, 5, 12'),
              keyboardType: TextInputType.text,
              onChanged: (v) => cctv['cameras'] = v.split(RegExp(r'[,\s]+')).map(int.tryParse).whereType<int>().where((n) => n >= 1 && n <= 64).toList(),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      Text('Panel next to 9:16 Reels', style: text.titleMedium),
      const SizedBox(height: 8),
      SectionCard(
        child: Column(children: [
          TextFormField(initialValue: panel['headline'] as String, maxLength: 60, decoration: const InputDecoration(labelText: 'Headline'), onChanged: (v) => panel['headline'] = v),
          TextFormField(initialValue: panel['offer'] as String, maxLength: 120, decoration: const InputDecoration(labelText: 'Offer line'), onChanged: (v) => panel['offer'] = v),
          TextFormField(initialValue: panel['qrUrl'] as String, decoration: const InputDecoration(labelText: 'QR code opens'), onChanged: (v) => panel['qrUrl'] = v.trim()),
        ]),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
        label: const Text('Save rules'),
      ),
    ]);
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.value, required this.onChanged, this.min = 0, this.max = 999});
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) onChanged(n.clamp(min, max));
        },
      );
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onChanged});
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: const Icon(Icons.schedule_rounded, size: 18),
        label: Text('$label  $value'),
        onPressed: () async {
          final parts = value.split(':');
          final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
          if (picked != null) onChanged('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        },
      );
}

Future<String?> _askText(BuildContext context, {required String title, String initial = '', String? hint, bool digits = false}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: digits ? TextInputType.number : TextInputType.text,
        inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)] : null,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(c, v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim().isEmpty ? null : controller.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}
