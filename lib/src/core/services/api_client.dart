import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => message;
}

class ApiSession {
  static const _accessTokenKey = 'p4u_vendor_access_token';
  static const _refreshTokenKey = 'p4u_vendor_refresh_token';
  static const _vendorIdKey = 'p4u_vendor_id';
  static const _rolesKey = 'p4u_vendor_roles';
  static const _profileKey = 'p4u_vendor_profile';

  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<String?> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<String?> vendorId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vendorIdKey);
  }

  Future<bool> hasToken() async =>
      (await accessToken())?.isNotEmpty == true ||
      (await refreshToken())?.isNotEmpty == true;

  Future<Map<String, dynamic>?> cachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      // A partially-written/corrupt cache must not prevent app startup.
      await prefs.remove(_profileKey);
      return null;
    }
  }

  Future<void> saveAuth(
    Map<String, dynamic> data, {
    Map<String, dynamic>? profile,
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final access = data['accessToken'] ?? data['access_token'];
    final refresh = data['refreshToken'] ?? data['refresh_token'];
    final vendorId = data['vendorId'] ?? data['vendor_id'];
    final roles = data['roles'];
    if (access != null) {
      await prefs.setString(_accessTokenKey, access.toString());
    }
    if (refresh != null) {
      await prefs.setString(_refreshTokenKey, refresh.toString());
    }
    if (vendorId != null) {
      await prefs.setString(_vendorIdKey, vendorId.toString());
    }
    if (roles != null) await prefs.setString(_rolesKey, jsonEncode(roles));
    if (profile != null) {
      await prefs.setString(_profileKey, jsonEncode(profile));
    }
    if (notify) _changes.add(null);
  }

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_vendorIdKey);
    await prefs.remove(_rolesKey);
    await prefs.remove(_profileKey);
    _changes.add(null);
  }
}

final apiSession = ApiSession();

class ApiClient {
  ApiClient({ApiSession? session}) : session = session ?? apiSession;

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.planext4u.com',
  );

  static Future<void>? _refreshInFlight;

  final ApiSession session;
  static const _requestTimeout = Duration(seconds: 30);
  static const _uploadTimeout = Duration(minutes: 2);

  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 20);

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, Object?> query = const {},
    bool auth = false,
  }) =>
      _send('GET', path, query: query, auth: auth);

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) =>
      _send('POST', path, query: query, body: body, auth: auth);

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) =>
      _send('PUT', path, query: query, body: body, auth: auth);

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) =>
      _send('PATCH', path, query: query, body: body, auth: auth);

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) =>
      _send('DELETE', path, query: query, body: body, auth: auth);

  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, Object?> query = const {},
    bool auth = false,
  }) async =>
      apiItems(await getJson(path, query: query, auth: auth));

  Future<Map<String, dynamic>> uploadFile(
    String path,
    File file, {
    String field = 'file',
    Map<String, Object?> fields = const {},
    String? contentType,
    bool auth = true,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _withUploadTimeout(_uploadFileOnce(
          path,
          file,
          field: field,
          fields: fields,
          contentType: contentType,
          auth: auth,
        ));
      } on ApiException catch (e) {
        if (!auth || e.statusCode != 401 || attempt > 0) rethrow;
        await _refreshAuthDeduped();
      }
    }
    throw const ApiException('Upload failed');
  }

  Future<Map<String, dynamic>> _uploadFileOnce(
    String path,
    File file, {
    required String field,
    required Map<String, Object?> fields,
    String? contentType,
    required bool auth,
  }) async {
    final request = await _withTimeout(_http.postUrl(_uri(path)));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (auth) await _attachAuth(request);

    final boundary = '----p4u-${DateTime.now().microsecondsSinceEpoch}';
    request.headers.contentType = ContentType('multipart', 'form-data',
        parameters: {'boundary': boundary});

    for (final entry in fields.entries) {
      if (entry.value == null) continue;
      request.write('--$boundary\r\n');
      request
          .write('Content-Disposition: form-data; name="${entry.key}"\r\n\r\n');
      request.write('${entry.value}\r\n');
    }

    final fileName = file.path.split(RegExp(r'[\\/]')).last;
    request.write('--$boundary\r\n');
    request.write(
        'Content-Disposition: form-data; name="$field"; filename="$fileName"\r\n');
    request.write(
        'Content-Type: ${contentType ?? 'application/octet-stream'}\r\n\r\n');
    // Stream from disk so large product/KYC files do not exhaust Android heap.
    await request.addStream(file.openRead());
    request.write('\r\n--$boundary--\r\n');

    return _decodeResponse(await _withTimeout(request.close()));
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _sendOnce(
          method,
          path,
          query: query,
          body: body,
          auth: auth,
        );
      } on ApiException catch (e) {
        if (e.statusCode == 429 && attempt < 2) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        if (!auth || e.statusCode != 401) rethrow;
        await _refreshAuthDeduped();
        return _sendOnce(
          method,
          path,
          query: query,
          body: body,
          auth: auth,
        );
      }
    }
    throw const ApiException(
        'Too many requests. Please wait a moment and try again.',
        statusCode: 429);
  }

  Future<Map<String, dynamic>> _sendOnce(
    String method,
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) async {
    final request =
        await _withTimeout(_http.openUrl(method, _uri(path, query)));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.contentType = ContentType.json;
    if (auth) await _attachAuth(request);
    if (body != null) request.write(jsonEncode(body));
    return _decodeResponse(await _withTimeout(request.close()));
  }

  Future<void> _refreshAuthDeduped() {
    final current = _refreshInFlight;
    if (current != null) return current;
    final refresh = _refreshAuth().whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = refresh;
    return refresh;
  }

  Future<void> _refreshAuth() async {
    final refreshToken = await session.refreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await session.clear();
      throw const ApiException('Session expired. Please login again.',
          statusCode: 401);
    }

    final request = await _withTimeout(
        _http.openUrl('POST', _uri('/api/auth/public/refresh')));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'refreshToken': refreshToken}));

    try {
      final data = await _decodeResponse(await _withTimeout(request.close()));
      final auth = apiObject(data['auth'] ?? data['data'] ?? data) ?? data;
      // Refreshing a token is an implementation detail. Broadcasting it as a
      // login event rebuilds the router and active data screens mid-request.
      await session.saveAuth(auth, notify: false);
    } on ApiException {
      rethrow;
    }
  }

  Future<T> _withTimeout<T>(Future<T> future) => future.timeout(
        _requestTimeout,
        onTimeout: () => throw const ApiException(
          'Network timeout. Please check your connection and try again.',
        ),
      );

  Future<T> _withUploadTimeout<T>(Future<T> future) => future.timeout(
        _uploadTimeout,
        onTimeout: () => throw const ApiException(
          'Upload timed out. Check your connection and try again.',
        ),
      );

  Uri _uri(String path, [Map<String, Object?> query = const {}]) {
    final base = Uri.parse(baseUrl);
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    final queryParams = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null || value.toString().isEmpty) continue;
      queryParams[entry.key] = value.toString();
    }
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}/$normalized',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  Future<void> _attachAuth(HttpClientRequest request) async {
    final token = await session.accessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('Please login to continue.', statusCode: 401);
    }
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }

  Future<Map<String, dynamic>> _decodeResponse(
      HttpClientResponse response) async {
    final raw = await _withTimeout(response.transform(utf8.decoder).join());
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : {'items': decoded};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message'] ??
          data['error'] ??
          data['code'] ??
          'API request failed';
      throw ApiException(message.toString(),
          statusCode: response.statusCode, details: data);
    }
    // Mirror web/customer client: unwrap `{ success: true, data: ... }`.
    if (data['success'] == true && data.containsKey('data')) {
      final inner = data['data'];
      if (inner is Map) {
        final result = Map<String, dynamic>.from(inner);
        for (final key in const ['total', 'limit', 'offset', 'page']) {
          if (data[key] != null && result[key] == null) {
            result[key] = data[key];
          }
        }
        return result;
      }
      if (inner is List) {
        return {
          'items': inner,
          if (data['total'] != null) 'total': data['total'],
          if (data['limit'] != null) 'limit': data['limit'],
          if (data['offset'] != null) 'offset': data['offset'],
        };
      }
    }
    return data;
  }
}

List<Map<String, dynamic>> apiItems(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    for (final key in [
      'items',
      'data',
      'results',
      'rows',
      'products',
      'services',
      'vendorServices',
      'orders',
      'bookings',
      'settlements',
      'assets',
      'media',
      'documents',
      'notifications',
      'folders',
      'categories',
      'suppliers',
    ]) {
      final nested = map[key];
      if (nested is List) return apiItems(nested);
      if (nested is Map) {
        final rows = apiItems(nested);
        if (rows.isNotEmpty) return rows;
      }
    }
  }
  return [];
}

Map<String, dynamic>? apiObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
