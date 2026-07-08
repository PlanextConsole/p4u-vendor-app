import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../../vendor/domain/vendor_models.dart';

class AuthRepository {
  AuthRepository({ApiClient? api}) : _api = api ?? ApiClient();

  static const demoVendorId = 'demo-vendor';
  static VendorUser? _demoVendor;

  final ApiClient _api;

  Stream<void> get authChanges => apiSession.changes;

  Future<VendorUser?> currentVendor() async {
    if (_demoVendor != null) return _demoVendor;
    if (!await apiSession.hasToken()) return null;
    final cached = await apiSession.cachedProfile();
    try {
      final profile = _vendorFrom(await _api.getJson('/api/v1/vendor/me', auth: true));
      await apiSession.saveProfile(profile);
      return VendorUser.fromApi(profile, fallbackId: await apiSession.vendorId());
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await apiSession.clear();
        return null;
      }
      if (cached != null) return VendorUser.fromApi(cached, fallbackId: await apiSession.vendorId());
      rethrow;
    }
  }

  Future<VendorUser> signInWithDemo() async {
    _demoVendor = const VendorUser(
      id: demoVendorId,
      name: 'Demo Vendor',
      email: 'demo.vendor@planext4u.test',
      businessName: 'Planext4u Demo Store',
      supabaseUid: 'demo-session',
      status: 'verified',
    );
    return _demoVendor!;
  }

  Future<VendorUser> signInWithPassword(String email, String password) async {
    throw const ApiException('Password login is not available in the new API yet. Please use Phone OTP.');
  }

  Future<VendorUser> signInWithFirebaseIdToken(String firebaseIdToken) async {
    final auth = await _api.postJson(
      '/api/auth/public/phone/exchange',
      body: {'idToken': firebaseIdToken, 'intendedRole': 'VENDOR'},
    );
    if (auth['accessToken'] == null && auth['access_token'] == null) {
      throw ApiException(auth['message']?.toString() ?? 'Phone verification failed.');
    }
    await apiSession.saveAuth(auth);
    final profile = await _safeProfile();
    if (profile != null) await apiSession.saveProfile(profile);
    return VendorUser.fromApi(profile ?? auth, fallbackId: auth['vendorId']?.toString());
  }

  Future<void> signOut() async {
    _demoVendor = null;
    final refresh = await apiSession.refreshToken();
    if (await apiSession.hasToken()) {
      await _api.postJson('/api/auth/logout', body: {'refreshToken': refresh}, auth: true).catchError((_) => <String, dynamic>{});
    }
    await apiSession.clear();
  }

  Future<void> updatePassword(String password) async {
    await _api.postJson(
      '/api/auth/change-password',
      body: {'currentPassword': '', 'newPassword': password},
      auth: true,
    );
  }

  Future<Map<String, dynamic>?> _safeProfile() async {
    try {
      return _vendorFrom(await _api.getJson('/api/v1/vendor/me', auth: true));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _vendorFrom(Map<String, dynamic> data) {
    return apiObject(data['vendor'] ?? data['profile'] ?? data['data'] ?? data) ?? data;
  }
}

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authStateProvider = StreamProvider<VendorUser?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield await repo.currentVendor();
  await for (final _ in repo.authChanges) {
    yield await repo.currentVendor();
  }
});
