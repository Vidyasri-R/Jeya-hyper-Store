import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'order_detail_view.dart';

/// The store's order board: tabs by stage, oldest first, with a chime when new orders arrive.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> with SingleTickerProviderStateMixin {
  static const _tabs = BoardTab.values;
  late final TabController _tabController = TabController(length: _tabs.length, vsync: this);
  final _search = TextEditingController();
  bool _searching = false;
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(boardProvider);
    final summary = board.summary;
    final staff = ref.watch(currentStaffProvider);
    final wide = MediaQuery.sizeOf(context).width >= AppConfig.wideLayout;

    ref.listen(boardProvider.select((s) => s.newOrderAlert), (previous, next) {
      if (previous != null && next > previous && mounted) {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('🛒 New order received'),
              backgroundColor: AppColors.brandBlue,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(label: 'VIEW', textColor: Colors.white, onPressed: () => _tabController.animateTo(0)),
            ),
          );
      }
    });

    final list = Column(
      children: [
        if (staff?.isAdmin == true && summary != null && summary.alertsOpen > 0) _AlertBanner(summary: summary),
        if (board.error != null && summary == null)
          Expanded(
            child: ErrorView(message: board.error!, onRetry: () => ref.read(boardProvider.notifier).refresh()),
          )
        else if (_searching && _query.length >= 2)
          Expanded(
            child: OrderList(tab: 'all', query: _query, wide: wide),
          )
        else
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [for (final tab in _tabs) OrderList(tab: tab.key, wide: wide)],
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onQuery,
                decoration: const InputDecoration(
                  hintText: 'Order no., phone or name',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              )
            : const Text('Orders'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search orders',
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _searching = !_searching;
              _search.clear();
              _query = '';
            }),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(boardProvider.notifier).refresh();
              ref.invalidate(orderListRefreshProvider);
            },
          ),
        ],
        bottom: _searching
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.green800,
                unselectedLabelColor: AppColors.inkMuted,
                indicatorColor: AppColors.green700,
                tabs: [
                  for (final tab in _tabs)
                    Tab(
                      child: _TabLabel(tab: tab, summary: summary),
                    ),
                ],
              ),
      ),
      body: wide
          ? Row(
              children: [
                SizedBox(width: 440, child: list),
                const VerticalDivider(width: 1),
                Expanded(child: _SelectedOrderPane()),
              ],
            )
          : list,
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.tab, required this.summary});
  final BoardTab tab;
  final BoardSummary? summary;

  @override
  Widget build(BuildContext context) {
    final count = switch (tab) {
      BoardTab.delivered => summary?.counts['deliveredToday'] ?? 0,
      BoardTab.cancelled => 0,
      _ => summary?.count(tab) ?? 0,
    };
    final urgent = tab == BoardTab.newOrders && count > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tab == BoardTab.delivered ? 'Delivered' : tab.label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: urgent ? AppColors.offerRed : AppColors.green100, borderRadius: BorderRadius.circular(99)),
            child: Text(
              tab == BoardTab.delivered ? '$count today' : '$count',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: urgent ? Colors.white : AppColors.green800),
            ),
          ),
        ],
      ],
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.summary});
  final BoardSummary summary;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = levelColors(summary.alertsWorst);
    return Material(
      color: bg,
      child: InkWell(
        onTap: () => context.go('/more/usage'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(summary.alertsWorst == 'critical' ? Icons.error_rounded : Icons.warning_amber_rounded, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${summary.alertsOpen} usage alert${summary.alertsOpen == 1 ? '' : 's'} — check Usage & bills',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedOrderPane extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(selectedOrderProvider);
    if (id == null) {
      return const EmptyView(icon: Icons.receipt_long_rounded, title: 'Select an order', subtitle: 'Its items, customer and next step show here.');
    }
    return OrderDetailView(key: ValueKey(id), orderId: id, embedded: true);
  }
}

/// One tab's orders (or search results), paged, pull-to-refresh, reloads when the board changes.
class OrderList extends ConsumerStatefulWidget {
  const OrderList({super.key, required this.tab, this.query, required this.wide});
  final String tab;
  final String? query;
  final bool wide;

  @override
  ConsumerState<OrderList> createState() => _OrderListState();
}

class _OrderListState extends ConsumerState<OrderList> with AutomaticKeepAliveClientMixin {
  final List<OrderCard> _orders = [];
  String? _cursor;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant OrderList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query || oldWidget.tab != widget.tab) _reload();
  }

  Future<void> _reload() async {
    _cursor = null;
    _done = false;
    await _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (_done && !reset)) return;
    setState(() => _loading = true);
    try {
      final page = await ref.read(repositoryProvider).orders(tab: widget.tab, query: widget.query, cursor: reset ? null : _cursor);
      if (!mounted) return;
      setState(() {
        if (reset) _orders.clear();
        _orders.addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(orderListRefreshProvider, (_, _) => _reload());
    final selected = ref.watch(selectedOrderProvider);

    if (_orders.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_orders.isEmpty && _error != null) return ErrorView(message: _error!, onRetry: _reload);
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          children: [
            SizedBox(
              height: 360,
              child: EmptyView(
                icon: widget.query != null ? Icons.search_off_rounded : Icons.inbox_rounded,
                title: widget.query != null ? 'No orders match "${widget.query}"' : 'Nothing here right now',
                subtitle: widget.tab == 'new' ? 'New orders appear here with a chime.' : null,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(boardProvider.notifier).refresh();
        await _reload();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _load();
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: _orders.length + (_done ? 0 : 1),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index >= _orders.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              );
            }
            final order = _orders[index];
            return OrderCardTile(
              order: order,
              selected: widget.wide && selected == order.id,
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar(); // the "new order" banner has done its job
                if (widget.wide) {
                  ref.read(selectedOrderProvider.notifier).state = order.id;
                } else {
                  context.push('/order/${order.id}');
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class OrderCardTile extends StatelessWidget {
  const OrderCardTile({super.key, required this.order, required this.onTap, this.selected = false});
  final OrderCard order;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final waitingMinutes = DateTime.now().difference(order.placedAt ?? order.createdAt).inMinutes;
    final late = order.status == 'placed' && waitingMinutes >= 10;
    return Material(
      color: selected ? AppColors.green50 : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.green600 : (late ? AppColors.offerRed.withValues(alpha: 0.5) : AppColors.line),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('#${order.shortNumber}', style: text.titleLarge),
                  const SizedBox(width: 10),
                  StatusChip(order.status, dense: true),
                  const SizedBox(width: 8),
                  // An order left over from an earlier day shows its date; never pushes the row off a phone.
                  Expanded(
                    child: Text(
                      ago(order.placedAt ?? order.createdAt, short: true),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(color: late ? AppColors.offerRed : AppColors.inkMuted, fontWeight: late ? FontWeight.w700 : null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(order.recipientName, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(order.area, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Wraps onto a second line on narrow phones / large text instead of overflowing.
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Pill('${order.itemCount} item${order.itemCount == 1 ? '' : 's'}', icon: Icons.shopping_basket_outlined),
                        if (order.isCod)
                          const Pill('Cash on delivery', fg: Color(0xFF8A5A00), bg: AppColors.amberSoft, icon: Icons.payments_outlined)
                        else
                          Pill(
                            order.paymentStatus == 'paid' ? 'Paid online' : 'Online',
                            fg: AppColors.green700,
                            bg: AppColors.green50,
                            icon: Icons.verified_outlined,
                          ),
                        if (order.hasNote) const Pill('Note', fg: AppColors.brandBlue, bg: AppColors.brandBlueSoft, icon: Icons.sticky_note_2_outlined),
                        if (order.isOpen && order.promisedBy != null)
                          order.isLate
                              ? const Pill('Late', fg: AppColors.offerRed, bg: AppColors.offerRedSoft, icon: Icons.schedule_rounded)
                              : Pill(
                                  'By ${deliveryDay(order.promisedBy!).toLowerCase() == 'today' || deliveryDay(order.promisedBy!).toLowerCase() == 'tomorrow' ? deliveryDay(order.promisedBy!).toLowerCase() : deliveryDay(order.promisedBy!)}',
                                  fg: deliveryDay(order.promisedBy!) == 'Today' ? const Color(0xFF8A5A00) : AppColors.green800,
                                  bg: deliveryDay(order.promisedBy!) == 'Today' ? AppColors.amberSoft : AppColors.green50,
                                  icon: Icons.local_shipping_outlined,
                                ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatRupees(order.amountDue), style: text.titleMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
