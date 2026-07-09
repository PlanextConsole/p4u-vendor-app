import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

class SettlementsPage extends ConsumerWidget {
  const SettlementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlements = ref.watch(vendorSettlementsProvider);
    final stats = ref.watch(settlementStatsProvider);
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.', decimalDigits: 0);
    return VendorScaffold(
      title: 'Settlements',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vendorSettlementsProvider);
          ref.invalidate(settlementStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            stats.maybeWhen(
              data: (s) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  MetricCard(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Total Earned',
                      value: currency.format(s.totalEarned)),
                  MetricCard(
                      icon: Icons.schedule_rounded,
                      label: 'Pending',
                      value: currency.format(s.pending)),
                  MetricCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Settled',
                      value: currency.format(s.settled)),
                  MetricCard(
                      icon: Icons.cancel_rounded,
                      label: 'Rejected',
                      value: currency.format(s.rejected)),
                ],
              ),
              orElse: () => const SizedBox(
                  height: 96,
                  child: Center(child: CircularProgressIndicator())),
            ),
            const SizedBox(height: 16),
            settlements.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.currency_rupee_rounded,
                      title: 'No settlements found')
                  : Column(
                      children: items.map((s) => SettlementTile(s)).toList()),
            ),
          ],
        ),
      ),
    );
  }
}

class SettlementTile extends StatelessWidget {
  const SettlementTile(this.row, {super.key});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.', decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(row['id']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                StatusBadge(row['status']?.toString() ?? 'pending'),
                const SizedBox(width: 8),
                Text(currency.format(row['net_amount'] ?? 0),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Order: ${row['order_id'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
                'Gross: ${currency.format(row['amount'] ?? 0)} - Commission: ${currency.format(row['commission'] ?? 0)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
