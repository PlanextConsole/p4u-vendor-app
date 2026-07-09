import 'dart:convert';
import 'dart:io';

import '../../../core/services/api_client.dart';
import '../domain/vendor_models.dart';

class VendorRepository {
  VendorRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<VendorDashboard> dashboard(String vendorId) async {
    final vendor = await profile(vendorId);
    final vendorType = _vendorType(vendor);
    final hasProductFlow = vendorType != 'SERVICE';
    final hasServiceFlow = vendorType == 'SERVICE' || vendorType == 'BOTH';
    final products = hasProductFlow
        ? await this.products(vendorId)
        : <Map<String, dynamic>>[];
    final services = hasServiceFlow
        ? await this.services(vendorId)
        : <Map<String, dynamic>>[];
    final orders = hasProductFlow
        ? await this.orders(vendorId)
        : hasServiceFlow
            ? await bookings(vendorId)
            : <Map<String, dynamic>>[];
    final settlements = await this.settlements(vendorId);
    final rating = await ratingSummary(vendorId);
    return VendorDashboard(
        vendor: {...vendor, ...rating},
        products: products,
        services: services,
        orders: orders,
        settlements: settlements);
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
    final rows = await _safeList(
        () => _api.getList('/api/v1/vendor/me/vendor-services', auth: true));
    return rows.map(_normalizeService).toList();
  }

  Future<void> upsertService(String vendorId, Map<String, dynamic> values,
      {String? id}) async {
    final payload = _servicePayload(values);
    if (id == null) {
      await _api.postJson('/api/v1/vendor/me/vendor-services',
          body: payload, auth: true);
    } else {
      await _api.patchJson('/api/v1/vendor/me/vendor-services/$id',
          body: payload, auth: true);
    }
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
    await _api.patchJson(
      '/api/v1/vendor/orders/$id',
      body: {
        'status': status,
        if (shippingData != null) 'metadata': shippingData
      },
      auth: true,
    );
  }

  Future<List<Map<String, dynamic>>> bookings(String vendorId) async {
    final rows = await _safeList(
        () => _api.getList('/api/v1/vendor/bookings', auth: true));
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
        body: _vendorPatchPayload(values), auth: true);
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
    if (bank is! Map) return [];
    return [
      {
        'id': 'primary',
        'account_holder_name': bank['accountHolder'] ??
            bank['account_holder_name'] ??
            bank['accountHolderName'],
        'bank_name': bank['bankName'] ?? bank['bank_name'] ?? '',
        'account_number': bank['accountNumber'] ?? bank['account_number'],
        'ifsc_code': bank['ifsc'] ?? bank['ifscCode'] ?? bank['ifsc_code'],
        'is_primary': true,
      }
    ];
  }

  Future<void> addBankAccount(
      String vendorId, Map<String, dynamic> values, bool primary) async {
    await updateProfile(vendorId, {'bankJson': _bankPayload(values)});
  }

  Future<void> setPrimaryBank(String vendorId, String id) async {}

  Future<void> deleteBank(String id) async {
    await _api.patchJson('/api/v1/vendor/me',
        body: {'bankJson': null}, auth: true);
  }

  Future<List<Map<String, dynamic>>> availability(String vendorId) async {
    final data = await _safeMap(() =>
        _api.getJson('/api/v1/vendor/me/booking-availability', auth: true));
    final weekly = data?['weekly'];
    if (weekly is Map) {
      return weekly.entries.map((entry) {
        final slot = entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : <String, dynamic>{};
        return {
          'id': 'day-${entry.key}',
          'day_of_week': int.tryParse(entry.key.toString()) ?? 0,
          'is_available': slot['enabled'] ?? false,
          'start_time': slot['start'] ?? '09:00',
          'end_time': slot['end'] ?? '18:00',
        };
      }).toList()
        ..sort((a, b) =>
            (a['day_of_week'] as int).compareTo(b['day_of_week'] as int));
    }
    return apiItems(data);
  }

  Future<void> saveAvailability(
      String vendorId, List<Map<String, dynamic>> rows) async {
    final weekly = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      weekly[row.s('day_of_week')] = {
        'enabled': row['is_available'] == true,
        'start': row.s('start_time', '09:00'),
        'end': row.s('end_time', '18:00'),
        'bufferMinutes': 30,
        'customSlots': [],
      };
    }
    await _api.putJson(
      '/api/v1/vendor/me/booking-availability',
      body: {
        'version': 1,
        'todayClosed': false,
        'defaultSlotMinutes': 60,
        'weekly': weekly,
        'dateOffs': []
      },
      auth: true,
    );
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
      {String folder = 'all', String search = ''}) async {
    final rows = await _safeList(
      () => _api.getList(
        '/api/v1/vendor/me/media/assets',
        query: {
          'q': search,
          'type': folder == 'all' ? null : folder,
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
      String folder, String type) async {
    await uploadVendorAsset(vendorId, file, folder, fileName,
        type == 'documents' ? 'application/pdf' : 'image/jpeg');
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
    await _api.patchJson('/api/v1/vendor/me',
        body: {
          'status': 'deactivated',
          'metadata': {'reason': reason}
        },
        auth: true);
  }

  Future<void> softDeleteVendor(String vendorId, String reason) async {
    await _api.patchJson('/api/v1/vendor/me',
        body: {
          'status': 'deletion_requested',
          'metadata': {'reason': reason}
        },
        auth: true);
  }

  Map<String, dynamic> _vendorRegistrationPayload(Map<String, dynamic> form) {
    final category = form.s('category', 'product');
    return {
      'vendorKind': category,
      'vendorType': category.toUpperCase(),
      'ownerName': form.s('name'),
      'businessName': form.s('business_name'),
      'email': form.s('email'),
      'phone': _phone(form.s('phone')),
      'gst': form.s('gst_number'),
      'pan': form.s('pan_number'),
      'categoriesJson': [
        if (form.s('subcategory').isNotEmpty)
          form.s('subcategory')
        else
          category
      ],
      'servicesJson': category == 'service' || category == 'both'
          ? [if (form.s('subcategory').isNotEmpty) form.s('subcategory')]
          : [],
      'addressJson': {
        'state': form.s('state'),
        'district': form.s('district'),
        'city': form.s('district'),
        'address': form.s('shop_address'),
        'latitude': form['latitude'],
        'longitude': form['longitude'],
      },
      'documentsJson': {
        'storeLogo': form.s('store_logo_url'),
        'gstCertificate': form.s('gst_certificate_url'),
        'fssai': form.s('fssai_url'),
        'panImage': form.s('pan_image_url'),
        'aadhaarFront': form.s('aadhaar_front_url'),
        'aadhaarBack': form.s('aadhaar_back_url'),
      },
      'bankJson': _bankPayload(form),
    };
  }

  Map<String, dynamic> _productPayload(Map<String, dynamic> values) {
    final price = values.n('price');
    final discount = values.n('discount');
    final finalPrice = price - discount;
    return {
      'name': values.s('title', values.s('name')),
      'categoryId': values.s('category_id', values.s('categoryId')),
      'sellPrice': price.toStringAsFixed(2),
      'discountAmount': discount.toStringAsFixed(2),
      'finalPrice': (finalPrice < 0 ? 0 : finalPrice).toStringAsFixed(2),
      'shortDescription':
          values.s('short_description', values.s('shortDescription')),
      'longDescription':
          values.s('long_description', values.s('longDescription')),
      'thumbnailUrl': values.s('image', values.s('thumbnailUrl')),
      'availability': values['availability'] ?? true,
      'isActive': values.s('status', 'active') == 'active',
      'metadata': {...values, 'stock': values.i('stock')},
    };
  }

  Map<String, dynamic> _servicePayload(Map<String, dynamic> values) => {
        'serviceId':
            values.s('service_id', values.s('serviceId', values.s('id'))),
        'price': values.n('price').toStringAsFixed(2),
        'isActive': values.s('status', 'active') == 'active',
        'isAvailable': true,
        'displayName': values.s('title', values.s('displayName')),
        'description': values.s('description'),
        'iconUrl': values.s('image', values.s('iconUrl')),
        'basePrice': values.n('price').toStringAsFixed(2),
        'priceType': values.s('price_type', 'fixed'),
        'duration': values.s('duration'),
        'city': values.s('city'),
      };

  Map<String, dynamic> _vendorPatchPayload(Map<String, dynamic> values) => {
        if (values['business_name'] != null || values['businessName'] != null)
          'businessName': values['business_name'] ?? values['businessName'],
        if (values['name'] != null || values['ownerName'] != null)
          'ownerName': values['name'] ?? values['ownerName'],
        if (values['email'] != null) 'email': values['email'],
        if (values['mobile'] != null || values['phone'] != null)
          'phone': values['mobile'] ?? values['phone'],
        if (values['bankJson'] != null) 'bankJson': values['bankJson'],
        'metadata': values,
      };

  Map<String, dynamic> _bankPayload(Map<String, dynamic> values) => {
        'accountHolder':
            values.s('bank_holder_name', values.s('account_holder_name')),
        'accountNumber':
            values.s('bank_account_number', values.s('account_number')),
        'ifsc': values.s('bank_ifsc', values.s('ifsc_code')),
      };

  Map<String, dynamic> _normalizeVendor(Map<String, dynamic> row) {
    final vendorType = _vendorType(row);
    return {
      ...row,
      'id': row.s('id', row.s('vendorId')),
      'name': row.s('name', row.s('ownerName')),
      'business_name':
          row.s('business_name', row.s('businessName', row.s('storeName'))),
      'mobile': row.s('mobile', row.s('phone')),
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

  Map<String, dynamic> _normalizeProduct(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('productId')),
        'title': row.s('title', row.s('name')),
        'price': row.n('price', row.n('sellPrice', row.n('finalPrice'))),
        'discount': row.n('discount', row.n('discountAmount')),
        'stock': row.i('stock', row.i('availableStock')),
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
        'status':
            row.s('status', row['isActive'] == false ? 'inactive' : 'active'),
      };

  Map<String, dynamic> _normalizeService(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('linkId', row.s('id')),
        'service_id': row.s('serviceId', row.s('service_id')),
        'title': row.s('title', row.s('displayName', row.s('name'))),
        'price': row.n('price', row.n('basePrice')),
        'image': _resolveUrl(_imageFrom(row, const [
          'image',
          'imageUrl',
          'image_url',
          'iconUrl',
          'icon_url',
          'thumbnailUrl',
          'thumbnail_url',
          'images',
          'mediaUrls'
        ])),
        'status':
            row.s('status', row['isActive'] == false ? 'inactive' : 'active'),
      };

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
      row['service_name'],
      row['serviceName'],
      row['catalogName'],
      row['displayName'],
      metadata['serviceName'],
      metadata['catalogName'],
      metadata['displayName'],
      row['name'],
      row['title'],
    ]);
    final title = serviceName.isNotEmpty ? serviceName : 'Service booking';
    return {
      ...row,
      'id': row.s('id', row.s('bookingId')),
      'booking_date': row.s('booking_date', row.s('bookingDate')),
      'service_name': title,
      'serviceName': title,
      'order_title': title,
      'title': title,
      'customer_name': customer,
      'customerName': customer,
      'total_amount': row.n('total_amount', row.n('totalAmount')),
      'total': row.n('total', row.n('total_amount', row.n('totalAmount'))),
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
  Map<String, dynamic> _normalizeMedia(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('assetId')),
        'file_name': row.s('file_name', row.s('fileName', row.s('name'))),
        'file_url': _resolveUrl(_imageFrom(
            row, const ['file_url', 'fileUrl', 'url', 'path', 'publicUrl'])),
        'file_type': row.s('file_type', row.s('fileType', row.s('type'))),
        'file_size': row.i('file_size', row.i('fileSize')),
        'created_at': row.s('created_at', row.s('createdAt')),
      };

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
    } on ApiException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _safeMap(
      Future<Map<String, dynamic>> Function() loader) async {
    try {
      return await loader();
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }
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
