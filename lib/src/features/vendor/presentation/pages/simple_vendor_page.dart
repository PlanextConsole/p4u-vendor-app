import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/vendor_providers.dart';

enum SimpleVendorKind {
  analytics,
  reviews,
  support,
  notifications,
  settings,
  wallet,
  accountControl
}

class SimpleVendorPage extends ConsumerWidget {
  const SimpleVendorPage({required this.kind, super.key});

  final SimpleVendorKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (kind) {
      SimpleVendorKind.analytics => _AnalyticsPage(),
      SimpleVendorKind.reviews => _ReviewsPage(),
      SimpleVendorKind.support => _SupportPage(),
      SimpleVendorKind.notifications => _NotificationsPage(),
      SimpleVendorKind.settings => _SettingsPage(),
      SimpleVendorKind.wallet => _WalletPage(),
      SimpleVendorKind.accountControl => _AccountControlPage(),
    };
  }
}

class _AnalyticsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return VendorScaffold(
      title: 'Analytics',
      child: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                MetricCard(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Revenue',
                    value: 'Rs.${d.revenue.toStringAsFixed(0)}'),
                MetricCard(
                    icon: Icons.shopping_cart_rounded,
                    label: 'Orders',
                    value: '${d.orders.length}'),
                MetricCard(
                    icon: Icons.inventory_2_rounded,
                    label: 'Products',
                    value: '${d.products.length}'),
                MetricCard(
                    icon: Icons.handyman_rounded,
                    label: 'Services',
                    value: '${d.services.length}'),
              ],
            ),
            const SizedBox(height: 16),
            const AppCard(
                child: Text(
                    'Analytics uses the same live orders/products/services data as the React vendor dashboard. Detailed time-series can be added once backend aggregates are available.')),
          ],
        ),
      ),
    );
  }
}

class _ReviewsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VendorScaffold(
      title: 'Reviews',
      child: FutureBuilder(
        future: _reviews(ref),
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const Padding(
                padding: EdgeInsets.all(16),
                child: EmptyState(
                    icon: Icons.star_outline_rounded, title: 'No reviews yet'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: rows
                .map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.star_rounded,
                              color: Colors.amber),
                          title: Text('${r['rating'] ?? 0} / 5'),
                          subtitle: Text(r['comment']?.toString() ?? ''),
                        ),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _reviews(WidgetRef ref) async {
    final vendorId = ref.read(vendorIdProvider);
    if (vendorId == null) return [];
    final client = ref.read(vendorRepositoryProvider);
    final profile = await client.profile(vendorId);
    return profile['reviews'] is List
        ? List<Map<String, dynamic>>.from(profile['reviews'])
        : [];
  }
}

class _SupportPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VendorScaffold(
      title: 'Support',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const EmptyState(
              icon: Icons.help_outline_rounded,
              title: 'Need help?',
              subtitle: 'Create a support request from here.'),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: () => _createTicket(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Ticket')),
        ],
      ),
    );
  }

  Future<void> _createTicket(BuildContext context, WidgetRef ref) async {
    final vendor = ref.read(authStateProvider).valueOrNull;
    if (vendor == null) return;
    final subject = TextEditingController();
    final description = TextEditingController();
    var category = 'vendor';
    var priority = 'medium';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Support Ticket'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 10),
              TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'vendor', child: Text('Vendor')),
                  DropdownMenuItem(value: 'orders', child: Text('Orders')),
                  DropdownMenuItem(value: 'payments', child: Text('Payments')),
                  DropdownMenuItem(
                      value: 'technical', child: Text('Technical')),
                ],
                onChanged: (v) => category = v ?? category,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (v) => priority = v ?? priority,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true ||
        subject.text.trim().isEmpty ||
        description.text.trim().isEmpty) {
      return;
    }
    await ref.read(vendorRepositoryProvider).createSupportTicket(
          vendorId: vendor.id,
          vendorName: vendor.businessName.isNotEmpty
              ? vendor.businessName
              : vendor.name,
          subject: subject.text.trim(),
          description: description.text.trim(),
          category: category,
          priority: priority,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support ticket created')));
    }
  }
}

class _NotificationsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(vendorNotificationsProvider);
    return VendorScaffold(
      title: 'Notifications',
      child: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(vendorNotificationsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = rows[index];
                final isUnread =
                    item['status']?.toString().toLowerCase() != 'read';
                return AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isUnread
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: isUnread
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black45,
                    ),
                    title: Text(
                      item['title']?.toString().isNotEmpty == true
                          ? item['title'].toString()
                          : 'Notification',
                      style: TextStyle(
                          fontWeight:
                              isUnread ? FontWeight.w900 : FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item['body']?.toString().isNotEmpty == true)
                          Text(item['body'].toString()),
                        if (item['created_at']?.toString().isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(item['created_at'].toString(),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black45)),
                          ),
                      ],
                    ),
                    onTap: isUnread
                        ? () async {
                            await ref
                                .read(vendorRepositoryProvider)
                                .markNotificationRead(
                                    item['id']?.toString() ?? '');
                            ref.invalidate(vendorNotificationsProvider);
                          }
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SettingsPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SettingsPage> createState() => _SettingsPageState();
}

class _WalletPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(settlementStatsProvider);
    return VendorScaffold(
      title: 'Wallet',
      child: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MetricCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Available / Pending',
                value: 'Rs.${s.pending.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            MetricCard(
                icon: Icons.check_circle_rounded,
                label: 'Settled',
                value: 'Rs.${s.settled.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            const AppCard(
                child: Text(
                    'Vendor wallet is derived from settlement records so balances stay aligned with the existing backend business logic.')),
          ],
        ),
      ),
    );
  }
}

class _AccountControlPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VendorScaffold(
      title: 'Account Control',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Deactivating or deleting your P4U vendor account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
              'Deactivate temporarily to hide your store, or request deletion if you want to permanently leave the platform.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Deactivate account',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text(
                  'Temporarily hide your store, products, and services.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _request(context, ref, 'deactivate'),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Delete account',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.red)),
              subtitle: const Text(
                  'Request permanent deletion. Data retention follows audit rules.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _request(context, ref, 'delete'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _request(
      BuildContext context, WidgetRef ref, String action) async {
    final vendorId = ref.read(vendorIdProvider);
    if (vendorId == null) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            action == 'delete' ? 'Delete account?' : 'Deactivate account?'),
        content: TextField(
            controller: reason,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Reason')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    if (action == 'delete') {
      await ref
          .read(vendorRepositoryProvider)
          .softDeleteVendor(vendorId, reason.text.trim());
    } else {
      await ref
          .read(vendorRepositoryProvider)
          .deactivateVendor(vendorId, reason.text.trim());
    }
    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) context.go('/login');
  }
}

class _SettingsPageState extends ConsumerState<_SettingsPage> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    return VendorScaffold(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Change Password',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                    controller: password,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'New password')),
                const SizedBox(height: 10),
                TextField(
                    controller: confirm,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Confirm password')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: saving ? null : _changePassword,
                  child: Text(saving ? 'Updating...' : 'Update Password'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account Control',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                    'Deactivate or request deletion of your vendor account from the support team.',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                    onPressed: () => context.go('/account-control'),
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('Request Account Action')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    if (password.text.length < 6 || password.text != confirm.text) return;
    setState(() => saving = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(password.text);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Password updated')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
