import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/order_alerts.dart';
import '../core/theme.dart';
import '../state/providers.dart';
import 'common.dart';

/// Turn on / off ringing for new orders while the app is closed. [compact]: the order board's
/// reminder — shown only while alerts are off, and it can be hidden for this visit.
class OrderAlertsCard extends ConsumerStatefulWidget {
  const OrderAlertsCard({super.key, this.compact = false});
  final bool compact;

  @override
  ConsumerState<OrderAlertsCard> createState() => _OrderAlertsCardState();
}

/// The board reminder was closed (until the app restarts).
bool _reminderClosed = false;

class _OrderAlertsCardState extends ConsumerState<OrderAlertsCard> {
  AlertStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await OrderAlerts.status(ref.read(repositoryProvider));
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) setState(() => _status = (support: AlertSupport.unsupported, on: false, blocked: false));
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showSnack(context, done);
    } on AlertException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.friendly, error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not change order alerts: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final text = Theme.of(context).textTheme;
    if (status == null || status.support == AlertSupport.unsupported) return const SizedBox.shrink();
    if (widget.compact && (status.on || _reminderClosed)) return const SizedBox.shrink();
    final repo = ref.read(repositoryProvider);

    final String title;
    final String body;
    Widget? action;
    if (status.support == AlertSupport.needsHomeScreen) {
      title = 'Order alerts on iPhone';
      body = 'To ring for new orders when Safari is closed: tap Share → "Add to Home Screen", open Jeya Staff from the Home Screen, and turn on alerts there.';
    } else if (status.on) {
      title = 'Order alerts are on';
      body = kIsWeb
          ? 'This device shows a notification with sound for every new order, even when Jeya Staff is closed.'
          : 'This phone rings for every new order, even when the app is closed. The ring repeats until you open the alert.';
      action = TextButton(onPressed: _busy ? null : () => _run(() => OrderAlerts.disable(repo), 'Order alerts turned off on this device'), child: const Text('Turn off'));
    } else if (status.blocked) {
      title = 'Notifications are blocked';
      body = kIsWeb
          ? 'Allow notifications for Jeya Staff in the browser or phone settings to hear new orders when the app is closed.'
          : 'Allow notifications for Jeya Staff (phone Settings → Apps → Jeya Staff → Notifications) to hear new orders when the app is closed.';
      action = OutlinedButton(onPressed: _busy ? null : () => _run(() => OrderAlerts.enable(repo), 'Order alerts are on'), child: const Text('Try again'));
    } else {
      title = 'Ring for new orders when the app is closed';
      body = kIsWeb
          ? 'Get a notification with sound for every new order, even when this page is closed.'
          : 'This phone rings for every new order, even when Jeya Staff is closed (it keeps a small "Ready for new orders" notification).';
      action = FilledButton.icon(
        onPressed: _busy ? null : () => _run(() => OrderAlerts.enable(repo), 'Order alerts are on — new orders ring on this device'),
        icon: const Icon(Icons.notifications_active_outlined),
        label: const Text('Turn on'),
      );
    }

    final content = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(status.on ? Icons.notifications_active_rounded : Icons.notifications_off_outlined, color: status.on ? AppColors.green700 : const Color(0xFF8A5A00)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: text.titleSmall),
          const SizedBox(height: 2),
          Text(body, style: text.bodySmall),
          if (action != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              action,
              if (_busy) ...[const SizedBox(width: 12), const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))],
            ]),
          ],
        ]),
      ),
      if (widget.compact)
        IconButton(
          tooltip: 'Not now',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: () => setState(() => _reminderClosed = true),
        ),
    ]);

    return widget.compact
        ? Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: content,
          )
        : SectionCard(child: content);
  }
}
