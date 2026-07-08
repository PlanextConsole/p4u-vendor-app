import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../theme/app_theme.dart';

class VendorScaffold extends ConsumerWidget {
  const VendorScaffold({
    required this.title,
    required this.child,
    this.actions = const [],
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  static const destinations = [
    _Destination('Home', '/', Icons.dashboard_rounded),
    _Destination('Products', '/products', Icons.inventory_2_rounded),
    _Destination('Orders', '/orders', Icons.shopping_cart_rounded),
    _Destination('Payments', '/settlements', Icons.currency_rupee_rounded),
    _Destination('Profile', '/profile', Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final auth = ref.watch(authStateProvider);
    if (!auth.isLoading && auth.valueOrNull == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
    }
    final current = destinations.indexWhere((d) => d.path == location);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.go('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          ...actions,
        ],
      ),
      drawer: _VendorDrawer(activePath: location),
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: current < 0 ? 0 : current,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary,
        onDestinationSelected: (index) => context.go(destinations[index].path),
        destinations: destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.icon, color: Colors.white),
                  label: d.label,
                ))
            .toList(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _VendorDrawer extends ConsumerWidget {
  const _VendorDrawer({required this.activePath});

  final String activePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(authStateProvider).valueOrNull;
    final items = [
      const _Destination('Dashboard', '/', Icons.dashboard_rounded),
      const _Destination('Products', '/products', Icons.inventory_2_rounded),
      const _Destination('Services', '/services', Icons.handyman_rounded),
      const _Destination('Availability', '/availability', Icons.calendar_month_rounded),
      const _Destination('Orders', '/orders', Icons.shopping_cart_rounded),
      const _Destination('Bookings', '/bookings', Icons.event_available_rounded),
      const _Destination('Settlements', '/settlements', Icons.currency_rupee_rounded),
      const _Destination('Payment History', '/payments', Icons.history_rounded),
      const _Destination('Wallet', '/wallet', Icons.account_balance_wallet_rounded),
      const _Destination('Bank Account', '/bank', Icons.account_balance_rounded),
      const _Destination('Media Library', '/media', Icons.perm_media_rounded),
      const _Destination('Analytics', '/analytics', Icons.bar_chart_rounded),
      const _Destination('Reviews', '/reviews', Icons.star_rounded),
      const _Destination('Support', '/support', Icons.help_outline_rounded),
      const _Destination('Settings', '/settings', Icons.settings_rounded),
      const _Destination('Account Control', '/account-control', Icons.admin_panel_settings_rounded),
    ];
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              color: AppColors.primary,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.storefront_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendor?.businessName.isNotEmpty == true ? vendor!.businessName : 'Vendor Portal',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        Text(vendor?.name ?? 'Seller Dashboard',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: items
                    .map((item) => ListTile(
                          selected: activePath == item.path,
                          selectedColor: AppColors.primary,
                          leading: Icon(item.icon),
                          title: Text(item.label),
                          onTap: () {
                            Navigator.pop(context);
                            context.go(item.path);
                          },
                        ))
                    .toList(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Logout', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}
