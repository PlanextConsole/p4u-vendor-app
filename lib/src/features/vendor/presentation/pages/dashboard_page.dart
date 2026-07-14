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
          final recentActivity = dashboard.orders.take(4).toList();
          final isServiceOnly = dashboard.isServiceVendor;
          final itemLabel = isServiceOnly ? 'Services' : 'Products';
          final activityLabel = isServiceOnly ? 'Bookings' : 'Orders';
          final activityPath = isServiceOnly ? '/bookings' : '/orders';
          final itemCount = isServiceOnly
              ? dashboard.services.length
              : dashboard.products.length;
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
                        caption:
                            '${dashboard.orders.length} ${activityLabel.toLowerCase()}'),
                    MetricCard(
                        icon: isServiceOnly
                            ? Icons.event_available_rounded
                            : Icons.shopping_cart_rounded,
                        label: 'Active $activityLabel',
                        value: '${dashboard.activeOrders}'),
                    MetricCard(
                        icon: isServiceOnly
                            ? Icons.handyman_rounded
                            : Icons.inventory_2_rounded,
                        label: itemLabel,
                        value: '$itemCount'),
                    MetricCard(
                        icon: Icons.star_rounded,
                        label: 'Rating',
                        value: '${dashboard.vendor['rating'] ?? 0}',
                        caption:
                            '${dashboard.vendor['total_orders'] ?? 0} total ${activityLabel.toLowerCase()}'),
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
                                spots: _weekRevenueSpots(dashboard.orders),
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
                          Expanded(
                              child: Text('Recent $activityLabel',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))),
                          TextButton(
                              onPressed: () => context.go(activityPath),
                              child: const Text('View All')),
                        ],
                      ),
                      if (recentActivity.isEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Text('No ${activityLabel.toLowerCase()} yet',
                                style: const TextStyle(color: Colors.black54)))
                      else
                        ...recentActivity.map((order) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(_activityTitle(order, activityLabel),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  order['customer_name']?.toString() ??
                                      order['customerName']?.toString() ??
                                      'Customer'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                      currency.format(order['total'] ??
                                          order['total_amount'] ??
                                          0),
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
                    if (!isServiceOnly)
                      _QuickLink(
                          'Products', '/products', Icons.inventory_2_rounded),
                    if (isServiceOnly || dashboard.isBothVendor)
                      _QuickLink(
                          'Services', '/services', Icons.handyman_rounded),
                    if (isServiceOnly || dashboard.isBothVendor)
                      _QuickLink('Bookings', '/bookings',
                          Icons.event_available_rounded),
                    if (!isServiceOnly)
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

String _activityTitle(Map<String, dynamic> row, String activityLabel) {
  final explicit = _firstText(row, const [
    'orderNumber',
    'order_number',
    'orderCode',
    'order_code',
    'bookingNumber',
    'booking_number',
    'bookingCode',
    'booking_code',
    'service_name',
    'serviceName',
    'product_name',
    'productName',
    'title',
    'name'
  ]);
  if (explicit.isNotEmpty) {
    return explicit;
  }
  final items = row['items'];
  if (items is List && items.isNotEmpty) {
    final first = items.first;
    if (first is Map) {
      final itemTitle = _firstText(Map<String, dynamic>.from(first),
          const ['title', 'name', 'productName', 'product_name']);
      if (itemTitle.isNotEmpty) return itemTitle;
    }
  }
  final customer = _firstText(row, const ['customer_name', 'customerName']);
  if (customer.isNotEmpty && customer != 'Customer') {
    return '$customer $activityLabel';
  }
  return activityLabel == 'Bookings' ? 'Service booking' : 'Customer order';
}

/// Last 7 calendar days of non-cancelled order totals (x = 0..6 oldest→newest).
List<FlSpot> _weekRevenueSpots(List<Map<String, dynamic>> orders) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 6));
  final totals = List<double>.filled(7, 0);
  for (final o in orders) {
    if (o['status']?.toString() == 'cancelled') continue;
    final created = DateTime.tryParse(
        '${o['created_at'] ?? o['createdAt'] ?? ''}');
    if (created == null) continue;
    final day = DateTime(created.year, created.month, created.day);
    final idx = day.difference(start).inDays;
    if (idx < 0 || idx > 6) continue;
    final amount = o['total'] ?? o['total_amount'] ?? 0;
    totals[idx] += amount is num
        ? amount.toDouble()
        : double.tryParse(amount.toString()) ?? 0;
  }
  return [
    for (var i = 0; i < 7; i++) FlSpot(i.toDouble(), totals[i]),
  ];
}

String _firstText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && !_looksLikeUuid(value)) return value;
  }
  return '';
}

bool _looksLikeUuid(String value) => RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
