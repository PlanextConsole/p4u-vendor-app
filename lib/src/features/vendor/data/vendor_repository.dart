import 'dart:convert';
import 'dart:io';

import '../../../core/services/api_client.dart';
import '../domain/vendor_models.dart';
import 'bank_accounts.dart';

class VendorRepository {
  VendorRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Last loaded booking-availability DTO — cached so a save can preserve the
  /// fields the mobile editor doesn't expose (todayClosed, defaultSlotMinutes,
  /// per-day bufferMinutes, dateOffs/holidays) instead of wiping them.
  Map<String, dynamic>? _availabilityDto;

  Future<VendorDashboard> dashboard(String vendorId) async {
    final vendor = await profile(vendorId);
    final vendorType = _vendorType(vendor);
    final hasProductFlow = vendorType != 'SERVICE';
    final hasServiceFlow = vendorType == 'SERVICE' || vendorType == 'BOTH';

    final productsFuture = hasProductFlow
        ? products(vendorId)
        : Future.value(<Map<String, dynamic>>[]);
    final servicesFuture = hasServiceFlow
        ? services(vendorId)
        : Future.value(<Map<String, dynamic>>[]);
    final ordersFuture = hasProductFlow
        ? orders(vendorId)
        : hasServiceFlow
            ? bookings(vendorId)
            : Future.value(<Map<String, dynamic>>[]);
    final settlementsFuture = settlements(vendorId);
    final ratingFuture = ratingSummary(vendorId);

    final results = await Future.wait<Object>([
      productsFuture,
      servicesFuture,
      ordersFuture,
      settlementsFuture,
      ratingFuture,
    ]);

    return VendorDashboard(
      vendor: {...vendor, ...(results[4] as Map<String, dynamic>)},
      products: results[0] as List<Map<String, dynamic>>,
      services: results[1] as List<Map<String, dynamic>>,
      orders: results[2] as List<Map<String, dynamic>>,
      settlements: results[3] as List<Map<String, dynamic>>,
    );
  }

  Future<List<Map<String, dynamic>>> products(String vendorId) async {
    final rows = await _safeList(
        () => _api.getList('/api/v1/vendor/me/products', auth: true));
    return rows.map(_normalizeProduct).toList();
  }

  Future<String?> checkVendorPhoneUnique(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 10) return null;
    final normalized = '+91$cleaned';
    try {
      final data = await _api.postJson('/api/auth/public/vendor/phone-status',
          body: {'phone': normalized});
      final available = data['available'] ?? data['isAvailable'];
      if (available == false) {
        return 'This mobile number is already registered as a vendor.';
      }
      final status = data.s('status').toLowerCase();
      if (['registered', 'pending', 'submitted', 'approved'].contains(status)) {
        return 'A vendor account or application with this phone number already exists.';
      }
    } catch (_) {}
    return null;
  }

  Future<String?> checkVendorEmailUnique(String email) async => null;

  Future<String> uploadRegistrationFile(
      File file, String field, String contentType) async {
    final fileName = file.path.split(RegExp(r'[\\/]')).last;
    if (!await apiSession.hasToken()) return fileName;
    final path = contentType == 'application/pdf'
        ? '/api/v1/vendor/me/documents/upload'
        : '/api/v1/vendor/me/upload';
    final data =
        await _api.uploadFile(path, file, contentType: contentType, auth: true);
    return _uploadedUrl(data);
  }

  Future<void> submitVendorApplication(Map<String, dynamic> payload) async {
    await _api.postJson('/api/auth/public/vendor/register',
        body: _vendorRegistrationPayload(payload));
  }

  Future<void> upsertProduct(String vendorId, Map<String, dynamic> values,
      {String? id}) async {
    final payload = _productPayload(values);
    if (id == null) {
      await _api.postJson('/api/v1/vendor/me/products',
          body: payload, auth: true);
    } else {
      await _api.patchJson('/api/v1/vendor/me/products/$id',
          body: payload, auth: true);
    }
  }

  Future<void> deleteProduct(String id) async {
    await _api.deleteJson('/api/v1/vendor/me/products/$id', auth: true);
  }

  Future<List<Map<String, dynamic>>> services(String vendorId) async {
    try {
      final rows =
          await _api.getList('/api/v1/vendor/me/vendor-services', auth: true);
      return rows.map(_normalizeService).toList();
    } on ApiException catch (e) {
      if (_isMissingModerationColumn(e)) {
        return _servicesFromProfile(await profile(vendorId));
      }
      rethrow;
    }
  }

  /// Service categories used to drive the "Service category" dropdown in the
  /// My Services form (mirrors the vendor web `service-categories` list).
  Future<List<Map<String, dynamic>>> serviceCategories(String vendorId) async {
    final rows = await _safeList(() => _api
        .getList('/api/v1/vendor/me/catalog/service-categories', auth: true));
    return rows
        .map((row) => {
              'id': row.s('id'),
              'name': row.s('name'),
              'slug': row.s('slug'),
            })
        .where((row) => (row['id'] as String).isNotEmpty)
        .toList();
  }

  /// Catalog service templates used to drive the "Subcategory" dropdown and to
  /// auto-fill defaults when a template is chosen (mirrors the web
  /// `service-items` list).
  Future<List<Map<String, dynamic>>> catalogServiceItems(
      String vendorId) async {
    final rows = await _safeList(() =>
        _api.getList('/api/v1/vendor/me/catalog/service-items', auth: true));
    return rows
        .map((row) => {
              ...row,
              'id': row.s('id'),
              'service_category_id':
                  row.s('serviceCategoryId', row.s('service_category_id')),
              'name': row.s('name'),
              'description': row.s('description'),
              'icon_url':
                  _resolveUrl(_imageFrom(row, const ['iconUrl', 'icon_url'])),
              'base_price': row.s('basePrice', row.s('base_price')),
              'availability': row['availability'] ?? true,
              'trending': row['trending'] ?? false,
              'metadata': _metadata(row),
            })
        .where((row) => (row['id'] as String).isNotEmpty)
        .toList();
  }

  Future<void> upsertService(String vendorId, Map<String, dynamic> values,
      {String? id}) async {
    final payload = _servicePayload(values, includeServiceId: id == null);
    if (id == null) {
      await _api.postJson('/api/v1/vendor/me/vendor-services',
          body: payload, auth: true);
    } else {
      await _api.patchJson('/api/v1/vendor/me/vendor-services/$id',
          body: payload, auth: true);
    }
  }

  /// Minimal active/inactive toggle — matches the web which patches only
  /// `isActive` so the rest of the listing metadata is untouched.
  Future<void> setServiceActive(String id, bool active) async {
    await _api.patchJson('/api/v1/vendor/me/vendor-services/$id',
        body: {'isActive': active}, auth: true);
  }

  Future<void> deleteService(String id) async {
    await _api.deleteJson('/api/v1/vendor/me/vendor-services/$id', auth: true);
  }

  Future<void> ensureServiceVendor(String vendorId) async {}

  Future<List<Map<String, dynamic>>> orders(String vendorId) async {
    final rows = await _safeList(
        () => _api.getList('/api/v1/vendor/orders', auth: true));
    return rows.map(_normalizeOrder).toList();
  }

  Future<Map<String, dynamic>?> order(String id) async {
    final data = await _safeMap(
        () => _api.getJson('/api/v1/vendor/orders/$id', auth: true));
    return data == null ? null : _normalizeOrder(data);
  }

  Future<void> updateOrderStatus(String id, String status,
      [Map<String, dynamic>? shippingData]) async {
    Map<String, dynamic>? metadata;
    if (shippingData != null) {
      final current = await order(id);
      final existing = current?['metadata'];
      final base = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      // Merge shipping fields — never replace entire metadata (wipes line items).
      metadata = {...base, ...shippingData};
    }
    await _api.patchJson(
      '/api/v1/vendor/orders/$id',
      body: {
        'status': status,
        if (metadata != null) 'metadata': metadata,
      },
      auth: true,
    );
  }

  Future<List<Map<String, dynamic>>> bookings(String vendorId) async {
    final rows = await _safeList(() => _api.getList('/api/v1/vendor/bookings',
        query: {'limit': 50, 'offset': 0}, auth: true));
    return rows.map(_normalizeBooking).toList();
  }

  Future<Map<String, dynamic>?> booking(String id) async {
    final data = await _safeMap(
        () => _api.getJson('/api/v1/vendor/bookings/$id', auth: true));
    return data == null ? null : _normalizeBooking(data);
  }

  Future<void> updateBookingStatus(String id, String status) async {
    await _api.patchJson('/api/v1/vendor/bookings/$id',
        body: {'status': status}, auth: true);
  }

  Future<void> completeBooking(String id, File photo, String notes) async {
    final uploaded = await uploadVendorAsset('', photo, 'service-completions',
        photo.path.split(RegExp(r'[\\/]')).last, 'image/jpeg');
    await _api.patchJson(
      '/api/v1/vendor/bookings/$id',
      body: {
        'status': 'completed',
        'metadata': {'completionPhotoUrl': uploaded, 'completionNotes': notes},
      },
      auth: true,
    );
  }

  Future<List<Map<String, dynamic>>> settlements(String vendorId) async {
    final rows = await _safeList(
        () => _api.getList('/api/v1/vendor/me/settlements', auth: true));
    return rows.map(_normalizeSettlement).toList();
  }

  Future<Map<String, dynamic>?> settlement(String id) async {
    final data = await _safeMap(
        () => _api.getJson('/api/v1/vendor/me/settlements/$id', auth: true));
    return data == null ? null : _normalizeSettlement(data);
  }

  Future<SettlementStats> settlementStats(String vendorId) async {
    final rows = await settlements(vendorId);
    double sumWhere(bool Function(Map<String, dynamic>) test) => rows
        .where(test)
        .fold(0, (sum, row) => sum + moneyOf(row, 'net_amount'));
    return SettlementStats(
      totalEarned: sumWhere((_) => true),
      pending: sumWhere((r) => ['pending', 'eligible'].contains(r['status'])),
      settled: sumWhere((r) => r['status'] == 'settled'),
      rejected: sumWhere((r) => r['status'] == 'rejected'),
    );
  }

  Future<Map<String, dynamic>> ratingSummary(String vendorId) async {
    final data = await _safeMap(
        () => _api.getJson('/api/v1/vendor/me/rating-summary', auth: true));
    if (data == null) return {};
    return {
      'rating': data.n('averageRating', data.n('rating')),
      'review_count': data.i('reviewCount', data.i('totalReviews')),
      'total_orders': data.i('totalOrders'),
    };
  }

  Future<Map<String, dynamic>> planInfo(String vendorId) async {
    return await _safeMap(
            () => _api.getJson('/api/v1/vendor/me/plan', auth: true)) ??
        {};
  }

  Future<List<Map<String, dynamic>>> plans(String vendorId) async {
    return _safeList(() => _api.getList('/api/v1/vendor/me/plans', auth: true));
  }

  Future<Map<String, dynamic>> profile(String vendorId) async {
    final data =
        await _safeMap(() => _api.getJson('/api/v1/vendor/me', auth: true));
    final source = apiObject(
            data?['vendor'] ?? data?['profile'] ?? data?['data'] ?? data) ??
        {};
    final normalized = _normalizeVendor(source);
    if (normalized.isNotEmpty) await apiSession.saveProfile(normalized);
    return normalized;
  }

  Future<void> updateProfile(
      String vendorId, Map<String, dynamic> values) async {
    await _api.patchJson('/api/v1/vendor/me',
        body: await _vendorPatchBody(values), auth: true);
  }

  Future<String> uploadVendorAsset(String vendorId, File file, String folder,
      String fileName, String contentType) async {
    final path = contentType == 'application/pdf'
        ? '/api/v1/vendor/me/documents/upload'
        : '/api/v1/vendor/me/upload';
    final data = await _api.uploadFile(path, file,
        fields: {'folder': folder}, contentType: contentType, auth: true);
    return _uploadedUrl(data);
  }

  Future<List<Map<String, dynamic>>> bankAccounts(String vendorId) async {
    final vendor = await profile(vendorId);
    final bank = vendor['bankJson'] ?? vendor['bank_json'] ?? vendor['bank'];
    return parseBankAccounts(bank).map(bankAccountToUiRow).toList();
  }

  Future<void> addBankAccount(
      String vendorId, Map<String, dynamic> values, bool primary) async {
    final vendor = await profile(vendorId);
    final bank = vendor['bankJson'] ?? vendor['bank_json'] ?? vendor['bank'];
    final existing = parseBankAccounts(bank);
    final row = bankAccountFromForm(
      values,
      id: newBankAccountId(),
      isPrimary: existing.isEmpty || primary,
    );
    final next = [...existing, row];
    await updateProfile(vendorId, {'bankJson': serializeBankAccounts(next)});
  }

  Future<void> setPrimaryBank(String vendorId, String id) async {
    final vendor = await profile(vendorId);
    final bank = vendor['bankJson'] ?? vendor['bank_json'] ?? vendor['bank'];
    final existing = parseBankAccounts(bank);
    if (existing.isEmpty) return;
    final next = [
      for (final a in existing) {...a, 'isPrimary': a['id'] == id},
    ];
    await updateProfile(vendorId, {'bankJson': serializeBankAccounts(next)});
  }

  Future<void> deleteBank(String vendorId, String id) async {
    final vendor = await profile(vendorId);
    final bank = vendor['bankJson'] ?? vendor['bank_json'] ?? vendor['bank'];
    final next = parseBankAccounts(bank).where((a) => a['id'] != id).toList();
    await updateProfile(vendorId, {'bankJson': serializeBankAccounts(next)});
  }

  Future<List<Map<String, dynamic>>> availability(String vendorId) async {
    final data = await _safeMap(() =>
        _api.getJson('/api/v1/vendor/me/booking-availability', auth: true));
    // Web unwraps `{ availability: DTO }` — without this the schedule is blank
    // and saving rebuilds weekly from empty → wipe.
    final raw = data == null
        ? null
        : (data['availability'] is Map
            ? Map<String, dynamic>.from(data['availability'] as Map)
            : Map<String, dynamic>.from(data));
    _availabilityDto = raw;
    final weekly = raw?['weekly'];
    final rows = <Map<String, dynamic>>[];
    if (weekly is Map) {
      weekly.forEach((key, value) {
        final slot =
            value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
        final start = _hhmm(slot['start']?.toString() ?? '09:00');
        final end = _hhmm(slot['end']?.toString() ?? '18:00');
        // Primary window + any extra custom windows become the editor's slots.
        final slots = <Map<String, dynamic>>[
          {'start': start, 'end': end}
        ];
        final custom = slot['customSlots'];
        if (custom is List) {
          for (final entry in custom) {
            if (entry is Map) {
              slots.add({
                'start': _hhmm(entry['start']?.toString() ?? start),
                'end': _hhmm(entry['end']?.toString() ?? end),
              });
            }
          }
        }
        rows.add({
          'id': 'day-$key',
          'day_of_week': int.tryParse(key.toString()) ?? 0,
          'is_available': slot['enabled'] ?? false,
          'buffer_minutes': slot['bufferMinutes'] ?? 30,
          'time_slots': slots,
        });
      });
      rows.sort((a, b) =>
          (a['day_of_week'] as int).compareTo(b['day_of_week'] as int));
    }
    return rows;
  }

  Future<void> saveAvailability(
      String vendorId, List<Map<String, dynamic>> rows) async {
    final dto = _availabilityDto ?? const {};
    final existingWeekly = dto['weekly'] is Map
        ? Map<String, dynamic>.from(dto['weekly'] as Map)
        : <String, dynamic>{};
    final weekly = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final key = row.s('day_of_week');
      final prev = existingWeekly[key] is Map
          ? Map<String, dynamic>.from(existingWeekly[key] as Map)
          : <String, dynamic>{};
      final rawSlots =
          row['time_slots'] is List ? row['time_slots'] as List : const [];
      final normalized = rawSlots
          .whereType<Map>()
          .map((s) => {
                'start': _hhmm(s['start']?.toString() ?? '09:00'),
                'end': _hhmm(s['end']?.toString() ?? '18:00'),
              })
          .toList();
      final primary = normalized.isNotEmpty
          ? normalized.first
          : {'start': '09:00', 'end': '18:00'};
      final custom = normalized.length > 1 ? normalized.sublist(1) : const [];
      weekly[key] = {
        ...prev, // preserve any server fields the editor doesn't touch
        'enabled': row['is_available'] == true,
        'start': primary['start'],
        'end': primary['end'],
        'bufferMinutes': row['buffer_minutes'] ?? prev['bufferMinutes'] ?? 30,
        'customSlots': custom,
      };
    }
    await _api.putJson(
      '/api/v1/vendor/me/booking-availability',
      body: {
        'version': dto['version'] ?? 1,
        'todayClosed': dto['todayClosed'] ?? false,
        'defaultSlotMinutes': dto['defaultSlotMinutes'] ?? 60,
        'weekly': weekly,
        'dateOffs': dto['dateOffs'] is List ? dto['dateOffs'] : const [],
      },
      auth: true,
    );
  }

  /// Normalises a time string to 24h `HH:MM` (accepts `9:00 AM`, `09:00`, etc.).
  String _hhmm(String value) {
    final v = value.trim();
    final ampm = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(v);
    if (ampm != null) {
      var h = int.parse(ampm.group(1)!);
      final m = ampm.group(2)!;
      final pm = ampm.group(3)!.toLowerCase() == 'pm';
      if (pm && h != 12) h += 12;
      if (!pm && h == 12) h = 0;
      return '${h.toString().padLeft(2, '0')}:$m';
    }
    final hm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(v);
    if (hm != null) {
      return '${hm.group(1)!.padLeft(2, '0')}:${hm.group(2)}';
    }
    return v.isEmpty ? '09:00' : v;
  }

  Future<List<Map<String, dynamic>>> mediaFolders(String vendorId) async {
    final rows = await _safeList(
        () => _api.getList('/api/v1/vendor/me/media/folders', auth: true));
    return rows
        .map((row) => {
              ...row,
              'id': row.s('id', row.s('folderId')),
              'name': row.s('name'),
            })
        .toList();
  }

  Future<Map<String, dynamic>> createMediaFolder(
      String vendorId, String name) async {
    return _api.postJson('/api/v1/vendor/me/media/folders',
        body: {'name': name}, auth: true);
  }

  Future<void> deleteMediaFolder(String folderId) async {
    if (folderId.isEmpty) return;
    await _api.deleteJson('/api/v1/vendor/me/media/folders/$folderId',
        auth: true);
  }

  Future<List<Map<String, dynamic>>> media(String vendorId,
      {String type = 'all', String search = ''}) async {
    final filter = (type == 'images' || type == 'documents') ? type : 'all';
    final rows = await _safeList(
      () => _api.getList(
        '/api/v1/vendor/me/media/assets',
        query: {
          'q': search.isEmpty ? null : search,
          'type': filter,
          'limit': 100,
          'offset': 0
        },
        auth: true,
      ),
    );
    return rows.map(_normalizeMedia).toList();
  }

  Future<List<Map<String, dynamic>>> notifications(String vendorId) async {
    final rows = await _safeList(
        () => _api.getList('/api/v1/notifications/me', auth: true));
    return rows.map(_normalizeNotification).toList();
  }

  Future<void> markNotificationRead(String id) async {
    if (id.isEmpty) return;
    await _api.postJson('/api/v1/notifications/me/$id/read', auth: true);
  }

  Future<void> uploadMedia(String vendorId, File file, String fileName,
      String folderId, String contentType) async {
    await _api.uploadFile(
      '/api/v1/vendor/me/media/folders/$folderId/upload',
      file,
      contentType: contentType,
      auth: true,
    );
  }

  Future<void> deleteMedia(Map<String, dynamic> item) async {
    final id = item.s('id');
    if (id.isNotEmpty) {
      await _api.deleteJson('/api/v1/vendor/me/media/assets/$id', auth: true);
    }
  }

  Future<void> createSupportTicket({
    required String vendorId,
    required String vendorName,
    required String subject,
    required String description,
    required String category,
    required String priority,
  }) async {
    final vendor = await profile(vendorId);
    final metadata = vendor['metadata'] is Map
        ? Map<String, dynamic>.from(vendor['metadata'] as Map)
        : <String, dynamic>{};
    final tickets = apiItems(metadata['supportTickets']);
    tickets.insert(0, {
      'id': 'ticket-${DateTime.now().millisecondsSinceEpoch}',
      'vendorName': vendorName,
      'subject': subject,
      'description': description,
      'category': category,
      'priority': priority,
      'status': 'open',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _api.patchJson('/api/v1/vendor/me',
        body: {
          'metadata': {...metadata, 'supportTickets': tickets}
        },
        auth: true);
  }

  Future<void> deactivateVendor(String vendorId, String reason) async {
    await updateProfile(vendorId, {
      'notes': jsonEncode({
        'accountControl': 'deactivate',
        'reason': reason.isEmpty ? null : reason,
        'requestedAt': DateTime.now().toIso8601String(),
      }),
    });
  }

  Future<void> softDeleteVendor(String vendorId, String reason) async {
    await updateProfile(vendorId, {
      'notes': jsonEncode({
        'accountControl': 'delete',
        'reason': reason.isEmpty ? null : reason,
        'requestedAt': DateTime.now().toIso8601String(),
      }),
    });
  }

  Map<String, dynamic> _vendorRegistrationPayload(Map<String, dynamic> form) {
    final category = form.s('category', 'product').toLowerCase() == 'service'
        ? 'service'
        : 'product';
    final vendorType = category == 'service' ? 'SERVICE' : 'PRODUCT';
    final categoryOrService = form.s('subcategory').trim();
    final shopAddress = form.s('shop_address').trim();
    final state = form.s('state').trim();
    return {
      'vendorKind': category,
      'vendorType': vendorType,
      'ownerName': form.s('name'),
      'businessName': form.s('business_name'),
      'email': form.s('email').isEmpty ? null : form.s('email'),
      'phone': _phone(form.s('phone')),
      'gst': form.s('gst_number').isEmpty ? null : form.s('gst_number'),
      'pan': form.s('pan_number').isEmpty ? null : form.s('pan_number'),
      'categoriesJson': category == 'product' && categoryOrService.isNotEmpty
          ? [categoryOrService]
          : null,
      'servicesJson': category == 'service' && categoryOrService.isNotEmpty
          ? [categoryOrService]
          : null,
      'addressJson': {
        'state': state.isEmpty ? null : state,
        'stateName': state.isEmpty ? null : state,
        'district': form.s('district').isEmpty ? null : form.s('district'),
        'areaLocality': shopAddress.isEmpty ? null : shopAddress,
        'address': shopAddress.isEmpty ? null : shopAddress,
        'secondaryPhone': form.s('secondary_phone').isEmpty
            ? null
            : _phone(form.s('secondary_phone')),
        'facebook': form.s('fb_link').isEmpty ? null : form.s('fb_link'),
        'instagram': form.s('instagram_link').isEmpty
            ? null
            : form.s('instagram_link'),
        'latitude': form['latitude'],
        'longitude': form['longitude'],
      },
      'documentsJson': {
        'storeLogo': form.s('store_logo_url').isEmpty
            ? null
            : form.s('store_logo_url'),
        'gstCertificateFileName': form.s('gst_certificate_url').isEmpty
            ? null
            : form.s('gst_certificate_url'),
        'gstCertificate': form.s('gst_certificate_url').isEmpty
            ? null
            : form.s('gst_certificate_url'),
        'gstCertificateUrl': form.s('gst_certificate_url').isEmpty
            ? null
            : form.s('gst_certificate_url'),
        'fssai': form.s('fssai_url').isEmpty ? null : form.s('fssai_url'),
        'panCardFileName': form.s('pan_image_url').isEmpty
            ? null
            : form.s('pan_image_url'),
        'panImage': form.s('pan_image_url').isEmpty
            ? null
            : form.s('pan_image_url'),
        'panCardUrl': form.s('pan_image_url').isEmpty
            ? null
            : form.s('pan_image_url'),
        'aadhaarFront': form.s('aadhaar_front_url').isEmpty
            ? null
            : form.s('aadhaar_front_url'),
        'aadhaarBack': form.s('aadhaar_back_url').isEmpty
            ? null
            : form.s('aadhaar_back_url'),
        'aadhaarCardUrl': form.s('aadhaar_front_url').isEmpty
            ? null
            : form.s('aadhaar_front_url'),
      },
      'bankJson': _bankPayload(form),
    };
  }
  Map<String, dynamic> _productPayload(Map<String, dynamic> values) {
    final price = values.n('price');
    final discount = values.n('discount');
    final finalPrice = price - discount;
    final stock = values.i('stock', values.i('quantity'));
    final existingMeta = values['metadata'] is Map
        ? Map<String, dynamic>.from(values['metadata'] as Map)
        : <String, dynamic>{};
    return {
      'name': values.s('title', values.s('name')),
      'categoryId': values.s('category_id', values.s('categoryId')),
      if (values.s('taxConfigurationId', values.s('tax_configuration_id'))
          .isNotEmpty)
        'taxConfigurationId':
            values.s('taxConfigurationId', values.s('tax_configuration_id')),
      'sellPrice': price.toStringAsFixed(2),
      'discountAmount': discount.toStringAsFixed(2),
      'finalPrice': (finalPrice < 0 ? 0 : finalPrice).toStringAsFixed(2),
      'shortDescription':
          values.s('short_description', values.s('shortDescription')),
      'longDescription':
          values.s('long_description', values.s('longDescription')),
      'thumbnailUrl': values.s('image', values.s('thumbnailUrl')),
      'isActive': values.s('status', 'active') == 'active',
      'metadata': {
        ...existingMeta,
        'sku': values.s('sku', existingMeta.s('sku')),
        'productType':
            values.s('productType', existingMeta.s('productType', 'simple')),
        'quantity': stock,
        'stock': stock,
      },
    };
  }

  /// Builds the request body for create/patch of a vendor service offering,
  /// matching the vendor web contract (CreateVendorServiceOfferingDto). The
  /// base price drives both `price` and `basePrice`. `serviceId` (the catalog
  /// template id) is only sent on create — it cannot change on edit.
  Map<String, dynamic> _servicePayload(Map<String, dynamic> values,
      {required bool includeServiceId}) {
    final base = values.s('base_price', values.s('price')).trim();
    final priceType = values.s('price_type', 'fixed').trim();
    return {
      if (includeServiceId)
        'serviceId': values.s('service_id', values.s('serviceId')),
      'price': base,
      'isAvailable': values['availability'] ?? true,
      'displayName': _nullIfEmpty(values.s('title', values.s('displayName'))),
      'description': _nullIfEmpty(values.s('description')),
      'iconUrl': _nullIfEmpty(values.s('image', values.s('iconUrl'))),
      'trending': values['trending'] == true,
      'emergency': values['emergency'] == true,
      'basePrice': _nullIfEmpty(base),
      'priceType':
          const ['fixed', 'starting_from', 'hourly'].contains(priceType)
              ? priceType
              : 'fixed',
      'duration': _nullIfEmpty(values.s('duration')),
      'city': _nullIfEmpty(values.s('city')),
      // On edit the vendor may activate/deactivate from the form; the backend
      // ignores this while the listing is pending approval.
      if (!includeServiceId && values['is_active'] != null)
        'isActive': values['is_active'] == true,
    };
  }

  /// Builds a `PATCH /me` body that writes to the SAME fields the vendor web
  /// uses: shop address → `addressJson.areaLocality` (merged over the existing
  /// addressJson so state/district survive), cover → `bannerUrl`, logo →
  /// `logoUrl`. It no longer dumps the whole form into `metadata`.
  Future<Map<String, dynamic>> _vendorPatchBody(
      Map<String, dynamic> values) async {
    final body = <String, dynamic>{};
    if (values['business_name'] != null || values['businessName'] != null) {
      body['businessName'] = values['business_name'] ?? values['businessName'];
    }
    if (values['name'] != null || values['ownerName'] != null) {
      body['ownerName'] = values['name'] ?? values['ownerName'];
    }
    if (values['email'] != null) body['email'] = values['email'];
    if (values['mobile'] != null || values['phone'] != null) {
      body['phone'] = values['mobile'] ?? values['phone'];
    }
    if (values['bankJson'] != null) body['bankJson'] = values['bankJson'];
    if (values['status'] != null) body['status'] = values['status'];
    if (values['notes'] != null) body['notes'] = values['notes'];

    final banner = values['background_image'] ??
        values['bannerUrl'] ??
        values['banner_url'];
    if (banner != null) body['bannerUrl'] = banner;
    final logo =
        values['logo'] ?? values['logoUrl'] ?? values['store_logo_url'];
    if (logo != null) body['logoUrl'] = logo;

    final touchesAddress = values['shop_address'] != null ||
        values['latitude'] != null ||
        values['longitude'] != null ||
        values['addressJson'] is Map;
    if (touchesAddress) {
      final cached = await apiSession.cachedProfile() ?? const {};
      final existing = cached['addressJson'] ?? cached['address_json'];
      final addr = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      if (values['addressJson'] is Map) {
        addr.addAll(Map<String, dynamic>.from(values['addressJson'] as Map));
      }
      if (values['shop_address'] != null) {
        addr['areaLocality'] = values['shop_address'];
        addr['address'] = values['shop_address'];
      }
      if (values['latitude'] != null) addr['latitude'] = values['latitude'];
      if (values['longitude'] != null) addr['longitude'] = values['longitude'];
      body['addressJson'] = addr;
    }

    // Only forward metadata the caller explicitly set — don't pollute it.
    if (values['metadata'] is Map) body['metadata'] = values['metadata'];
    return body;
  }

  /// Registration / onboarding: persist a single primary account in the
  /// versioned `{ version: 1, accounts: [...] }` shape used by the bank page.
  Map<String, dynamic> _bankPayload(Map<String, dynamic> values) {
    final row = bankAccountFromForm(values, id: newBankAccountId(), isPrimary: true);
    final hasAny = (row['bankName'] as String).isNotEmpty ||
        (row['accountHolderName'] as String).isNotEmpty ||
        (row['accountNumber'] as String).isNotEmpty ||
        (row['ifscCode'] as String).isNotEmpty;
    if (!hasAny) {
      return serializeBankAccounts(const []);
    }
    return serializeBankAccounts([row]);
  }

  Map<String, dynamic> _normalizeVendor(Map<String, dynamic> row) {
    final vendorType = _vendorType(row);
    final addressJson = row['addressJson'] ?? row['address_json'];
    final area = addressJson is Map
        ? (addressJson['areaLocality'] ?? addressJson['address'] ?? '').toString()
        : '';
    return {
      ...row,
      'id': row.s('id', row.s('vendorId')),
      'name': row.s('name', row.s('ownerName')),
      'business_name':
          row.s('business_name', row.s('businessName', row.s('storeName'))),
      'mobile': row.s('mobile', row.s('phone')),
      'shop_address': row.s('shop_address').isNotEmpty
          ? row.s('shop_address')
          : area,
      'vendorType': vendorType,
      'vendor_type': vendorType,
      'vendorKind': vendorType,
      'vendor_kind': vendorType,
      'background_image': _resolveUrl(_imageFrom(row, const [
        'background_image',
        'backgroundImage',
        'bannerUrl',
        'banner_url',
        'coverImage',
        'thumbnailUrl'
      ])),
      'logo': _resolveUrl(_imageFrom(
          row, const ['logo', 'logoUrl', 'thumbnailUrl', 'thumbnail_url'])),
    };
  }

  Map<String, dynamic> _normalizeProduct(Map<String, dynamic> row) {
    final moderation = row
        .s('moderationStatus', row.s('moderation_status', 'approved'))
        .toLowerCase();
    final status = moderation == 'pending' || moderation == 'pending_approval'
        ? 'pending_approval'
        : row.s('status', row['isActive'] == false ? 'inactive' : 'active');
    final meta = _metadata(row);
    return {
      ...row,
      'id': row.s('id', row.s('productId')),
      'title': row.s('title', row.s('name')),
      'price': row.n('price', row.n('sellPrice', row.n('finalPrice'))),
      'discount': row.n('discount', row.n('discountAmount')),
      'stock': row.i('stock',
          row.i('availableStock', meta.i('quantity', meta.i('stock')))),
      'category_id': row.s('categoryId', row.s('category_id')),
      'image': _resolveUrl(_imageFrom(row, const [
        'image',
        'imageUrl',
        'image_url',
        'thumbnailUrl',
        'thumbnail_url',
        'primaryImageUrl',
        'primary_image_url',
        'images',
        'imageUrls',
        'mediaUrls'
      ])),
      'status': status,
      'moderation_status': moderation,
    };
  }
  Map<String, dynamic> _normalizeService(Map<String, dynamic> row) {
    final metadata = _metadata(row);
    final catalogMeta =
        _asMap(row['catalogMetadata'] ?? row['catalog_metadata']);
    // Web display rule: metadata.displayName || catalogName. Guard against raw
    // UUIDs sneaking through so the list never shows a service id as a name.
    final metaDisplay = _metaStr(metadata, 'displayName');
    final catalogName = row.s('catalogName', row.s('catalog_name'));
    final title = _readable(metaDisplay).isNotEmpty
        ? metaDisplay
        : _readable(catalogName).isNotEmpty
            ? catalogName
            : 'Service';
    final moderation = row
        .s('moderationStatus', row.s('moderation_status', 'approved'))
        .toLowerCase();
    final priceStr = row.s('price', row.s('basePrice', row.s('base_price')));
    final iconRaw = _metaStr(metadata, 'vendorIconUrl').isNotEmpty
        ? _metaStr(metadata, 'vendorIconUrl')
        : row.s('catalogIconUrl', row.s('catalog_icon_url'));
    return {
      ...row,
      'id': row.s('id', row.s('linkId')),
      'service_id': row.s('serviceId', row.s('service_id')),
      'category_id': row.s('categoryId', row.s('category_id')),
      'category_name': row.s('categoryName', row.s('category_name')),
      'catalog_name': catalogName,
      'title': title,
      'description': _firstNonEmpty([
        metadata['vendorDescription'],
        row['catalogDescription'],
        row['catalog_description'],
      ]),
      'price': row.n('price', row.n('basePrice', row.n('base_price'))),
      'base_price': _firstNonEmpty([metadata['referenceBasePrice'], priceStr]),
      'price_type': _metaStr(metadata, 'priceType', 'fixed'),
      'duration': _firstNonEmpty([metadata['duration'], catalogMeta['duration']]),
      'city': _metaStr(metadata, 'city'),
      'trending': metadata['trending'] == true,
      'emergency': metadata['emergency'] == true,
      'availability': row['isAvailable'] ?? row['availability'] ?? true,
      'is_active': row['isActive'] ?? true,
      'image': _resolveUrl(iconRaw),
      'moderationStatus': moderation,
      'status': moderation == 'pending'
          ? 'pending_approval'
          : (row['isActive'] == false ? 'inactive' : 'active'),
    };
  }

  Map<String, dynamic> _normalizeOrder(Map<String, dynamic> row) {
    final metadata = _metadata(row);
    final lines = _lineItems(row, metadata).map(_normalizeOrderLine).toList();
    final customer = _customerName(row, metadata);
    final displayRef = _displayOrderRef(row, metadata);
    final title = _orderTitle(row, metadata, lines, customer, displayRef);
    return {
      ...row,
      'id': row.s('id', row.s('orderId')),
      'order_ref': displayRef,
      'orderRef': displayRef,
      'order_title': title,
      'title': title,
      'customer_name': customer,
      'customerName': customer,
      'items': lines,
      'total': row.n('total', row.n('totalAmount', row.n('grandTotal'))),
      'created_at': row.s('created_at', row.s('createdAt')),
      'payment_status': row.s('payment_status', row.s('paymentStatus')),
    };
  }

  Map<String, dynamic> _normalizeBooking(Map<String, dynamic> row) {
    final metadata = _metadata(row);
    final customer = _customerName(row, metadata);
    final serviceName = _firstReadable([
      metadata['serviceName'],
      metadata['catalogName'],
      metadata['displayName'],
      row['service_name'],
      row['serviceName'],
      row['catalogName'],
      row['displayName'],
      row['name'],
      row['title'],
    ]);
    final title = serviceName.isNotEmpty ? serviceName : 'Service booking';
    return {
      ...row,
      'id': row.s('id', row.s('bookingId')),
      'booking_date': row.s('booking_date', row.s('bookingDate')),
      'bookingDate': row.s('bookingDate', row.s('booking_date')),
      'timeSlot': row.s('timeSlot', _bookingTimeSlot(row)),
      'start_time': row.s('start_time'),
      'end_time': row.s('end_time'),
      'service_name': title,
      'serviceName': title,
      'order_title': title,
      'title': title,
      'customer_name': customer,
      'customerName': customer,
      'total_amount': row.n('total_amount', row.n('totalAmount')),
      'totalAmount': row.n('totalAmount', row.n('total_amount')),
      'total': row.n('total', row.n('total_amount', row.n('totalAmount'))),
      'services': {
        'title': title,
        'price': row.n('total_amount', row.n('totalAmount'))
      },
    };
  }

  Map<String, dynamic> _normalizeSettlement(Map<String, dynamic> row) {
    final metadata = _metadata(row);
    final customer = _customerName(row, metadata);
    final orderRef = _firstReadable([
      metadata['orderRef'],
      metadata['order_ref'],
      row['orderRef'],
      row['order_ref'],
      row['orderNumber'],
      row['order_number'],
    ]);
    final displayRef = _firstReadable([
      metadata['displayRef'],
      metadata['settlementCode'],
      metadata['code'],
      row['settlementNumber'],
      row['settlement_number'],
      row['reference'],
      row['referenceNumber'],
    ]);
    final serviceName = _firstReadable([
      metadata['serviceName'],
      metadata['catalogName'],
      row['service_name'],
      row['serviceName'],
    ]);
    final settlementTitle = displayRef.isNotEmpty
        ? displayRef
        : serviceName.isNotEmpty
            ? '$serviceName settlement'
            : orderRef.isNotEmpty
                ? '$orderRef settlement'
                : customer.isNotEmpty && customer != 'Customer'
                    ? '$customer settlement'
                    : _shortCode('STL', row.s('id', row.s('settlementId')));
    return {
      ...row,
      'id': row.s('id', row.s('settlementId')),
      'settlement_title': settlementTitle,
      'title': settlementTitle,
      'order_label': orderRef,
      'order_ref': orderRef,
      'customer_name': customer,
      'customerName': customer,
      'net_amount': row.n('net_amount', row.n('netAmount', row.n('amount'))),
      'gross_amount':
          row.n('gross_amount', row.n('grossAmount', row.n('amount'))),
      'platform_fee':
          row.n('platform_fee', row.n('platformFee', row.n('commission'))),
      'amount': row.n('amount', row.n('gross_amount', row.n('grossAmount'))),
      'commission':
          row.n('commission', row.n('platform_fee', row.n('platformFee'))),
    };
  }

  Map<String, dynamic> _normalizeNotification(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('notificationId')),
        'title': row.s('title'),
        'body': row.s('body', row.s('message')),
        'status': row.s('status', row['read'] == true ? 'read' : 'unread'),
        'created_at': row.s('created_at', row.s('createdAt')),
      };
  Map<String, dynamic> _normalizeMedia(Map<String, dynamic> row) {
    final mime = row.s('mimeType', row.s('mime_type', row.s('fileType')));
    final type = mime.startsWith('image/')
        ? 'image'
        : (mime.contains('pdf') || mime.contains('document')
            ? 'document'
            : row.s('file_type', row.s('fileType', row.s('type', 'file'))));
    return {
      ...row,
      'id': row.s('id', row.s('assetId')),
      'file_name': row.s(
          'file_name',
          row.s('fileName',
              row.s('originalName', row.s('original_name', row.s('name'))))),
      'file_url': _resolveUrl(_imageFrom(
          row, const ['file_url', 'fileUrl', 'url', 'path', 'publicUrl'])),
      'file_type': type,
      'mime_type': mime,
      'file_size': row.i('file_size', row.i('fileSize', row.i('sizeBytes'))),
      'created_at': row.s('created_at', row.s('createdAt')),
    };
  }

  Map<String, dynamic> _metadata(Map<String, dynamic> row) {
    final raw = row['metadata'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _lineItems(
      Map<String, dynamic> row, Map<String, dynamic> metadata) {
    final raw = metadata['items'] ?? metadata['lines'] ?? row['items'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _servicesFromProfile(Map<String, dynamic> vendor) {
    final raw =
        vendor['servicesJson'] ?? vendor['services_json'] ?? vendor['services'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.asMap().entries.map((entry) {
      final value = entry.value;
      if (value is Map) {
        return _normalizeService(Map<String, dynamic>.from(value));
      }
      final title = value?.toString().trim() ?? '';
      return {
        'id': 'assigned-service-${entry.key}',
        'service_id': title,
        'title': title.isEmpty ? 'Assigned service' : title,
        'price': 0,
        'status': 'active',
      };
    }).toList();
  }

  bool _isMissingModerationColumn(ApiException e) {
    final text = '${e.message} ${e.details}'.toLowerCase();
    return text.contains('moderation_status') ||
        text.contains('catalogvendorservice.moderation_status');
  }

  String _bookingTimeSlot(Map<String, dynamic> row) {
    final existing = row.s('timeSlot', row.s('time_slot'));
    if (existing.isNotEmpty) return existing;
    final start = row.s('start_time', row.s('startTime'));
    final end = row.s('end_time', row.s('endTime'));
    if (start.isEmpty && end.isEmpty) return '';
    return '$start - $end'.trim();
  }

  Map<String, dynamic> _normalizeOrderLine(Map<String, dynamic> line) {
    final meta = _metadata(line);
    final title = _firstReadable([
      line['name'],
      line['productName'],
      line['product_name'],
      line['title'],
      meta['productName'],
      meta['name'],
      meta['title'],
    ]);
    return {
      ...line,
      'title': title.isEmpty ? 'Item' : title,
      'name': title.isEmpty ? 'Item' : title,
      'productName': title.isEmpty ? 'Item' : title,
      'qty': line['quantity'] ?? line['qty'] ?? 1,
      'quantity': line['quantity'] ?? line['qty'] ?? 1,
      'image': _resolveUrl(_imageFrom({
        ...meta,
        ...line
      }, const [
        'thumbnailUrl',
        'imageUrl',
        'productImage',
        'image',
        'thumbnail'
      ])),
    };
  }

  String _displayOrderRef(
      Map<String, dynamic> row, Map<String, dynamic> metadata) {
    final ref = _firstReadable([
      metadata['displayId'],
      metadata['orderRef'],
      metadata['order_ref'],
      row['orderRef'],
      row['order_ref'],
      row['orderNumber'],
      row['order_number'],
      row['orderCode'],
      row['order_code'],
    ]);
    return ref.isNotEmpty
        ? ref
        : _shortCode('ORD', row.s('id', row.s('orderId')));
  }

  String _customerName(
      Map<String, dynamic> row, Map<String, dynamic> metadata) {
    final customer = metadata['customer'] ?? row['customer'];
    final nested = customer is Map ? Map<String, dynamic>.from(customer) : null;
    final name = _firstReadable([
      metadata['customerName'],
      metadata['customer_name'],
      row['customerName'],
      row['customer_name'],
      nested?['name'],
      nested?['fullName'],
      nested?['full_name'],
      nested?['mobile'],
      nested?['phone'],
    ]);
    return name.isEmpty ? 'Customer' : name;
  }

  String _orderTitle(Map<String, dynamic> row, Map<String, dynamic> metadata,
      List<Map<String, dynamic>> lines, String customer, String displayRef) {
    final explicit = _firstReadable([
      row['title'],
      row['name'],
      metadata['title'],
      metadata['displayName'],
    ]);
    if (explicit.isNotEmpty) return explicit;
    if (lines.isNotEmpty) {
      final first = lines.first.s('title', lines.first.s('name'));
      if (first.isNotEmpty && first != 'Item') {
        return lines.length > 1 ? '$first + ${lines.length - 1} more' : first;
      }
    }
    if (customer.isNotEmpty && customer != 'Customer') return '$customer order';
    return displayRef.isNotEmpty ? displayRef : 'Customer order';
  }

  String _firstReadable(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && !_looksLikeUuid(text)) return text;
    }
    return '';
  }

  /// First non-empty string in [values] (UUIDs allowed — used for descriptions,
  /// durations and prices where a raw value is still meaningful).
  String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// Returns [value] when it is a non-UUID, non-empty string, else ''.
  String _readable(String value) {
    final text = value.trim();
    return text.isNotEmpty && !_looksLikeUuid(text) ? text : '';
  }

  String _metaStr(Map<String, dynamic> metadata, String key,
      [String fallback = '']) {
    final value = metadata[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  Object? _nullIfEmpty(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  String _shortCode(String prefix, String id) {
    final clean = id.replaceAll('-', '').trim();
    if (clean.length >= 7) {
      return '$prefix-${clean.substring(0, 3).toUpperCase()}-${clean.substring(clean.length - 4).toUpperCase()}';
    }
    return prefix;
  }

  bool _looksLikeUuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value.trim());
  String _vendorType(Map<String, dynamic> row) {
    final value = (row['vendorType'] ??
            row['vendor_type'] ??
            row['vendorKind'] ??
            row['vendor_kind'] ??
            row['category'] ??
            'PRODUCT')
        .toString()
        .trim()
        .toUpperCase();
    if (value == 'SERVICE' || value == 'BOTH') return value;
    return 'PRODUCT';
  }

  String _uploadedUrl(Map<String, dynamic> data) {
    return _resolveUrl(_imageFrom(
        data, const ['url', 'fileUrl', 'file_url', 'path', 'publicUrl']));
  }

  String _resolveUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty ||
        value.startsWith('http') ||
        value.startsWith('assets/')) {
      return value;
    }
    final normalized = value.startsWith('/') ? value : '/$value';
    return '${ApiClient.baseUrl}$normalized';
  }

  String _imageFrom(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final found = _firstString(row[key]);
      if (found.isNotEmpty) return found;
    }
    return '';
  }

  String _firstString(Object? value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) {
      for (final item in value) {
        final found = _firstString(item);
        if (found.isNotEmpty) return found;
      }
      return '';
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const [
        'url',
        'fileUrl',
        'file_url',
        'imageUrl',
        'image_url',
        'thumbnailUrl',
        'path'
      ]) {
        final found = _firstString(map[key]);
        if (found.isNotEmpty) return found;
      }
      return '';
    }
    return value.toString().trim();
  }

  String _phone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10 ? '+91$digits' : value;
  }

  Future<List<Map<String, dynamic>>> _safeList(
      Future<List<Map<String, dynamic>>> Function() loader) async {
    try {
      return await loader();
    } on ApiException catch (e) {
      if (_shouldKeepReadError(e)) rethrow;
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _safeMap(
      Future<Map<String, dynamic>> Function() loader) async {
    try {
      return await loader();
    } on ApiException catch (e) {
      if (_shouldKeepReadError(e)) rethrow;
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _shouldKeepReadError(ApiException e) =>
      e.statusCode == 401 || e.statusCode == 403;
}

extension _MapRead on Map<String, dynamic> {
  String s(String key, [String fallback = '']) =>
      this[key]?.toString() ?? fallback;

  num n(String key, [num fallback = 0]) {
    final value = this[key];
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int i(String key, [int fallback = 0]) => n(key, fallback).round();
}

