import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(vendorOrdersProvider);
    return VendorScaffold(
      title: 'Orders',
      child: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          final today = items
              .where((o) => DateUtils.isSameDay(
                  DateTime.tryParse(o['created_at']?.toString() ?? ''),
                  DateTime.now()))
              .length;
          final pending = items
              .where((o) => const {
                    'placed',
                    'created',
                    'pending',
                    'paid',
                    'new'
                  }.contains(o['status']))
              .length;
          final active = items
              .where((o) => const {
                    'accepted',
                    'in_progress',
                    'paid',
                    'shipped',
                    'delivered'
                  }.contains(o['status']))
              .length;
          final revenue = items.where((o) {
            final d = DateTime.tryParse(o['created_at']?.toString() ?? '');
            final now = DateTime.now();
            return d != null && d.month == now.month && d.year == now.year;
          }).fold<double>(
              0,
              (s, o) =>
                  s + (o['total'] is num ? (o['total'] as num).toDouble() : 0));
          return DefaultTabController(
            length: 4,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    children: [
                      MetricCard(
                          icon: Icons.schedule_rounded,
                          label: 'Today',
                          value: '$today'),
                      MetricCard(
                          icon: Icons.inventory_2_rounded,
                          label: 'Pending',
                          value: '$pending'),
                      MetricCard(
                          icon: Icons.local_shipping_rounded,
                          label: 'Active',
                          value: '$active'),
                      MetricCard(
                          icon: Icons.currency_rupee_rounded,
                          label: 'Revenue',
                          value: NumberFormat.compactCurrency(
                                  locale: 'en_IN', symbol: 'Rs.')
                              .format(revenue)),
                    ],
                  ),
                ),
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'All'),
                    Tab(text: 'New'),
                    Tab(text: 'Active'),
                    Tab(text: 'Done')
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OrderList(items),
                      _OrderList(items
                          .where((o) => const {
                                'placed',
                                'created',
                                'pending',
                                'paid',
                                'new'
                              }.contains(o['status']))
                          .toList()),
                      _OrderList(items
                          .where((o) => const {
                                'accepted',
                                'in_progress',
                                'shipped',
                                'delivered'
                              }.contains(o['status']))
                          .toList()),
                      _OrderList(items
                          .where((o) => const {
                                'completed',
                                'delivered',
                                'cancelled'
                              }.contains(o['status']))
                          .toList()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList(this.items);
  final List<Map<String, dynamic>> items;

  static const flow = {
    'placed': ('accepted', 'Accept Order'),
    'created': ('accepted', 'Accept Order'),
    'pending': ('accepted', 'Accept Order'),
    'paid': ('accepted', 'Accept Order'),
    'new': ('accepted', 'Accept Order'),
    'accepted': ('in_progress', 'Start Processing'),
    // "Out for Delivery" must set shipped (not delivered). Delivered is separate.
    'in_progress': ('shipped', 'Out for Delivery'),
    'shipped': ('delivered', 'Mark Delivered'),
    'delivered': ('completed', 'Mark Completed'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No orders yet',
            subtitle: 'Orders placed by customers will appear here.'),
      );
    }
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.', decimalDigits: 0);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(vendorOrdersProvider.future),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, index) {
          final order = items[index];
          final status = order['status']?.toString() ?? 'placed';
          final next = flow[status];
          final orderItems =
              order['items'] is List ? order['items'] as List : const [];
          final metadata = order['metadata'] is Map
              ? Map<String, dynamic>.from(order['metadata'] as Map)
              : <String, dynamic>{};
          final returnRequest = metadata['returnRequest'] is Map
              ? Map<String, dynamic>.from(metadata['returnRequest'] as Map)
              : <String, dynamic>{};
          final returnStatus = returnRequest['status']?.toString() ?? '';
          final payMode = _paymentMode(order, metadata);
          final payStatus = _paymentStatus(order, metadata);
          final awaiting = _isAwaitingPayment(status, payMode, payStatus);
          final phone = _customerPhone(order, metadata);
          final address = _shippingAddress(order, metadata);
          return Opacity(
            opacity: awaiting ? 0.85 : 1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(_orderTitle(order),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))),
                        StatusBadge(status),
                        const SizedBox(width: 8),
                        Text(currency.format(order['total'] ?? 0),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    if (awaiting) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Awaiting payment',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                        '${order['customer_name'] ?? order['customerName'] ?? 'Customer'} - ${_date(order['created_at'])}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    if (phone.isNotEmpty)
                      Text('Phone: $phone',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    if (payMode.isNotEmpty || payStatus.isNotEmpty)
                      Text(
                          'Payment: ${_payModeLabel(payMode)}${payStatus.isNotEmpty ? ' · ${_payStatusLabel(payStatus, payMode)}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: awaiting
                                ? Colors.amber.shade900
                                : Colors.black54,
                            fontWeight: awaiting
                                ? FontWeight.w600
                                : FontWeight.w400,
                          )),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Address: $address',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                    const SizedBox(height: 8),
                    ...orderItems.take(3).map((item) {
                      final map = item is Map
                          ? Map<String, dynamic>.from(item)
                          : <String, dynamic>{};
                      final title =
                          map['title'] ?? map['name'] ?? map['productName'] ?? 'Item';
                      final qty = map['qty'] ?? map['quantity'] ?? 1;
                      final image = (map['image'] ??
                              map['imageUrl'] ??
                              map['thumbnailUrl'] ??
                              map['productImage'] ??
                              '')
                          .toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: image.isNotEmpty
                                    ? Image.network(
                                        image,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          color: Colors.black12,
                                          child: const Icon(
                                              Icons.image_not_supported,
                                              size: 16),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.black12,
                                        child: const Icon(Icons.inventory_2,
                                            size: 16),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$title x $qty',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (order['shipping_type'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                          'Shipping: ${order['shipping_type']} ${order['tracking_number'] ?? ''}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                    if (returnRequest.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Customer return request',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                  returnRequest['reason']?.toString() ??
                                      'No reason provided',
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 6),
                              Text(
                                  'Status: ${returnStatus.replaceAll('_', ' ')}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, children: [
                                if (returnStatus == 'requested') ...[
                                  FilledButton(
                                      onPressed: () => _updateReturn(
                                          context, ref, order, 'approve'),
                                      child: const Text('Approve')),
                                  OutlinedButton(
                                      onPressed: () => _updateReturn(
                                          context, ref, order, 'reject'),
                                      child: const Text('Reject'))
                                ],
                                if (returnStatus == 'approved')
                                  FilledButton(
                                      onPressed: () => _updateReturn(
                                          context, ref, order, 'received'),
                                      child: const Text('Mark received')),
                              ]),
                            ]),
                      ),
                    ],
                    if (next != null) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: () =>
                                _update(context, ref, order, next.$1),
                            child: Text(next.$2),
                          ),
                          if (const {
                            'placed',
                            'created',
                            'pending',
                            'paid',
                            'new'
                          }.contains(status))
                            OutlinedButton(
                              onPressed: () =>
                                  _update(context, ref, order, 'cancelled'),
                              child: const Text('Reject'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateReturn(BuildContext context, WidgetRef ref,
      Map<String, dynamic> order, String action) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(
                  '${action[0].toUpperCase()}${action.substring(1)} return'),
              content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Optional note'),
                  minLines: 2,
                  maxLines: 3),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: const Text('Confirm'))
              ],
            ));
    if (note == null) return;
    await ref
        .read(vendorRepositoryProvider)
        .updateProductReturn(order['id'].toString(), action, note: note);
    ref.invalidate(vendorOrdersProvider);
  }

  Future<void> _update(BuildContext context, WidgetRef ref,
      Map<String, dynamic> order, String nextStatus) async {
    Map<String, dynamic>? shipping;
    if (nextStatus == 'shipped') {
      shipping = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => const _ShippingDialog(),
      );
      if (shipping == null) return;
    }
    await ref
        .read(vendorRepositoryProvider)
        .updateOrderStatus(order['id'].toString(), nextStatus, shipping);
    ref.invalidate(vendorOrdersProvider);
  }

  String _date(Object? value) {
    final d = DateTime.tryParse(value?.toString() ?? '');
    return d == null ? '' : DateFormat('MMM d').format(d);
  }
}

class _ShippingDialog extends StatefulWidget {
  const _ShippingDialog();
  @override
  State<_ShippingDialog> createState() => _ShippingDialogState();
}

class _ShippingDialogState extends State<_ShippingDialog> {
  String type = 'own';
  final courier = TextEditingController();
  final awb = TextEditingController();
  final url = TextEditingController();
  final notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Shipping Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'own', label: Text('Own')),
                ButtonSegment(value: 'courier', label: Text('Courier'))
              ],
              selected: {type},
              onSelectionChanged: (v) => setState(() => type = v.first),
            ),
            if (type == 'courier') ...[
              const SizedBox(height: 10),
              TextField(
                  controller: courier,
                  decoration:
                      const InputDecoration(labelText: 'Courier Name *')),
              const SizedBox(height: 10),
              TextField(
                  controller: awb,
                  decoration: const InputDecoration(
                      labelText: 'AWB / Tracking Number *')),
              const SizedBox(height: 10),
              TextField(
                  controller: url,
                  decoration: const InputDecoration(labelText: 'Tracking URL')),
            ],
            const SizedBox(height: 10),
            TextField(
                controller: notes,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (type == 'courier' &&
                (courier.text.trim().isEmpty || awb.text.trim().isEmpty)) {
              return;
            }
            Navigator.pop(context, {
              'shipping_type': type,
              if (type == 'courier') 'courier_name': courier.text.trim(),
              if (type == 'courier') 'tracking_number': awb.text.trim(),
              if (url.text.trim().isNotEmpty) 'tracking_url': url.text.trim(),
              if (notes.text.trim().isNotEmpty)
                'shipping_notes': notes.text.trim(),
            });
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

String _orderTitle(Map<String, dynamic> order) {
  final normalized = _firstOrderText(order, const ['order_title', 'title']);
  if (normalized.isNotEmpty) return normalized;
  final explicit = _firstOrderText(order, const [
    'orderNumber',
    'order_number',
    'orderCode',
    'order_code',
    'reference',
    'referenceNumber'
  ]);
  if (explicit.isNotEmpty) return explicit;
  final orderItems = order['items'];
  if (orderItems is List && orderItems.isNotEmpty) {
    final first = orderItems.first;
    if (first is Map) {
      final itemTitle = _firstOrderText(Map<String, dynamic>.from(first),
          const ['title', 'name', 'productName', 'product_name']);
      if (itemTitle.isNotEmpty) return itemTitle;
    }
  }
  final customer =
      _firstOrderText(order, const ['customer_name', 'customerName']);
  if (customer.isNotEmpty && customer != 'Customer') return '$customer order';
  return 'Customer order';
}

String _firstOrderText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && !_looksLikeUuid(value)) return value;
  }
  return '';
}

bool _looksLikeUuid(String value) => RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());

String _paymentMode(Map<String, dynamic> order, Map<String, dynamic> meta) {
  final raw = order['paymentMode'] ??
      order['payment_mode'] ??
      meta['paymentMode'] ??
      meta['payment_mode'] ??
      '';
  return raw.toString().trim().toLowerCase();
}

String _paymentStatus(Map<String, dynamic> order, Map<String, dynamic> meta) {
  final raw = order['paymentStatus'] ??
      order['payment_status'] ??
      meta['paymentStatus'] ??
      meta['payment_status'] ??
      '';
  return raw.toString().trim().toLowerCase();
}

bool _isAwaitingPayment(String status, String mode, String payStatus) {
  if (mode == 'cod' || payStatus == 'cod' || payStatus == 'paid') return false;
  return status == 'created' || payStatus == 'pending';
}

String _payModeLabel(String mode) {
  if (mode.isEmpty) return '—';
  if (mode == 'cod') return 'COD';
  return mode.toUpperCase();
}

String _payStatusLabel(String status, String mode) {
  if (mode == 'cod' || status == 'cod') return 'COD';
  if (status.isEmpty) return '—';
  return status.replaceAll('_', ' ');
}

String _customerPhone(Map<String, dynamic> order, Map<String, dynamic> meta) {
  final fromOrder = [
    order['customerPhone'],
    order['customer_phone'],
    order['phone'],
  ];
  for (final v in fromOrder) {
    final s = v?.toString().trim() ?? '';
    if (s.isNotEmpty) return s;
  }
  final fromMeta = [
    meta['customerPhone'],
    meta['customer_phone'],
  ];
  for (final v in fromMeta) {
    final s = v?.toString().trim() ?? '';
    if (s.isNotEmpty) return s;
  }
  final addr = meta['shippingAddress'] ?? meta['shipping_address'];
  if (addr is Map) {
    final phone = addr['phone']?.toString().trim() ?? '';
    if (phone.isNotEmpty) return phone;
  }
  final customer = meta['customer'];
  if (customer is Map) {
    final phone =
        (customer['phone'] ?? customer['mobile'])?.toString().trim() ?? '';
    if (phone.isNotEmpty) return phone;
  }
  return '';
}

String _shippingAddress(Map<String, dynamic> order, Map<String, dynamic> meta) {
  final raw = order['shippingAddress'] ??
      order['shipping_address'] ??
      meta['shippingAddress'] ??
      meta['shipping_address'] ??
      meta['address'];
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  if (raw is! Map) return '';
  final a = Map<String, dynamic>.from(raw);
  final parts = <String>[
    (a['fullName'] ?? a['name'] ?? '').toString().trim(),
    (a['line1'] ?? a['addressLine1'] ?? a['street'] ?? '').toString().trim(),
    (a['line2'] ?? a['addressLine2'] ?? '').toString().trim(),
    [
      (a['city'] ?? '').toString().trim(),
      (a['state'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(', '),
    (a['pincode'] ?? a['postalCode'] ?? a['zip'] ?? '').toString().trim(),
    (a['country'] ?? '').toString().trim(),
  ].where((s) => s.isNotEmpty).toList();
  return parts.join(', ');
}
