import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/register_page.dart';
import 'features/auth/presentation/splash_gate.dart';
import 'features/vendor/presentation/pages/availability_page.dart';
import 'features/vendor/presentation/pages/bank_accounts_page.dart';
import 'features/vendor/presentation/pages/bookings_page.dart';
import 'features/vendor/presentation/pages/dashboard_page.dart';
import 'features/vendor/presentation/pages/dropshipping_page.dart';
import 'features/vendor/presentation/pages/food_vendor_page.dart';
import 'features/vendor/presentation/pages/media_library_page.dart';
import 'features/vendor/presentation/pages/orders_page.dart';
import 'features/vendor/presentation/pages/payments_page.dart';
import 'features/vendor/presentation/pages/products_page.dart';
import 'features/vendor/presentation/pages/profile_page.dart';
import 'features/vendor/presentation/pages/services_page.dart';
import 'features/vendor/presentation/pages/settlements_page.dart';
import 'features/vendor/presentation/pages/vendor_kyc_page.dart';
import 'features/vendor/presentation/pages/vendor_plans_page.dart';
import 'features/vendor/presentation/pages/simple_vendor_page.dart';

GoRouter? _vendorRouter;
void openVendorDeepLink(String raw) {
  final path = Uri.tryParse(raw)?.path ?? raw;
  _vendorRouter?.go(path.contains('/food/') ? '/food' : path);
}

final routerProvider = Provider<GoRouter>((ref) {
  return _vendorRouter = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const VendorSplashGate()),
      GoRoute(path: '/login', builder: (_, __) => const VendorLoginPage()),
      GoRoute(
          path: '/register', builder: (_, __) => const VendorRegisterPage()),
      GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
      GoRoute(path: '/products', builder: (_, __) => const ProductsPage()),
      GoRoute(path: '/food', builder: (_, __) => const FoodVendorPage()),
      GoRoute(path: '/services', builder: (_, __) => const ServicesPage()),
      GoRoute(
          path: '/availability', builder: (_, __) => const AvailabilityPage()),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersPage()),
      GoRoute(path: '/bookings', builder: (_, __) => const BookingsPage()),
      GoRoute(
          path: '/settlements', builder: (_, __) => const SettlementsPage()),
      GoRoute(path: '/payments', builder: (_, __) => const PaymentsPage()),
      GoRoute(
          path: '/wallet',
          builder: (_, __) =>
              const SimpleVendorPage(kind: SimpleVendorKind.wallet)),
      GoRoute(path: '/bank', builder: (_, __) => const BankAccountsPage()),
      GoRoute(path: '/media', builder: (_, __) => const MediaLibraryPage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(path: '/kyc', builder: (_, __) => const VendorKycPage()),
      GoRoute(path: '/plans', builder: (_, __) => const VendorPlansPage()),
      GoRoute(
          path: '/dropshipping', builder: (_, __) => const DropshippingPage()),
      GoRoute(
          path: '/settings',
          builder: (_, __) =>
              const SimpleVendorPage(kind: SimpleVendorKind.settings)),
      GoRoute(
          path: '/account-control',
          builder: (_, __) =>
              const SimpleVendorPage(kind: SimpleVendorKind.accountControl)),
      GoRoute(
          path: '/analytics',
          builder: (_, __) =>
              const SimpleVendorPage(kind: SimpleVendorKind.analytics)),
      GoRoute(
          path: '/reviews',
          builder: (_, __) =>
              const SimpleVendorPage(kind: SimpleVendorKind.reviews)),
      GoRoute(
          path: '/support',
          builder: (_, __) =>
              const SimpleVendorPage(kind: SimpleVendorKind.support)),
      GoRoute(
          path: '/notifications',
          builder: (_, __) =>
              const SimpleVendorPage(kind: SimpleVendorKind.notifications)),
    ],
  );
});

class VendorApp extends ConsumerWidget {
  const VendorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'P4U Vendor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
