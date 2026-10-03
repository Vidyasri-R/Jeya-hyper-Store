import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key, this.selectMode = false});
  final bool selectMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    final selected = ref.watch(selectedAddressProvider);
    return Scaffold(
      appBar: AppBar(title: Text(selectMode ? 'Deliver to' : 'Saved Addresses')),
      body: addresses.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.brand700)),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(addressesProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.location_on_outlined,
                title: 'No saved addresses',
                message: 'Add your home or work address for faster checkout.',
                action: 'Add Address',
                onAction: () => context.push('/address'),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final a in list)
                    _AddressCard(
                      address: a,
                      selected: selectMode && selected?.id == a.id,
                      onTap: selectMode
                          ? () {
                              if (!a.serviceable) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("We don't deliver to this address yet")));
                                return;
                              }
                              ref.read(selectedAddressIdProvider.notifier).state = a.id;
                              context.pop();
                            }
                          : () => context.push('/address?id=${a.id}'),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: OutlinedButton.icon(onPressed: () => context.push('/address'), icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Add New Address')),
        ),
      ),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address, required this.selected, required this.onTap});
  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final a = address;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.brand50 : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: selected ? AppColors.brand700 : AppColors.line, width: selected ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(a.title.toLowerCase() == 'work' ? Icons.business_rounded : Icons.home_rounded, color: AppColors.brand700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(a.title, style: text.titleSmall),
                  if (a.isDefault) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.brand700, borderRadius: BorderRadius.circular(10)),
                      child: Text('Default', style: text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text('${a.recipientName} · ${a.phone.length == 12 ? a.phone.substring(2) : a.phone}', style: text.labelMedium),
                Text(a.oneLine, style: text.bodySmall),
                if (!a.serviceable)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("We don't deliver here yet", style: text.labelSmall?.copyWith(color: AppColors.offerRed, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                final repo = ref.read(repositoryProvider);
                try {
                  if (v == 'edit') {
                    context.push('/address?id=${a.id}');
                  } else if (v == 'default') {
                    await repo.updateAddress(a.id, {'isDefault': true});
                    ref.invalidate(addressesProvider);
                  } else if (v == 'delete') {
                    await repo.deleteAddress(a.id);
                    ref.invalidate(addressesProvider);
                  }
                } on ApiException catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (!a.isDefault) const PopupMenuItem(value: 'default', child: Text('Set as default')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
