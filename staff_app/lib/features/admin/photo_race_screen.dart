import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

const _periods = [('today', 'Today'), ('week', 'This week'), ('all', 'All time')];

/// Gold, silver, bronze; then the brand green.
Color _medal(int rank) => switch (rank) {
  1 => const Color(0xFFE0A100),
  2 => const Color(0xFF8E9AA6),
  3 => const Color(0xFFB0662F),
  _ => AppColors.green700,
};

/// Each lane's car gets its own colour (by name, so it stays the same every day).
const _carColors = [Color(0xFFD32F2F), Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFF6A1B9A), Color(0xFFEF6C00), Color(0xFF00838F), Color(0xFFAD1457), Color(0xFF4E342E)];
Color _carColor(String name) => _carColors[name.codeUnits.fold(0, (a, b) => a + b) % _carColors.length];

String _firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

/// The photo race: every staff member sees who added the most product photos, as cars on a track.
class PhotoRaceScreen extends ConsumerStatefulWidget {
  const PhotoRaceScreen({super.key});

  @override
  ConsumerState<PhotoRaceScreen> createState() => _PhotoRaceScreenState();
}

class _PhotoRaceScreenState extends ConsumerState<PhotoRaceScreen> {
  String _period = 'week';
  List<Racer>? _racers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final racers = await ref.read(repositoryProvider).photoRace(_period);
      if (mounted) setState(() => _racers = racers);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final racers = _racers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo race 🏁'),
        actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          SegmentedButton<String>(
            segments: [for (final (key, label) in _periods) ButtonSegment(value: key, label: Text(label))],
            selected: {_period},
            onSelectionChanged: (v) {
              setState(() {
                _period = v.first;
                _racers = null;
              });
              _load();
            },
          ),
          const SizedBox(height: 14),
          if (_error != null)
            ErrorView(message: _error!, onRetry: _load)
          else if (racers == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (racers.isEmpty)
            EmptyView(
              icon: Icons.sports_score_rounded,
              title: _period == 'today' ? 'No photos yet today' : 'The race hasn\'t started',
              subtitle: 'The first photo takes the lead!',
            )
          else ...[
            _Headline(racers: racers, period: _period),
            const SizedBox(height: 14),
            for (final r in racers) _Lane(racer: r, leader: racers.first.photos),
            const SizedBox(height: 10),
            Text('Counts the product photos each person added that are in the shop now. Same score: whoever got there first is ahead.',
                style: text.bodySmall, textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.racers, required this.period});
  final List<Racer> racers;
  final String period;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final leader = racers.first;
    final me = racers.where((r) => r.isMe).firstOrNull;
    final when = switch (period) { 'today' => 'today', 'week' => 'this week', _ => 'so far' };
    final String cheer;
    if (me == null) {
      cheer = 'Add one photo to join the race!';
    } else if (me.rank == 1) {
      cheer = 'You\'re in the lead — keep going! 🏆';
    } else {
      final ahead = racers.lastWhere((r) => r.rank < me.rank);
      final gap = ahead.photos - me.photos + 1;
      cheer = '$gap more to pass ${_firstName(ahead.name)} and take #${ahead.rank}!';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(colors: [Color(0xFF14612F), Color(0xFF1B7A3E)]),
      ),
      child: Row(children: [
        const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD54F), size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_firstName(leader.name)} is leading $when with ${leader.photos} photos',
                style: text.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(cheer, style: text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
          ]),
        ),
      ]),
    );
  }
}

/// One racer: rank, name and score, then the track with their car driving towards the flag.
class _Lane extends StatelessWidget {
  const _Lane({required this.racer, required this.leader});
  final Racer racer;
  final int leader;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = racer;
    final share = leader == 0 ? 0.0 : r.photos / leader;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: r.isMe ? AppColors.green50 : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: r.isMe ? AppColors.green700 : AppColors.line, width: r.isMe ? 1.6 : 1),
      ),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: _medal(r.rank),
            child: Text('${r.rank}', style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(r.isMe ? '${r.name} (you)' : r.name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall?.copyWith(fontWeight: r.isMe ? FontWeight.w800 : FontWeight.w600)),
          ),
          Text('${r.photos}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: _medal(r.rank))),
          Text(' photos', style: text.bodySmall),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          child: LayoutBuilder(builder: (context, box) {
            const car = 30.0;
            const flag = 22.0;
            final run = (box.maxWidth - car - flag).clamp(0.0, double.infinity);
            return Stack(alignment: Alignment.centerLeft, children: [
              // The road: grey with a dashed centre line.
              Positioned(
                left: 0,
                right: flag,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(color: const Color(0xFFE3E7E5), borderRadius: BorderRadius.circular(7)),
                  alignment: Alignment.center,
                  child: Row(children: [for (var i = 0; i < 24; i++) Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 3), color: i.isEven ? Colors.white : Colors.transparent))]),
                ),
              ),
              const Positioned(right: 0, child: Icon(Icons.sports_score_rounded, size: flag, color: AppColors.ink)),
              // The car drives in from the start each time the race is shown.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: share),
                duration: Duration(milliseconds: 700 + (r.rank * 120).clamp(0, 900)),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => Positioned(
                  left: run * t,
                  child: Icon(Icons.directions_car_filled_rounded, size: car, color: _carColor(r.name)),
                ),
              ),
            ]);
          }),
        ),
      ]),
    );
  }
}

/// Small race card for My photos and Photo work: the top three and where I am; opens the race.
class PhotoRaceCard extends ConsumerStatefulWidget {
  const PhotoRaceCard({super.key});

  @override
  ConsumerState<PhotoRaceCard> createState() => _PhotoRaceCardState();
}

class _PhotoRaceCardState extends ConsumerState<PhotoRaceCard> {
  List<Racer>? _racers;

  @override
  void initState() {
    super.initState();
    ref.read(repositoryProvider).photoRace('today').then((r) {
      if (mounted) setState(() => _racers = r);
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final racers = _racers ?? const <Racer>[];
    final me = racers.where((r) => r.isMe).firstOrNull;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/race'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
          child: Row(children: [
            const Icon(Icons.sports_score_rounded, color: AppColors.green700, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Photo race — today', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  racers.isEmpty
                      ? 'Be the first to add a photo today!'
                      : [for (final r in racers.take(3)) '${r.rank}. ${_firstName(r.name)} ${r.photos}'].join('   '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
                if (me != null && me.rank > 3)
                  Text('You: #${me.rank} with ${me.photos}', style: text.labelMedium?.copyWith(color: AppColors.green700, fontWeight: FontWeight.w700)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }
}
