import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/vendor_models.dart';
import 'vendor_repository.dart';

final vendorRepositoryProvider = Provider((ref) => VendorRepository());

final vendorIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.valueOrNull?.id;
});

final currentVendorProvider = Provider<VendorUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final dashboardProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) throw StateError('Not signed in');
  return ref.watch(vendorRepositoryProvider).dashboard(vendorId);
});

final vendorProductsProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  final vendor = ref.watch(currentVendorProvider);
  if (vendorId == null || vendor?.hasProductFlow == false) {
    return <Map<String, dynamic>>[];
  }
  return ref.watch(vendorRepositoryProvider).products(vendorId);
});

final vendorServicesProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  final vendor = ref.watch(currentVendorProvider);
  if (vendorId == null || vendor?.hasServiceFlow != true) {
    return <Map<String, dynamic>>[];
  }
  return ref.watch(vendorRepositoryProvider).services(vendorId);
});

final vendorOrdersProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  final vendor = ref.watch(currentVendorProvider);
  if (vendorId == null || vendor?.hasProductFlow == false) {
    return <Map<String, dynamic>>[];
  }
  return ref.watch(vendorRepositoryProvider).orders(vendorId);
});

final vendorBookingsProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  final vendor = ref.watch(currentVendorProvider);
  if (vendorId == null || vendor?.hasServiceFlow != true) {
    return <Map<String, dynamic>>[];
  }
  return ref.watch(vendorRepositoryProvider).bookings(vendorId);
});

final vendorSettlementsProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  return ref.watch(vendorRepositoryProvider).settlements(vendorId);
});

final settlementStatsProvider = FutureProvider((ref) async {
  final rows = await ref.watch(vendorSettlementsProvider.future);
  double sumWhere(bool Function(Map<String, dynamic>) test) =>
      rows.where(test).fold(0, (sum, row) => sum + moneyOf(row, 'net_amount'));
  return SettlementStats(
    totalEarned: sumWhere((_) => true),
    pending: sumWhere((r) => ['pending', 'eligible'].contains(r['status'])),
    settled: sumWhere((r) => r['status'] == 'settled'),
    rejected: sumWhere((r) => r['status'] == 'rejected'),
  );
});

final vendorProfileProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <String, dynamic>{};
  return ref.watch(vendorRepositoryProvider).profile(vendorId);
});

final vendorBanksProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  return ref.watch(vendorRepositoryProvider).bankAccounts(vendorId);
});

final vendorNotificationsProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  return ref.watch(vendorRepositoryProvider).notifications(vendorId);
});
