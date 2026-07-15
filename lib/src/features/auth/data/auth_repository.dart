import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../../vendor/domain/vendor_models.dart';

Map<String, dynamic> _authPayloadFromPhoneExchange(
    Map<String, dynamic> exchange) {
  final nested = exchange['auth'];
  if (nested is Map<String, dynamic>) return nested;
  if (nested is Map) return Map<String, dynamic>.from(nested);
  return exchange;
}

bool _hasAccessToken(Map<String, dynamic> payload) =>
    payload['accessToken'] != null || payload['access_token'] != null;

class AuthRepository {
  AuthRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Stream<void> get authChanges => apiSession.changes;

  Future<VendorUser?> currentVendor() async {
    if (!await apiSession.hasToken()) return null;
    final cached = await apiSession.cachedProfile();
    try {
      final profile =
          _vendorFrom(await _api.getJson('/api/v1/vendor/me', auth: true));
      await apiSession.saveProfile(profile);
      return VendorUser.fromApi(profile,
          fallbackId: await apiSession.vendorId());
    } on ApiException catch (e) {
      // 401 only reaches here after a failed silent refresh (session is truly
      // dead) — clearing is correct. A 403 is a live-token authorization issue,
      // NOT an expiry, so it must not log the user out; fall back to the cache.
      if (e.statusCode == 401) {
        await apiSession.clear();
        return null;
      }
      if (cached != null) {
        return VendorUser.fromApi(cached,
            fallbackId: await apiSession.vendorId());
      }
      rethrow;
    }
  }

  Future<VendorUser> signInWithPassword(String email, String password) async {
    throw const ApiException(
        'Password login is not available in the new API yet. Please use Phone OTP.');
  }

  Future<VendorUser> signInWithFirebaseIdToken(String firebaseIdToken) async {
    final exchange = await _api.postJson(
      '/api/auth/public/phone/exchange',
      body: {'idToken': firebaseIdToken, 'intendedRole': 'VENDOR'},
    );
    final auth = _authPayloadFromPhoneExchange(exchange);
    if (exchange['loggedIn'] != true && !_hasAccessToken(auth)) {
      throw ApiException(
        exchange['registrationToken'] != null
            ? 'No vendor account found for this mobile number. Please complete vendor registration first.'
            : exchange['message']?.toString() ??
                auth['message']?.toString() ??
                'Phone verification failed.',
      );
    }
    await apiSession.saveAuth(auth);
    final profile = await _safeProfile();
    if (profile != null) await apiSession.saveProfile(profile);
    return VendorUser.fromApi(profile ?? auth,
        fallbackId: auth['vendorId']?.toString());
  }

  Future<void> signOut() async {
    final refresh = await apiSession.refreshToken();
    if (await apiSession.hasToken()) {
      await _api
          .postJson('/api/auth/logout',
              body: {'refreshToken': refresh}, auth: true)
          .catchError((_) => <String, dynamic>{});
    }
    await apiSession.clear();
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    await _api.postJson(
      '/api/auth/change-password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
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
    return apiObject(
            data['vendor'] ?? data['profile'] ?? data['data'] ?? data) ??
        data;
  }
}

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authStateProvider = StreamProvider<VendorUser?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  final fallbackId = await apiSession.vendorId();
  if (!await apiSession.hasToken()) {
    yield null;
  } else {
    final cached = await apiSession.cachedProfile();
    if (cached != null) {
      yield VendorUser.fromApi(cached, fallbackId: fallbackId);
    }
    yield await repo.currentVendor();
  }
  await for (final _ in repo.authChanges) {
    yield await repo.currentVendor();
  }
});
