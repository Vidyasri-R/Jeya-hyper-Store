import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Free-tier budget: what each service has used this month, what the bill will be, and alerts.
class UsageScreen extends ConsumerStatefulWidget {
  const UsageScreen({super.key});

  @override
  ConsumerState<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends ConsumerState<UsageScreen> {
  Map<String, dynamic>? _report;
  String? _error;
  bool _measuring = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final report = await ref.read(repositoryProvider).usage();
      if (mounted) {
        setState(() {
          _report = report;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _measureNow() async {
    setState(() => _measuring = true);
    final report = await guard(context, () => ref.read(repositoryProvider).refreshUsage());
    if (!mounted) return;
    setState(() {
      _measuring = false;
      if (report != null) _report = report;
    });
    ref.read(boardProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage & bills'),
        actions: [
          TextButton.icon(
            onPressed: _measuring ? null : _measureNow,
            icon: _measuring ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.speed_rounded),
            label: const Text('Measure now'),
          ),
        ],
      ),
      body: r == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(onRefresh: _load, child: _content(context, r)),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> r) {
    final text = Theme.of(context).textTheme;
    final totals = Map<String, dynamic>.from(r['totals'] as Map);
    final alerts = [for (final a in r['alerts'] as List) Map<String, dynamic>.from(a as Map)];
    final services = [for (final s in r['services'] as List) Map<String, dynamic>.from(s as Map)];
    final email = (r['notifications'] as Map?)?['email'] == true;
    final health = Map<String, dynamic>.from((r['health'] as Map?)?['catalogSync'] as Map? ?? const {});
    final tables = [for (final t in (r['largestTables'] as List? ?? const [])) Map<String, dynamic>.from(t as Map)];
    final hostingUsd = (totals['hostingUsd'] as num).toDouble();
    final overBudget = hostingUsd > 7.0001;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          color: overBudget ? AppColors.offerRed : AppColors.green800,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_monthName(r['month'] as String)} · day ${(r['daysElapsed'] as num).floor() + 1} of ${r['daysInMonth']}',
                style: text.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text('Expected hosting bill', style: text.bodyMedium?.copyWith(color: Colors.white)),
              Text(
                '\$${hostingUsd.toStringAsFixed(2)}  ·  ≈ ₹${formatCount(totals['hostingInr'] as num)}',
                style: text.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                overBudget ? 'Above the \$7 plan — see the red items below.' : 'On budget: Render \$7 + Supabase free + R2 free.',
                style: text.bodySmall?.copyWith(color: Colors.white70),
              ),
              const Divider(color: Colors.white24, height: 22),
              Text('Razorpay fees so far: ₹${formatCount(totals['paymentFeesInr'] as num)}', style: text.bodyMedium?.copyWith(color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          color: email ? AppColors.green50 : AppColors.amberSoft,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(email ? Icons.mark_email_read_outlined : Icons.notifications_active_outlined, color: email ? AppColors.green700 : const Color(0xFF8A5A00)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  email
                      ? 'Alerts and a 9 AM daily summary are emailed to the admin.'
                      : 'Alerts show here and on the Orders tab. To also get them by email, add the SMTP settings on Render (see the setup notes).',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
        if (alerts.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Needs attention', style: text.titleMedium),
          const SizedBox(height: 8),
          for (final a in alerts)
            _AlertCard(
              alert: a,
              onAck: () async {
                await guard(context, () => ref.read(repositoryProvider).acknowledgeAlert((a['id'] as num).toInt()));
                _load();
              },
            ),
        ],
        if (health['level'] != null && health['level'] != 'ok') ...[
          const SizedBox(height: 10),
          SectionCard(
            color: levelColors(health['level'] as String).$2,
            child: Text(health['message'] as String, style: text.bodyMedium),
          ),
        ],
        const SizedBox(height: 18),
        _BackupCard(
          status: Map<String, dynamic>.from((r['backups'] as Map?) ?? const {}),
          health: Map<String, dynamic>.from((r['health'] as Map?)?['backups'] as Map? ?? const {}),
          onBackUp: () async {
            final status = await guard(context, () => ref.read(repositoryProvider).runBackup());
            if (status != null && context.mounted) showSnack(context, 'Backup saved');
            await _load();
          },
        ),
        const SizedBox(height: 12),
        for (final s in services) ...[_ServiceCard(service: s), const SizedBox(height: 12)],
        if (tables.isNotEmpty)
          SectionCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              shape: const Border(),
              title: Text('What uses the database space', style: text.titleSmall),
              children: [
                for (final t in tables)
                  ListTile(
                    dense: true,
                    title: Text(t['name'] as String),
                    subtitle: Text('${formatCount(t['rows'] as num)} rows'),
                    trailing: Text(formatBytes(t['bytes'] as num), style: text.titleSmall),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Measured by the server itself (bytes on the wire, every 5 minutes). Provider dashboards remain the final word for billing.',
          style: text.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  static String _monthName(String yyyyMm) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final parts = yyyyMm.split('-');
    return '${months[int.parse(parts[1]) - 1]} ${parts[0]}';
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onAck});
  final Map<String, dynamic> alert;
  final VoidCallback onAck;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final level = alert['level'] as String;
    final (fg, bg) = levelColors(level);
    final acked = alert['acknowledgedAt'] != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        color: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(level == 'critical' ? Icons.error_rounded : Icons.warning_amber_rounded, color: fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(alert['title'] as String, style: text.titleSmall?.copyWith(color: fg)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(alert['message'] as String, style: text.bodySmall?.copyWith(color: AppColors.ink)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Since ${ago(DateTime.parse(alert['createdAt'] as String).toLocal())}', style: text.labelSmall),
                const Spacer(),
                if (!acked) TextButton(onPressed: onAck, child: const Text('Got it')) else Text('Seen', style: text.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});
  final Map<String, dynamic> service;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final metrics = [for (final m in service['metrics'] as List) Map<String, dynamic>.from(m as Map)];
    final notes = [for (final n in service['notes'] as List) n.toString()];
    final isRazorpay = service['id'] == 'razorpay';
    final projected = (service['costProjectedUsd'] as num).toDouble();
    final costLine = isRazorpay ? '₹${formatCount(service['costInr'] as num)} so far' : '\$${projected.toStringAsFixed(2)} this month';
    final worst = metrics.map((m) => m['level'] as String).fold<String>('ok', (a, b) => _rank(b) > _rank(a) ? b : a);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(service['name'] as String, style: text.titleMedium)),
              if (worst != 'ok') Pill(worst == 'critical' ? 'Act now' : 'Watch', fg: levelColors(worst).$1, bg: levelColors(worst).$2),
            ],
          ),
          Text('${service['plan']}  ·  $costLine', style: text.bodySmall),
          for (final m in metrics) _MetricRow(metric: m),
          if (notes.isNotEmpty) const SizedBox(height: 8),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(n, style: text.bodySmall),
            ),
        ],
      ),
    );
  }

  static int _rank(String level) => switch (level) {
    'critical' => 3,
    'warning' => 2,
    'info' => 1,
    _ => 0,
  };
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});
  final Map<String, dynamic> metric;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final used = metric['used'] as num?;
    final limit = metric['limit'] as num;
    final percent = (metric['percent'] as num?)?.toDouble();
    final projected = metric['projected'] as num?;
    final level = metric['level'] as String;
    final bytes = metric['unit'] == 'bytes';
    // RAM limits are binary (Render's "512 MB" = 512 MiB); everything else is billed in decimal units.
    final binary = (metric['id'] as String?)?.endsWith('memory') == true;
    String fmt(num n) => binary ? '${(n / (1024 * 1024)).toStringAsFixed(0)} MB' : (bytes ? formatBytes(n) : formatCount(n));
    final (fg, _) = levelColors(level);
    final color = level == 'ok' ? AppColors.green600 : fg;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(metric['label'] as String, style: text.titleSmall)),
              Text(used == null ? 'not measured' : '${fmt(used)} of ${fmt(limit)}', style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent == null ? 0 : (percent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.line,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                percent == null ? '' : '${percent.toStringAsFixed(percent < 10 ? 1 : 0)}% used',
                style: text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (projected != null) Text('month end ≈ ${fmt(projected)}', style: text.labelSmall),
            ],
          ),
          if ((metric['note'] as String?)?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(metric['note'] as String, style: text.labelSmall),
            ),
        ],
      ),
    );
  }
}

/// Nightly database backup (Supabase Free keeps none): when it last ran, its size, and a manual run.
class _BackupCard extends StatefulWidget {
  const _BackupCard({required this.status, required this.health, required this.onBackUp});
  final Map<String, dynamic> status;
  final Map<String, dynamic> health;
  final Future<void> Function() onBackUp;

  @override
  State<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<_BackupCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final level = widget.health['level'] as String? ?? 'ok';
    final (fg, bg) = levelColors(level == 'ok' ? null : level);
    final last = widget.status['last'] as Map?;
    final lastAt = widget.status['lastSuccessAt'] as String?;
    final configured = widget.status['configured'] == true;
    return SectionCard(
      color: level == 'ok' ? null : bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(level == 'ok' ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, color: level == 'ok' ? AppColors.green700 : fg),
              const SizedBox(width: 8),
              Expanded(child: Text('Database backup', style: text.titleMedium)),
              if (configured)
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await widget.onBackUp();
                          if (mounted) setState(() => _busy = false);
                        },
                  icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.backup_outlined),
                  label: const Text('Back up now'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            lastAt != null
                ? 'Last backup ${ago(DateTime.parse(lastAt).toLocal())}${last != null ? ' · ${last['kind']} · ${formatBytes(last['bytes'] as num)}' : ''}'
                : 'No backup yet',
            style: text.bodyMedium,
          ),
          if ((widget.health['message'] as String?)?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(widget.health['message'] as String, style: text.bodySmall?.copyWith(color: level == 'ok' ? null : fg)),
            ),
          const SizedBox(height: 4),
          Text('Every night at 2 AM to a private Cloudflare R2 bucket; kept 100 days.', style: text.labelSmall),
        ],
      ),
    );
  }
}
