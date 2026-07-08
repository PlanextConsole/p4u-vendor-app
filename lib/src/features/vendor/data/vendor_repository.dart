import 'dart:io';

import '../../../core/services/api_client.dart';
import '../domain/vendor_models.dart';

class VendorRepository {
  VendorRepository({ApiClient? api}) : _api = api ?? ApiClient();

  static const demoVendorId = 'demo-vendor';

  final ApiClient _api;

  bool _isDemo(String vendorId) => vendorId == demoVendorId;

  Future<VendorDashboard> dashboard(String vendorId) async {
    if (_isDemo(vendorId)) {
      return VendorDashboard(
        vendor: _demoVendor,
        products: _demoProducts,
        services: _demoServices,
        orders: _demoOrders,
        settlements: _demoSettlements,
      );
    }
    final vendor = await profile(vendorId);
    final products = await this.products(vendorId);
    final services = await this.services(vendorId);
    final orders = await this.orders(vendorId);
    final settlements = await this.settlements(vendorId);
    return VendorDashboard(vendor: vendor, products: products, services: services, orders: orders, settlements: settlements);
  }

  Future<List<Map<String, dynamic>>> products(String vendorId) async {
    if (_isDemo(vendorId)) return _demoProducts;
    final rows = await _safeList(() => _api.getList('/api/v1/vendor/me/products', auth: true));
    return rows.map(_normalizeProduct).toList();
  }

  Future<List<Map<String, dynamic>>> states() async => const [
        {'id': 'TN', 'name': 'Tamil Nadu', 'code': 'TN'},
        {'id': 'KL', 'name': 'Kerala', 'code': 'KL'},
        {'id': 'KA', 'name': 'Karnataka', 'code': 'KA'},
        {'id': 'AP', 'name': 'Andhra Pradesh', 'code': 'AP'},
        {'id': 'TS', 'name': 'Telangana', 'code': 'TS'},
        {'id': 'MH', 'name': 'Maharashtra', 'code': 'MH'},
      ];

  Future<List<Map<String, dynamic>>> districts(String stateId) async {
    const districts = {
      'TN': ['Ariyalur', 'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore', 'Dharmapuri', 'Dindigul', 'Erode', 'Kanchipuram', 'Kanyakumari', 'Karur', 'Madurai', 'Salem', 'Thanjavur', 'Tiruchirappalli', 'Tirunelveli', 'Tiruppur', 'Vellore'],
      'KL': ['Ernakulam', 'Kollam', 'Kottayam', 'Kozhikode', 'Thiruvananthapuram', 'Thrissur'],
      'KA': ['Bengaluru Urban', 'Mysuru', 'Mangaluru', 'Hubballi', 'Belagavi'],
      'AP': ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Tirupati'],
      'TS': ['Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar'],
      'MH': ['Mumbai', 'Pune', 'Nagpur', 'Nashik'],
    };
    return (districts[stateId] ?? const ['Other'])
        .map((name) => {'id': name, 'name': name, 'state_id': stateId})
        .toList();
  }

  Future<String?> checkVendorPhoneUnique(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 10) return null;
    final normalized = '+91$cleaned';
    try {
      final data = await _api.postJson('/api/auth/public/vendor/phone-status', body: {'phone': normalized});
      final available = data['available'] ?? data['isAvailable'];
      if (available == false) return 'This mobile number is already registered as a vendor.';
      final status = data.s('status').toLowerCase();
      if (['registered', 'pending', 'submitted', 'approved'].contains(status)) {
        return 'A vendor account or application with this phone number already exists.';
      }
    } catch (_) {}
    return null;
  }

  Future<String?> checkVendorEmailUnique(String email) async => null;

  Future<String> uploadRegistrationFile(File file, String field, String contentType) async {
    if (!await apiSession.hasToken()) {
      final fileName = file.path.split(RegExp(r'[\\/]')).last;
      return 'pending-upload://$field/$fileName';
    }
    final path = contentType == 'application/pdf' ? '/api/v1/vendor/me/documents/upload' : '/api/v1/vendor/me/upload';
    final data = await _api.uploadFile(path, file, contentType: contentType, auth: true);
    return _uploadedUrl(data);
  }

  Future<void> submitVendorApplication(Map<String, dynamic> payload) async {
    await _api.postJson('/api/auth/public/vendor/register', body: _vendorRegistrationPayload(payload));
  }

  Future<void> upsertProduct(String vendorId, Map<String, dynamic> values, {String? id}) async {
    if (_isDemo(vendorId)) return;
    final payload = _productPayload(values);
    if (id == null) {
      await _api.postJson('/api/v1/vendor/me/products', body: payload, auth: true);
    } else {
      await _api.patchJson('/api/v1/vendor/me/products/$id', body: payload, auth: true);
    }
  }

  Future<void> deleteProduct(String id) async {
    if (id.startsWith('DEMO-')) return;
    await _api.deleteJson('/api/v1/vendor/me/products/$id', auth: true);
  }

  Future<List<Map<String, dynamic>>> services(String vendorId) async {
    if (_isDemo(vendorId)) return _demoServices;
    final rows = await _safeList(() => _api.getList('/api/v1/vendor/me/vendor-services', auth: true));
    return rows.map(_normalizeService).toList();
  }

  Future<void> upsertService(String vendorId, Map<String, dynamic> values, {String? id}) async {
    if (_isDemo(vendorId)) return;
    final payload = _servicePayload(values);
    if (id == null) {
      await _api.postJson('/api/v1/vendor/me/vendor-services', body: payload, auth: true);
    } else {
      await _api.patchJson('/api/v1/vendor/me/vendor-services/$id', body: payload, auth: true);
    }
  }

  Future<void> deleteService(String id) async {
    if (id.startsWith('DEMO-')) return;
    await _api.deleteJson('/api/v1/vendor/me/vendor-services/$id', auth: true);
  }

  Future<void> ensureServiceVendor(String vendorId) async {}

  Future<List<Map<String, dynamic>>> orders(String vendorId) async {
    if (_isDemo(vendorId)) return _demoOrders;
    final rows = await _safeList(() => _api.getList('/api/v1/vendor/orders', auth: true));
    return rows.map(_normalizeOrder).toList();
  }

  Future<void> updateOrderStatus(String id, String status, [Map<String, dynamic>? shippingData]) async {
    if (id.startsWith('DEMO-')) return;
    await _api.patchJson(
      '/api/v1/vendor/orders/$id',
      body: {'status': status, if (shippingData != null) 'metadata': shippingData},
      auth: true,
    );
  }

  Future<List<Map<String, dynamic>>> bookings(String vendorId) async {
    if (_isDemo(vendorId)) return _demoBookings;
    final rows = await _safeList(() => _api.getList('/api/v1/vendor/bookings', auth: true));
    return rows.map(_normalizeBooking).toList();
  }

  Future<void> updateBookingStatus(String id, String status) async {
    if (id.startsWith('DEMO-')) return;
    await _api.patchJson('/api/v1/vendor/bookings/$id', body: {'status': status}, auth: true);
  }

  Future<void> completeBooking(String id, File photo, String notes) async {
    if (id.startsWith('DEMO-')) return;
    final uploaded = await uploadVendorAsset('', photo, 'service-completions', photo.path.split(RegExp(r'[\\/]')).last, 'image/jpeg');
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
    if (_isDemo(vendorId)) return _demoSettlements;
    final rows = await _safeList(() => _api.getList('/api/v1/vendor/me/settlements', auth: true));
    return rows.map(_normalizeSettlement).toList();
  }

  Future<SettlementStats> settlementStats(String vendorId) async {
    final rows = await settlements(vendorId);
    double sumWhere(bool Function(Map<String, dynamic>) test) =>
        rows.where(test).fold(0, (sum, row) => sum + moneyOf(row, 'net_amount'));
    return SettlementStats(
      totalEarned: sumWhere((_) => true),
      pending: sumWhere((r) => ['pending', 'eligible'].contains(r['status'])),
      settled: sumWhere((r) => r['status'] == 'settled'),
      rejected: sumWhere((r) => r['status'] == 'rejected'),
    );
  }

  Future<Map<String, dynamic>> profile(String vendorId) async {
    if (_isDemo(vendorId)) return _demoVendor;
    final data = await _safeMap(() => _api.getJson('/api/v1/vendor/me', auth: true));
    final source = apiObject(data?['vendor'] ?? data?['profile'] ?? data?['data'] ?? data) ?? {};
    final normalized = _normalizeVendor(source);
    if (normalized.isNotEmpty) await apiSession.saveProfile(normalized);
    return normalized;
  }

  Future<void> updateProfile(String vendorId, Map<String, dynamic> values) async {
    if (_isDemo(vendorId)) return;
    await _api.patchJson('/api/v1/vendor/me', body: _vendorPatchPayload(values), auth: true);
  }

  Future<String> uploadVendorAsset(String vendorId, File file, String folder, String fileName, String contentType) async {
    if (_isDemo(vendorId)) return '';
    final path = contentType == 'application/pdf' ? '/api/v1/vendor/me/documents/upload' : '/api/v1/vendor/me/upload';
    final data = await _api.uploadFile(path, file, fields: {'folder': folder}, contentType: contentType, auth: true);
    return _uploadedUrl(data);
  }

  Future<List<Map<String, dynamic>>> bankAccounts(String vendorId) async {
    if (_isDemo(vendorId)) return _demoBankAccounts;
    final vendor = await profile(vendorId);
    final bank = vendor['bankJson'] ?? vendor['bank_json'] ?? vendor['bank'];
    if (bank is! Map) return [];
    return [
      {
        'id': 'primary',
        'account_holder_name': bank['accountHolder'] ?? bank['account_holder_name'] ?? bank['accountHolderName'],
        'bank_name': bank['bankName'] ?? bank['bank_name'] ?? '',
        'account_number': bank['accountNumber'] ?? bank['account_number'],
        'ifsc_code': bank['ifsc'] ?? bank['ifscCode'] ?? bank['ifsc_code'],
        'is_primary': true,
      }
    ];
  }

  Future<void> addBankAccount(String vendorId, Map<String, dynamic> values, bool primary) async {
    if (_isDemo(vendorId)) return;
    await updateProfile(vendorId, {'bankJson': _bankPayload(values)});
  }

  Future<void> setPrimaryBank(String vendorId, String id) async {}

  Future<void> deleteBank(String id) async {
    if (id.startsWith('DEMO-')) return;
    await _api.patchJson('/api/v1/vendor/me', body: {'bankJson': null}, auth: true);
  }

  Future<List<Map<String, dynamic>>> availability(String vendorId) async {
    if (_isDemo(vendorId)) return _demoAvailability;
    final data = await _safeMap(() => _api.getJson('/api/v1/vendor/me/booking-availability', auth: true));
    final weekly = data?['weekly'];
    if (weekly is Map) {
      return weekly.entries
          .map((entry) {
            final slot = entry.value is Map ? Map<String, dynamic>.from(entry.value as Map) : <String, dynamic>{};
            return {
              'id': 'day-${entry.key}',
              'day_of_week': int.tryParse(entry.key.toString()) ?? 0,
              'is_available': slot['enabled'] ?? false,
              'start_time': slot['start'] ?? '09:00',
              'end_time': slot['end'] ?? '18:00',
            };
          })
          .toList()
        ..sort((a, b) => (a['day_of_week'] as int).compareTo(b['day_of_week'] as int));
    }
    return apiItems(data);
  }

  Future<void> saveAvailability(String vendorId, List<Map<String, dynamic>> rows) async {
    if (_isDemo(vendorId)) return;
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
      body: {'version': 1, 'todayClosed': false, 'defaultSlotMinutes': 60, 'weekly': weekly, 'dateOffs': []},
      auth: true,
    );
  }

  Future<List<Map<String, dynamic>>> media(String vendorId, {String folder = 'all', String search = ''}) async {
    if (_isDemo(vendorId)) return _demoMedia;
    final rows = await _safeList(
      () => _api.getList(
        '/api/v1/vendor/me/media/assets',
        query: {'q': search, 'type': folder == 'all' ? null : folder, 'limit': 100, 'offset': 0},
        auth: true,
      ),
    );
    return rows.map(_normalizeMedia).toList();
  }

  Future<void> uploadMedia(String vendorId, File file, String fileName, String folder, String type) async {
    if (_isDemo(vendorId)) return;
    await uploadVendorAsset(vendorId, file, folder, fileName, type == 'documents' ? 'application/pdf' : 'image/jpeg');
  }

  Future<void> deleteMedia(Map<String, dynamic> item) async {
    if (item['id']?.toString().startsWith('DEMO-') == true) return;
    final id = item.s('id');
    if (id.isNotEmpty) await _api.deleteJson('/api/v1/vendor/me/media/assets/$id', auth: true);
  }

  Future<void> createSupportTicket({
    required String vendorId,
    required String vendorName,
    required String subject,
    required String description,
    required String category,
    required String priority,
  }) async {
    throw const ApiException('Vendor support tickets are not available in the new API collection yet.');
  }

  Future<void> deactivateVendor(String vendorId, String reason) async {
    if (_isDemo(vendorId)) return;
    await _api.patchJson('/api/v1/vendor/me', body: {'status': 'deactivated', 'metadata': {'reason': reason}}, auth: true);
  }

  Future<void> softDeleteVendor(String vendorId, String reason) async {
    if (_isDemo(vendorId)) return;
    await _api.patchJson('/api/v1/vendor/me', body: {'status': 'deletion_requested', 'metadata': {'reason': reason}}, auth: true);
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
      'categoriesJson': [if (form.s('subcategory').isNotEmpty) form.s('subcategory') else category],
      'servicesJson': category == 'service' || category == 'both' ? [if (form.s('subcategory').isNotEmpty) form.s('subcategory')] : [],
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
      'shortDescription': values.s('short_description', values.s('shortDescription')),
      'longDescription': values.s('long_description', values.s('longDescription')),
      'thumbnailUrl': values.s('image', values.s('thumbnailUrl')),
      'availability': values['availability'] ?? true,
      'isActive': values.s('status', 'active') == 'active',
      'metadata': {...values, 'stock': values.i('stock')},
    };
  }

  Map<String, dynamic> _servicePayload(Map<String, dynamic> values) => {
        'serviceId': values.s('service_id', values.s('serviceId', values.s('id'))),
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
        if (values['business_name'] != null || values['businessName'] != null) 'businessName': values['business_name'] ?? values['businessName'],
        if (values['name'] != null || values['ownerName'] != null) 'ownerName': values['name'] ?? values['ownerName'],
        if (values['email'] != null) 'email': values['email'],
        if (values['mobile'] != null || values['phone'] != null) 'phone': values['mobile'] ?? values['phone'],
        if (values['bankJson'] != null) 'bankJson': values['bankJson'],
        'metadata': values,
      };

  Map<String, dynamic> _bankPayload(Map<String, dynamic> values) => {
        'accountHolder': values.s('bank_holder_name', values.s('account_holder_name')),
        'accountNumber': values.s('bank_account_number', values.s('account_number')),
        'ifsc': values.s('bank_ifsc', values.s('ifsc_code')),
      };

  Map<String, dynamic> _normalizeVendor(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('vendorId')),
        'name': row.s('name', row.s('ownerName')),
        'business_name': row.s('business_name', row.s('businessName', row.s('storeName'))),
        'mobile': row.s('mobile', row.s('phone')),
      };

  Map<String, dynamic> _normalizeProduct(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('productId')),
        'title': row.s('title', row.s('name')),
        'price': row.n('price', row.n('sellPrice', row.n('finalPrice'))),
        'discount': row.n('discount', row.n('discountAmount')),
        'stock': row.i('stock', row.i('availableStock')),
        'image': row.s('image', row.s('thumbnailUrl')),
        'status': row.s('status', row['isActive'] == false ? 'inactive' : 'active'),
      };

  Map<String, dynamic> _normalizeService(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('linkId', row.s('id')),
        'service_id': row.s('serviceId', row.s('service_id')),
        'title': row.s('title', row.s('displayName', row.s('name'))),
        'price': row.n('price', row.n('basePrice')),
        'image': row.s('image', row.s('iconUrl')),
        'status': row.s('status', row['isActive'] == false ? 'inactive' : 'active'),
      };

  Map<String, dynamic> _normalizeOrder(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('orderId')),
        'total': row.n('total', row.n('totalAmount', row.n('grandTotal'))),
        'created_at': row.s('created_at', row.s('createdAt')),
        'payment_status': row.s('payment_status', row.s('paymentStatus')),
      };

  Map<String, dynamic> _normalizeBooking(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('bookingId')),
        'booking_date': row.s('booking_date', row.s('bookingDate')),
        'total_amount': row.n('total_amount', row.n('totalAmount')),
      };

  Map<String, dynamic> _normalizeSettlement(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('settlementId')),
        'net_amount': row.n('net_amount', row.n('netAmount', row.n('amount'))),
        'gross_amount': row.n('gross_amount', row.n('grossAmount')),
        'platform_fee': row.n('platform_fee', row.n('platformFee')),
      };

  Map<String, dynamic> _normalizeMedia(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('assetId')),
        'file_name': row.s('file_name', row.s('fileName', row.s('name'))),
        'file_url': row.s('file_url', row.s('fileUrl', row.s('url'))),
        'file_type': row.s('file_type', row.s('fileType', row.s('type'))),
        'file_size': row.i('file_size', row.i('fileSize')),
        'created_at': row.s('created_at', row.s('createdAt')),
      };

  String _uploadedUrl(Map<String, dynamic> data) {
    return data.s('url', data.s('fileUrl', data.s('file_url', data.s('path', data.s('publicUrl')))));
  }

  String _phone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10 ? '+91$digits' : value;
  }

  Future<List<Map<String, dynamic>>> _safeList(Future<List<Map<String, dynamic>>> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _safeMap(Future<Map<String, dynamic>> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> get _demoVendor => {
        'id': demoVendorId,
        'name': 'Demo Vendor',
        'business_name': 'Planext4u Demo Store',
        'email': 'demo.vendor@planext4u.test',
        'mobile': '+917449143583',
        'status': 'verified',
        'rating': 4.8,
        'total_orders': 28,
        'payment_status': 'paid',
        'plan': 'Premium',
      };

  List<Map<String, dynamic>> get _demoProducts => [
        {
          'id': 'DEMO-PRD-001',
          'title': 'Organic Grocery Pack',
          'sku': 'DEMO-GROCERY',
          'price': 699,
          'tax': 5,
          'discount': 50,
          'stock': 42,
          'status': 'active',
          'short_description': 'Demo product for testing',
          'long_description': 'A sample product used by the dummy vendor session.',
          'category_name': 'Groceries',
        },
        {
          'id': 'DEMO-PRD-002',
          'title': 'Home Essentials Kit',
          'sku': 'DEMO-HOME',
          'price': 1299,
          'tax': 12,
          'discount': 100,
          'stock': 18,
          'status': 'pending_approval',
          'short_description': 'Pending demo catalog item',
          'long_description': 'A sample pending item for approval-state testing.',
          'category_name': 'Home',
        },
      ];

  List<Map<String, dynamic>> get _demoServices => [
        {
          'id': 'DEMO-SVC-001',
          'title': 'AC Repair Visit',
          'price': 499,
          'tax': 18,
          'discount': 0,
          'status': 'active',
          'description': 'Demo service booking item',
        },
        {
          'id': 'DEMO-SVC-002',
          'title': 'Home Cleaning',
          'price': 899,
          'tax': 18,
          'discount': 50,
          'status': 'active',
          'description': 'Sample service for dummy login',
        },
      ];

  List<Map<String, dynamic>> get _demoOrders {
    final now = DateTime.now();
    return [
      {
        'id': 'DEMO-ORD-1001',
        'customer_name': 'Aarav Kumar',
        'status': 'placed',
        'total': 1549,
        'created_at': now.toIso8601String(),
        'items': [
          {'title': 'Organic Grocery Pack', 'qty': 1},
          {'title': 'Home Essentials Kit', 'qty': 1},
        ],
      },
      {
        'id': 'DEMO-ORD-1002',
        'customer_name': 'Meera Nair',
        'status': 'shipped',
        'total': 699,
        'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'shipping_type': 'courier',
        'tracking_number': 'DEMO123456',
        'items': [
          {'title': 'Organic Grocery Pack', 'qty': 1},
        ],
      },
      {
        'id': 'DEMO-ORD-1003',
        'customer_name': 'Ravi Shah',
        'status': 'delivered',
        'total': 1299,
        'created_at': now.subtract(const Duration(days: 5)).toIso8601String(),
        'items': [
          {'title': 'Home Essentials Kit', 'qty': 1},
        ],
      },
    ];
  }

  List<Map<String, dynamic>> get _demoBookings {
    final now = DateTime.now();
    return [
      {
        'id': 'DEMO-BKG-001',
        'customer_name': 'Priya S',
        'status': 'pending',
        'booking_date': now.add(const Duration(days: 1)).toIso8601String(),
        'total_amount': 499,
        'services': {'title': 'AC Repair Visit', 'price': 499},
      },
      {
        'id': 'DEMO-BKG-002',
        'customer_name': 'Kiran M',
        'status': 'accepted',
        'booking_date': now.add(const Duration(days: 3)).toIso8601String(),
        'total_amount': 899,
        'services': {'title': 'Home Cleaning', 'price': 899},
      },
    ];
  }

  List<Map<String, dynamic>> get _demoSettlements => [
        {
          'id': 'DEMO-SET-001',
          'status': 'eligible',
          'net_amount': 1849,
          'gross_amount': 1998,
          'platform_fee': 149,
          'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        },
        {
          'id': 'DEMO-SET-002',
          'status': 'settled',
          'net_amount': 1299,
          'gross_amount': 1399,
          'platform_fee': 100,
          'created_at': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
        },
      ];

  List<Map<String, dynamic>> get _demoBankAccounts => [
        {
          'id': 'DEMO-BANK-001',
          'account_holder_name': 'Demo Vendor',
          'bank_name': 'Demo Bank',
          'account_number': 'XXXXXX1234',
          'ifsc_code': 'DEMO0001234',
          'is_primary': true,
        },
      ];

  List<Map<String, dynamic>> get _demoAvailability => List.generate(
        7,
        (index) => {
          'id': 'DEMO-AV-$index',
          'day_of_week': index,
          'is_available': index != 0,
          'start_time': '09:00',
          'end_time': '18:00',
        },
      );

  List<Map<String, dynamic>> get _demoMedia => [
        {
          'id': 'DEMO-MEDIA-001',
          'file_name': 'demo-product.jpg',
          'file_url': '',
          'file_type': 'image',
          'file_size': 245760,
          'folder': 'vendor-demo/products',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];
}

extension _MapRead on Map<String, dynamic> {
  String s(String key, [String fallback = '']) => this[key]?.toString() ?? fallback;

  num n(String key, [num fallback = 0]) {
    final value = this[key];
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int i(String key, [int fallback = 0]) => n(key, fallback).round();
}
