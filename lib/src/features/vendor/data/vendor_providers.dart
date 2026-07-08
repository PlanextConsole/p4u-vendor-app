import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import 'vendor_repository.dart';

final vendorRepositoryProvider = Provider((ref) => VendorRepository());

final vendorIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.valueOrNull?.id;
});

final dashboardProvider = FutureProvider.autoDispose((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) throw StateError('Not signed in');
  return ref.watch(vendorRepositoryProvider).dashboard(vendorId);
});

final vendorProductsProvider = FutureProvider.autoDispose((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  return ref.watch(vendorRepositoryProvider).products(vendorId);
});

final vendorServicesProvider = FutureProvider.autoDispose((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  return ref.watch(vendorRepositoryProvider).services(vendorId);
});

final vendorOrdersProvider = FutureProvider.autoDispose((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  return ref.watch(vendorRepositoryProvider).orders(vendorId);
});

final vendorBookingsProvider = FutureProvider.autoDispose((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  return ref.watch(vendorRepositoryProvider).bookings(vendorId);
});

final vendorSettlementsProvider = FutureProvider.autoDispose((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  return ref.watch(vendorRepositoryProvider).settlements(vendorId);
});

final settlementStatsProvider = FutureProvider.autoDispose((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) throw StateError('Not signed in');
  return ref.watch(vendorRepositoryProvider).settlementStats(vendorId);
});

final vendorProfileProvider = FutureProvider.autoDispose((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <String, dynamic>{};
  return ref.watch(vendorRepositoryProvider).profile(vendorId);
});

final vendorBanksProvider = FutureProvider.autoDispose((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  return ref.watch(vendorRepositoryProvider).bankAccounts(vendorId);
});
