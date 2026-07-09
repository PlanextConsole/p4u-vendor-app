class VendorUser {
  const VendorUser({
    required this.id,
    required this.name,
    required this.email,
    required this.businessName,
    this.supabaseUid,
    this.status,
    this.vendorType = 'PRODUCT',
  });

  final String id;
  final String name;
  final String email;
  final String businessName;
  final String? supabaseUid;
  final String? status;
  final String vendorType;

  bool get isServiceVendor => vendorType.toUpperCase() == 'SERVICE';
  bool get isProductVendor => vendorType.toUpperCase() == 'PRODUCT';
  bool get isBothVendor => vendorType.toUpperCase() == 'BOTH';
  bool get hasProductFlow => isProductVendor || isBothVendor;
  bool get hasServiceFlow => isServiceVendor || isBothVendor;

  factory VendorUser.fromRole(Map<String, dynamic> role,
      Map<String, dynamic>? vendor, String uid, String fallbackEmail) {
    return VendorUser(
      id: (role['vendor_id'] ?? vendor?['id'] ?? '').toString(),
      name: (vendor?['name'] ?? '').toString(),
      email: (vendor?['email'] ?? fallbackEmail).toString(),
      businessName: (vendor?['business_name'] ?? vendor?['businessName'] ?? '')
          .toString(),
      supabaseUid: uid,
      status: vendor?['status']?.toString(),
      vendorType: _vendorType(vendor ?? role),
    );
  }

  factory VendorUser.fromApi(Map<String, dynamic> vendor,
      {String? fallbackId, String? userId}) {
    final id = (vendor['id'] ??
            vendor['vendorId'] ??
            vendor['vendor_id'] ??
            fallbackId ??
            '')
        .toString();
    return VendorUser(
      id: id,
      name:
          (vendor['ownerName'] ?? vendor['owner_name'] ?? vendor['name'] ?? '')
              .toString(),
      email: (vendor['email'] ?? '').toString(),
      businessName: (vendor['businessName'] ??
              vendor['business_name'] ??
              vendor['storeName'] ??
              vendor['store_name'] ??
              '')
          .toString(),
      supabaseUid: userId,
      status: vendor['status']?.toString(),
      vendorType: _vendorType(vendor),
    );
  }
}

class VendorDashboard {
  const VendorDashboard({
    required this.vendor,
    required this.products,
    required this.services,
    required this.orders,
    required this.settlements,
  });

  final Map<String, dynamic> vendor;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> settlements;

  bool get isServiceVendor => _vendorType(vendor) == 'SERVICE';
  bool get isBothVendor => _vendorType(vendor) == 'BOTH';
  bool get hasProductFlow => !isServiceVendor || isBothVendor;
  bool get hasServiceFlow => isServiceVendor || isBothVendor;

  double get revenue => orders
      .where((o) => o['status'] != 'cancelled')
      .fold(0, (sum, o) => sum + _num(o['total'] ?? o['total_amount']));

  int get activeOrders => orders
      .where((o) => !['completed', 'cancelled'].contains(o['status']))
      .length;
}

class SettlementStats {
  const SettlementStats({
    required this.totalEarned,
    required this.pending,
    required this.settled,
    required this.rejected,
  });

  final double totalEarned;
  final double pending;
  final double settled;
  final double rejected;
}

double moneyOf(Map<String, dynamic> row, String key) => _num(row[key]);

String _vendorType(Map<String, dynamic>? row) {
  final value = (row?['vendorType'] ??
          row?['vendor_type'] ??
          row?['vendorKind'] ??
          row?['vendor_kind'] ??
          row?['category'] ??
          'PRODUCT')
      .toString()
      .trim()
      .toUpperCase();
  if (value == 'SERVICE' || value == 'BOTH') return value;
  return 'PRODUCT';
}

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
