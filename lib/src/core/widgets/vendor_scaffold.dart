import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/vendor/domain/vendor_models.dart';
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

  static List<_Destination> _bottomDestinationsFor(VendorUser? vendor) {
    if (vendor?.isServiceVendor == true) {
      return const [
        _Destination('Home', '/', Icons.dashboard_rounded),
        _Destination('Services', '/services', Icons.handyman_rounded),
        _Destination('Bookings', '/bookings', Icons.event_available_rounded),
        _Destination('Payments', '/settlements', Icons.currency_rupee_rounded),
        _Destination('Profile', '/profile', Icons.person_rounded),
      ];
    }
    return const [
      _Destination('Home', '/', Icons.dashboard_rounded),
      _Destination('Products', '/products', Icons.inventory_2_rounded),
      _Destination('Orders', '/orders', Icons.shopping_cart_rounded),
      _Destination('Payments', '/settlements', Icons.currency_rupee_rounded),
      _Destination('Profile', '/profile', Icons.person_rounded),
    ];
  }

  static bool isBlockedForVendor(String path, VendorUser? vendor) {
    if (vendor == null || vendor.isBothVendor) return false;
    const serviceOnly = {'/services', '/availability', '/bookings'};
    const productOnly = {'/products', '/orders', '/food'};
    if (vendor.isProductVendor && serviceOnly.contains(path)) return true;
    if (vendor.isServiceVendor && productOnly.contains(path)) return true;
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final isDashboard = location == '/';
    final auth = ref.watch(authStateProvider);
    final vendor = auth.valueOrNull;
    if (!auth.isLoading && vendor == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
    } else if (isBlockedForVendor(location, vendor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
    }
    final destinations = _bottomDestinationsFor(vendor);
    final current = destinations.indexWhere((d) => d.path == location);
    return PopScope(
      // Routes reached with go (for example a restored/deep-linked module)
      // have no page beneath them. Intercept Back and return to Dashboard.
      canPop: isDashboard || context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !isDashboard) context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: isDashboard
              ? null
              : IconButton(
                  tooltip: 'Back',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.softGreen, // soft teal brand tile
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset('assets/images/p4u-logo.png',
                    fit: BoxFit.contain),
              ),
              const SizedBox(width: 8),
              Flexible(
                child:
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          actions: [
            if (!isDashboard)
              Builder(
                builder: (scaffoldContext) => IconButton(
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: location == '/notifications'
                  ? null
                  : () => context.push('/notifications'),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            ...actions,
          ],
        ),
        drawer: _VendorDrawer(activePath: location),
        body: SafeArea(child: child),
        bottomNavigationBar: _VendorBottomNav(
          destinations: destinations,
          selectedIndex: current < 0 ? 0 : current,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }
}

class _VendorBottomNav extends StatelessWidget {
  const _VendorBottomNav({
    required this.destinations,
    required this.selectedIndex,
  });

  final List<_Destination> destinations;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 70,
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            for (var index = 0; index < destinations.length; index++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    if (index != selectedIndex) {
                      final path = destinations[index].path;
                      if (path == '/') {
                        context.go(path);
                      } else {
                        context.push(path);
                      }
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 30,
                        child: Icon(
                          destinations[index].icon,
                          size: 23,
                          color: index == selectedIndex
                              ? AppColors.primary
                              : AppColors.brandDark.withValues(alpha: .72),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: index == selectedIndex ? 18 : 0,
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          destinations[index].label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: index == selectedIndex
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: index == selectedIndex
                                ? AppColors.primary
                                : AppColors.brandDark.withValues(alpha: .72),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VendorDrawer extends ConsumerWidget {
  const _VendorDrawer({required this.activePath});

  final String activePath;

  List<_Destination> _itemsFor(VendorUser? vendor) {
    final hasProduct = vendor?.hasProductFlow != false;
    final hasService = vendor?.hasServiceFlow == true;
    return [
      const _Destination('Dashboard', '/', Icons.dashboard_rounded),
      if (hasProduct)
        const _Destination('Products', '/products', Icons.inventory_2_rounded),
      if (hasService)
        const _Destination('Services', '/services', Icons.handyman_rounded),
      if (hasService)
        const _Destination(
            'Availability', '/availability', Icons.calendar_month_rounded),
      if (hasProduct)
        const _Destination('Orders', '/orders', Icons.shopping_cart_rounded),
      if (hasService)
        const _Destination(
            'Bookings', '/bookings', Icons.event_available_rounded),
      const _Destination(
          'Settlements', '/settlements', Icons.currency_rupee_rounded),
      const _Destination('Payment History', '/payments', Icons.history_rounded),
      // Hidden to match the vendor web (no Wallet module on web). Route/page
      // code is kept in the router — only the menu entry is hidden.
      // const _Destination(
      //     'Wallet', '/wallet', Icons.account_balance_wallet_rounded),
      const _Destination(
          'Bank Account', '/bank', Icons.account_balance_rounded),
      const _Destination('Media Library', '/media', Icons.perm_media_rounded),
      // Hidden to match the vendor web (no dedicated Analytics/Reviews modules).
      // Kept in the router; only hidden from the menu.
      // const _Destination('Analytics', '/analytics', Icons.bar_chart_rounded),
      // const _Destination('Reviews', '/reviews', Icons.star_rounded),
      const _Destination('Support', '/support', Icons.help_outline_rounded),
      const _Destination('Settings', '/settings', Icons.settings_rounded),
      const _Destination('Account Control', '/account-control',
          Icons.admin_panel_settings_rounded),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(authStateProvider).valueOrNull;
    final items = _itemsFor(vendor);
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
                    child: Icon(Icons.storefront_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            vendor?.businessName.isNotEmpty == true
                                ? vendor!.businessName
                                : 'Vendor Portal',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                        Text(vendor?.name ?? 'Seller Dashboard',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
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
                            if (item.path == '/') {
                              context.go(item.path);
                            } else if (item.path != activePath) {
                              context.push(item.path);
                            }
                          },
                        ))
                    .toList(),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Logout',
                  style: TextStyle(color: AppColors.danger)),
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
