import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../vendor/data/vendor_providers.dart';

class VendorRegisterPage extends ConsumerStatefulWidget {
  const VendorRegisterPage({super.key});

  @override
  ConsumerState<VendorRegisterPage> createState() => _VendorRegisterPageState();
}

class _VendorRegisterPageState extends ConsumerState<VendorRegisterPage> {
  int step = 1;
  bool loading = false;
  bool locating = false;

  final form = <String, dynamic>{
    'name': '',
    'phone': '',
    'secondary_phone': '',
    'email': '',
    'state': '',
    'district': '',
    'fb_link': '',
    'instagram_link': '',
    'business_name': '',
    'business_type': 'proprietorship',
    'store_name': '',
    'category': 'product',
    'subcategory': '',
    'business_description': '',
    'gst_number': '',
    'gst_certificate_url': '',
    'fssai_url': '',
    'pan_number': '',
    'pan_image_url': '',
    'aadhaar_number': '',
    'aadhaar_front_url': '',
    'aadhaar_back_url': '',
    'bank_account_number': '',
    'bank_confirm_account': '',
    'bank_ifsc': '',
    'bank_holder_name': '',
    'store_logo_url': '',
    'latitude': 0.0,
    'longitude': 0.0,
    'shop_address': '',
  };

  void _set(String key, Object? value) =>
      setState(() => form[key] = value ?? '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.arrow_back_rounded)),
        title: const Text('Vendor Registration'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text('Step $step of 5',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      Text('${_completion()}%',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                      value: step / 5,
                      color: AppColors.primary,
                      backgroundColor: AppColors.border),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['Personal', 'Business', 'KYC', 'Bank', 'Review']
                        .asMap()
                        .entries
                        .map((e) => Text(e.value,
                            style: TextStyle(
                                fontSize: 10,
                                color: step == e.key + 1
                                    ? AppColors.primary
                                    : Colors.black45,
                                fontWeight: step == e.key + 1
                                    ? FontWeight.w800
                                    : FontWeight.w500)))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (step == 1) _personalStep(),
            if (step == 2) _businessStep(),
            if (step == 3) _kycStep(),
            if (step == 4) _bankStep(),
            if (step == 5) _reviewStep(),
            const SizedBox(height: 16),
            Row(
              children: [
                if (step > 1)
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => setState(() => step--),
                          child: const Text('Back'))),
                if (step > 1) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: loading ? null : (step < 5 ? _next : _submit),
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(step < 5 ? 'Next' : 'Submit Application'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalStep() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Details',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _field('Name *', 'name',
              textCapitalization: TextCapitalization.words),
          _field('Phone *', 'phone',
              keyboard: TextInputType.phone, maxLength: 10),
          _field('Secondary Phone', 'secondary_phone',
              keyboard: TextInputType.phone, maxLength: 10),
          _field('Email *', 'email', keyboard: TextInputType.emailAddress),
          _field('State *', 'state',
              textCapitalization: TextCapitalization.words),
          _field('District *', 'district',
              textCapitalization: TextCapitalization.words),
          _field('Facebook URL', 'fb_link', keyboard: TextInputType.url),
          _field('Instagram URL', 'instagram_link',
              keyboard: TextInputType.url),
        ],
      ),
    );
  }

  Widget _businessStep() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Business Details',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _field('Business Name *', 'business_name'),
          _dropdown('Business Type', 'business_type',
              const ['proprietorship', 'partnership', 'pvt_ltd']),
          _dropdown(
              'Vendor Type', 'category', const ['product', 'service']),
          if (form['category'] == 'service')
            _field('Service Name *', 'subcategory')
          else
            _field('Product Category *', 'subcategory'),
          _field('Store Name', 'store_name'),
          _field('Business Description', 'business_description', maxLines: 4),
          _uploadTile('store_logo_url', 'Store Logo'),
          const Divider(height: 28),
          const Text('Shop Location *',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: locating ? null : _captureLocation,
            icon: locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.location_on_rounded),
            label: Text(form['latitude'] == 0
                ? 'Capture Shop Location'
                : 'Update Location'),
          ),
          _field('Shop Address', 'shop_address', maxLines: 2),
        ],
      ),
    );
  }

  Widget _kycStep() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('KYC Documents',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
              'Either Aadhaar or PAN is mandatory. Related document images are required.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          _field('Aadhaar Number', 'aadhaar_number',
              keyboard: TextInputType.number, maxLength: 12),
          _uploadTile('aadhaar_front_url', 'Aadhaar Front *'),
          _uploadTile('aadhaar_back_url', 'Aadhaar Back *'),
          const Divider(height: 28),
          _field('PAN Number', 'pan_number',
              textCapitalization: TextCapitalization.characters, maxLength: 10),
          _uploadTile('pan_image_url', 'PAN Image *'),
          const Divider(height: 28),
          _field('GST Number', 'gst_number',
              textCapitalization: TextCapitalization.characters, maxLength: 15),
          _uploadTile('gst_certificate_url', 'GST Certificate'),
          _uploadTile('fssai_url', 'FSSAI Certificate'),
        ],
      ),
    );
  }

  Widget _bankStep() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bank Verification',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _field('Account Holder Name', 'bank_holder_name'),
          _field('Account Number', 'bank_account_number',
              keyboard: TextInputType.number, maxLength: 18),
          _field('Confirm Account Number', 'bank_confirm_account',
              keyboard: TextInputType.number, maxLength: 18),
          _field('IFSC Code', 'bank_ifsc',
              textCapitalization: TextCapitalization.characters, maxLength: 11),
        ],
      ),
    );
  }

  Widget _reviewStep() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review & Submit',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _review('Name', form['name']),
          _review('Phone', form['phone']),
          _review('Email', form['email']),
          _review('Business', form['business_name']),
          _review('Vendor Type', form['category']),
          _review(form['category'] == 'service' ? 'Service' : 'Category',
              form['subcategory']),
          _review(
              'KYC',
              form['aadhaar_number'].toString().isNotEmpty
                  ? 'Aadhaar provided'
                  : form['pan_number'].toString().isNotEmpty
                      ? 'PAN provided'
                      : 'Missing'),
          _review(
              'Bank',
              form['bank_account_number'].toString().isNotEmpty
                  ? 'Provided'
                  : 'Not provided'),
        ],
      ),
    );
  }

  Widget _field(String label, String key,
      {TextInputType? keyboard,
      int? maxLength,
      int maxLines = 1,
      TextCapitalization textCapitalization = TextCapitalization.none}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: form[key]?.toString() ?? '',
        keyboardType: keyboard,
        maxLength: maxLength,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        decoration: InputDecoration(labelText: label, counterText: ''),
        onChanged: (v) {
          final clean = keyboard == TextInputType.phone ||
                  keyboard == TextInputType.number
              ? v.replaceAll(RegExp(r'\D'), '')
              : v;
          form[key] = clean;
        },
      ),
    );
  }

  Widget _dropdown(String label, String key, List<String> values,
      {ValueChanged<String>? onChanged}) {
    final value = values.contains(form[key]) ? form[key] as String : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          if (onChanged == null) {
            _set(key, v);
          } else {
            onChanged(v);
          }
        },
      ),
    );
  }

  Widget _uploadTile(String key, String label) {
    final hasFile = form[key]?.toString().isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => _pickUpload(key),
            icon: Icon(
                hasFile ? Icons.check_circle_rounded : Icons.upload_rounded,
                color: hasFile ? AppColors.success : null),
            label: Text(hasFile ? 'Uploaded' : 'Upload'),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          if (hasFile)
            IconButton(
                onPressed: () => _set(key, ''),
                icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }

  Widget _review(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(
              child: Text(value?.toString() ?? '',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Future<void> _pickUpload(String key) async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf']);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    if (await file.length() > 2 * 1024 * 1024) {
      _snack('File must be under 2MB');
      return;
    }
    final ext = result.files.single.extension?.toLowerCase();
    final contentType = ext == 'pdf' ? 'application/pdf' : 'image/jpeg';
    setState(() => loading = true);
    try {
      final url = await ref
          .read(vendorRepositoryProvider)
          .uploadRegistrationFile(file, key, contentType);
      _set(key, url);
      _snack('Uploaded');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _captureLocation() async {
    setState(() => locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _set('latitude', pos.latitude);
      _set('longitude', pos.longitude);
      if (form['shop_address'].toString().isEmpty) {
        _set('shop_address',
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}');
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _next() async {
    final err = _validate();
    if (err != null) {
      _snack(err);
      return;
    }
    if (step == 1) {
      setState(() => loading = true);
      try {
        final repo = ref.read(vendorRepositoryProvider);
        final phoneErr =
            await repo.checkVendorPhoneUnique(form['phone'].toString());
        if (phoneErr != null) return _snack(phoneErr);
        final emailErr =
            await repo.checkVendorEmailUnique(form['email'].toString());
        if (emailErr != null) return _snack(emailErr);
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }
    setState(() => step++);
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      _snack(err);
      return;
    }
    setState(() => loading = true);
    try {
      final payload = Map<String, dynamic>.from(form)
        ..remove('bank_confirm_account')
        ..addAll({
          'user_id': form['email'],
          'city': form['district'],
          'district': form['district'],
          'status': 'submitted',
        });
      await ref.read(vendorRepositoryProvider).submitVendorApplication(payload);
      if (mounted) {
        _snack('Application submitted. Our team will review it.');
        context.go('/login');
      }
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String? _validate() {
    if (step == 1) {
      if (form['name'].toString().trim().length < 2) {
        return 'Name must be at least 2 characters';
      }
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(form['phone'].toString())) {
        return 'Enter a valid 10-digit phone number';
      }
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
          .hasMatch(form['email'].toString())) {
        return 'Enter a valid email';
      }
    }
    if (step == 2) {
      if (form['business_name'].toString().trim().isEmpty) {
        return 'Business name is required';
      }
      if (form['subcategory'].toString().trim().isEmpty) {
        return form['category'] == 'service'
            ? 'Service name is required'
            : 'Product category is required';
      }
    }
    if (step == 3) {
      final aadhaar = form['aadhaar_number'].toString();
      final pan = form['pan_number'].toString();
      final gst = form['gst_number'].toString();
      if (aadhaar.isEmpty && pan.isEmpty) {
        return 'Either Aadhaar or PAN is required';
      }
      if (aadhaar.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(aadhaar)) {
        return 'Aadhaar must be 12 digits';
      }
      if (aadhaar.isNotEmpty &&
          (form['aadhaar_front_url'].toString().isEmpty ||
              form['aadhaar_back_url'].toString().isEmpty)) {
        return 'Aadhaar front and back images are required';
      }
      if (pan.isNotEmpty && !RegExp(r'^[A-Z0-9]{10}$').hasMatch(pan)) {
        return 'PAN must be 10 alphanumeric characters';
      }
      if (pan.isNotEmpty && form['pan_image_url'].toString().isEmpty) {
        return 'PAN card image is required';
      }
      if (gst.isNotEmpty && !RegExp(r'^[0-9A-Z]{15}$').hasMatch(gst)) {
        return 'GST must be 15 characters';
      }
      if (gst.isNotEmpty && form['gst_certificate_url'].toString().isEmpty) {
        return 'GST certificate is required';
      }
    }
    if (step == 4) {
      final account = form['bank_account_number'].toString();
      if (account.isNotEmpty && (account.length < 9 || account.length > 18)) {
        return 'Bank account number must be 9-18 digits';
      }
      if (account.isNotEmpty && account != form['bank_confirm_account']) {
        return 'Account numbers do not match';
      }
      final ifsc = form['bank_ifsc'].toString();
      if (ifsc.isNotEmpty &&
          !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
        return 'Enter a valid IFSC code';
      }
    }
    return null;
  }

  int _completion() {
    final keys = [
      'name',
      'phone',
      'email',
      'business_name',
      'business_description',
      'bank_account_number',
      'gst_number'
    ];
    var filled = keys.where((k) => form[k].toString().isNotEmpty).length;
    if (form['aadhaar_number'].toString().isNotEmpty ||
        form['pan_number'].toString().isNotEmpty) {
      filled++;
    }
    return ((filled / 8) * 100).round();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

