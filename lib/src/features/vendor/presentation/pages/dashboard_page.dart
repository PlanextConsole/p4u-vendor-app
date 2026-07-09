import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider);
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.', decimalDigits: 0);
    return VendorScaffold(
      title: 'Dashboard',
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorCard(message: '$error'),
        data: (dashboard) {
          final recentOrders = dashboard.orders.take(4).toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(dashboardProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount:
                      MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    MetricCard(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Total Revenue',
                        value: currency.format(dashboard.revenue),
                        caption: '${dashboard.orders.length} orders'),
                    MetricCard(
                        icon: Icons.shopping_cart_rounded,
                        label: 'Active Orders',
                        value: '${dashboard.activeOrders}'),
                    MetricCard(
                        icon: Icons.inventory_2_rounded,
                        label: 'Products',
                        value: '${dashboard.products.length}'),
                    MetricCard(
                        icon: Icons.star_rounded,
                        label: 'Rating',
                        value: '${dashboard.vendor['rating'] ?? 0}',
                        caption:
                            '${dashboard.vendor['total_orders'] ?? 0} total orders'),
                  ],
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('This Week\'s Revenue',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 210,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => const FlLine(
                                    color: AppColors.border, strokeWidth: 1)),
                            titlesData: const FlTitlesData(
                                leftTitles: AxisTitles(),
                                topTitles: AxisTitles(),
                                rightTitles: AxisTitles()),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                isCurved: true,
                                color: AppColors.primary,
                                barWidth: 3,
                                spots: const [
                                  FlSpot(0, 12),
                                  FlSpot(1, 18),
                                  FlSpot(2, 15),
                                  FlSpot(3, 22),
                                  FlSpot(4, 28),
                                  FlSpot(5, 32),
                                  FlSpot(6, 25),
                                ],
                                belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.primary
                                        .withValues(alpha: .12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                              child: Text('Recent Orders',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800))),
                          TextButton(
                              onPressed: () => context.go('/orders'),
                              child: const Text('View All')),
                        ],
                      ),
                      if (recentOrders.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text('No orders yet',
                                style: TextStyle(color: Colors.black54)))
                      else
                        ...recentOrders.map((order) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(order['id']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  order['customer_name']?.toString() ??
                                      'Customer'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(currency.format(order['total'] ?? 0),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  StatusBadge(
                                      order['status']?.toString() ?? 'placed'),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _QuickLink(
                        'Products', '/products', Icons.inventory_2_rounded),
                    _QuickLink('Services', '/services', Icons.handyman_rounded),
                    _QuickLink(
                        'Orders', '/orders', Icons.shopping_cart_rounded),
                    _QuickLink('Settlements', '/settlements',
                        Icons.currency_rupee_rounded),
                    _QuickLink('Payments', '/payments', Icons.history_rounded),
                    _QuickLink(
                        'Bank A/C', '/bank', Icons.account_balance_rounded),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: AppCard(
        onTap: () => context.go(path),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Text(message)));
}
