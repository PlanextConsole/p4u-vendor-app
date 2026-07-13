import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(vendorProfileProvider);
    final dashboard = ref.watch(dashboardProvider);
    return VendorScaffold(
      title: 'Business Profile',
      child: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (vendor) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                    colors: [Color(0x330C831F), Color(0x110C831F)]),
                image: vendor['background_image'] != null
                    ? DecorationImage(
                        image: NetworkImage(vendor['background_image']),
                        fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                  onPressed: () => _uploadCover(context, ref),
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('Change Cover')),
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: AppCard(
                child: Row(
                  children: [
                    const CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.accent,
                        child: Icon(Icons.storefront_rounded,
                            size: 34, color: AppColors.primary)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(
                                    vendor['business_name']?.toString() ??
                                        'Business',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900))),
                            StatusBadge(
                                vendor['status']?.toString() ?? 'pending'),
                          ]),
                          Text(
                              '${vendor['name'] ?? ''} - Category ${vendor['category_id'] ?? ''}',
                              style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Business Details',
                            style: TextStyle(fontWeight: FontWeight.w800))),
                    TextButton.icon(
                        onPressed: () => _editProfile(context, ref, vendor),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit')),
                  ]),
                  _Detail(Icons.mail_outline_rounded, 'Email', vendor['email']),
                  _Detail(Icons.phone_rounded, 'Phone', vendor['mobile']),
                  _Detail(
                      Icons.location_on_outlined,
                      'Location',
                      vendor['shop_address'] ??
                          'Area ${vendor['area_id']}, City ${vendor['city_id']}'),
                  _Detail(Icons.verified_user_outlined, 'Commission Rate',
                      '${vendor['commission_rate'] ?? 0}%'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Plan & Payment',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              vendor['membership']?.toString() == 'premium'
                                  ? 'Premium Plan'
                                  : 'Basic Plan')),
                      StatusBadge(vendor['plan_payment_status']?.toString() ??
                          'unpaid'),
                    ],
                  ),
                  if (vendor['plan_transaction_id'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                          'Transaction ID: ${vendor['plan_transaction_id']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            dashboard.maybeWhen(
              data: (d) => GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: [
                  MetricCard(
                      icon: Icons.inventory_2_rounded,
                      label: 'Products',
                      value: '${d.products.length}'),
                  MetricCard(
                      icon: Icons.shopping_cart_rounded,
                      label: 'Orders',
                      value: '${d.orders.length}'),
                  MetricCard(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Revenue',
                      value: NumberFormat.compactCurrency(
                              locale: 'en_IN', symbol: 'Rs.')
                          .format(d.revenue)),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile(
      BuildContext context, WidgetRef ref, Map<String, dynamic> vendor) async {
    final vendorId = ref.read(vendorIdProvider);
    if (vendorId == null) return;
    final email =
        TextEditingController(text: vendor['email']?.toString() ?? '');
    final mobile =
        TextEditingController(text: vendor['mobile']?.toString() ?? '');
    final address =
        TextEditingController(text: vendor['shop_address']?.toString() ?? '');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, MediaQuery.viewInsetsOf(sheetContext).bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(
                controller: mobile,
                decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 10),
            TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Shop Address')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(vendorRepositoryProvider)
                    .updateProfile(vendorId, {
                  'email': email.text.trim(),
                  'mobile': mobile.text.trim(),
                  'shop_address': address.text.trim()
                });
                ref.invalidate(vendorProfileProvider);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadCover(BuildContext context, WidgetRef ref) async {
    final vendorId = ref.read(vendorIdProvider);
    if (vendorId == null) return;
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (picked == null) return;
    final url = await ref.read(vendorRepositoryProvider).uploadVendorAsset(
          vendorId,
          File(picked.path),
          'vendor-backgrounds',
          picked.name,
          picked.mimeType ?? 'image/jpeg',
        );
    await ref
        .read(vendorRepositoryProvider)
        .updateProfile(vendorId, {'background_image': url});
    ref.invalidate(vendorProfileProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cover image updated')));
    }
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black45),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
              Text(value?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }
}
