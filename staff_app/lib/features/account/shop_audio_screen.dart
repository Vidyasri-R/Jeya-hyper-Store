import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/order_alerts.dart';
import '../../core/shop_audio.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// More → Shop audio (on the shop's Android phone): the music the owner plays here pauses for every
/// ad break of the shop TV, and the ad's sound plays through the same speakers.
class ShopAudioScreen extends ConsumerStatefulWidget {
  const ShopAudioScreen({super.key});

  @override
  ConsumerState<ShopAudioScreen> createState() => _ShopAudioScreenState();
}

class _ShopAudioScreenState extends ConsumerState<ShopAudioScreen> {
  ShopAudioInfo? _info;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final info = await ShopAudio.status();
    if (mounted) setState(() => _info = info);
  }

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      on ? await ShopAudio.enable(repo) : await ShopAudio.disable(repo);
    } on AlertException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not change Shop audio: $e', error: true);
    }
    if (mounted) setState(() => _busy = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final info = _info;
    final status = info?.status;
    final next = status?['nextAt'] as int?;
    final last = status?['last'] as Map?;
    return Scaffold(
      appBar: AppBar(title: const Text('Shop audio')),
      body: info == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
              if (!info.supported)
                const SectionCard(color: AppColors.amberSoft, child: Text('Shop audio works in the Android store app on the shop’s music phone.'))
              else ...[
                SectionCard(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: info.on,
                    onChanged: _busy ? null : _toggle,
                    title: const Text('Play shop TV ads on this phone'),
                    subtitle: Text(
                      info.on
                          ? 'On — at every ad break your music pauses, the ad sound plays, then the music carries on.'
                          : 'Turn on for the phone that plays the shop’s music (Bluetooth to the speakers).',
                      style: text.bodySmall,
                    ),
                  ),
                ),
                if (info.on) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _row(text, Icons.schedule_rounded, next == null ? 'No ad break planned (outside shop hours or no ads)' : 'Next ad break at ${DateFormat('h:mm:ss a').format(DateTime.fromMillisecondsSinceEpoch(next))}'),
                      if (status?['playing'] != null) _row(text, Icons.volume_up_rounded, 'Playing: ${status!['playing']}'),
                      if (last != null) _row(text, Icons.history_rounded, 'Last: ${last['title']} at ${DateFormat('h:mm a').format(DateTime.parse(last['at'] as String))}'),
                      if (status?['ads'] != null) _row(text, Icons.download_done_rounded, '${status!['ads']} ad sound(s) saved on this phone'),
                      if (status?['error'] != null) _row(text, Icons.error_outline_rounded, '${status!['error']}', color: AppColors.offerRed),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          ShopAudio.test();
                          showSnack(context, 'Playing a test ad — your music should pause and come back');
                        },
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('Test now'),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Play music in any app (Spotify, YouTube Music…) as usual. Keep this phone charging and don’t swipe the store app away; '
                  'if Android asks, allow it to run in the background.',
                  style: text.bodySmall,
                ),
              ],
            ]),
    );
  }

  Widget _row(TextTheme text, IconData icon, String label, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: color ?? AppColors.green700),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: text.bodyMedium?.copyWith(color: color))),
        ]),
      );
}
