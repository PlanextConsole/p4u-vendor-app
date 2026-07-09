import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';
import 'settlements_page.dart';

class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlements = ref.watch(vendorSettlementsProvider);
    return VendorScaffold(
      title: 'Payment History',
      child: settlements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search by ID or order ID...'),
                onChanged: (_) {}),
            const SizedBox(height: 16),
            ...items.map((row) => SettlementTile(row)),
          ],
        ),
      ),
    );
  }
}
