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
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  Future<void> saveAuth(Map<String, dynamic> data,
      {Map<String, dynamic>? profile}) async {
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
    _changes.add(null);
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

  static Future<void> _requestQueue = Future.value();

  final ApiSession session;
  static const _requestTimeout = Duration(seconds: 12);

  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  Future<void>? _refreshInFlight;

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
    request.add(await file.readAsBytes());
    request.write('\r\n--$boundary--\r\n');

    return _decodeResponse(await _withTimeout(request.close()));
  }

  Future<T> _runQueued<T>(Future<T> Function() action) {
    final queued = _requestQueue.then((_) async {
      await Future.delayed(const Duration(milliseconds: 40));
      return action();
    });
    _requestQueue = queued.then((_) {}, onError: (_) {});
    return queued;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) async {
    final isRead = method.toUpperCase() == 'GET';
    Future<Map<String, dynamic>> run() {
      Future<Map<String, dynamic>> action() =>
          _sendOnce(method, path, query: query, body: body, auth: auth);
      return isRead ? action() : _runQueued(action);
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await run();
      } on ApiException catch (e) {
        if (e.statusCode == 429 && attempt < 2) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        if (!auth || e.statusCode != 401) rethrow;
        await _refreshAuthDeduped();
        return run();
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
      await session.saveAuth(auth);
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
