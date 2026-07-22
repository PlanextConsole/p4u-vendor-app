import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

class VendorKycPage extends ConsumerStatefulWidget {
  const VendorKycPage({super.key});
  @override
  ConsumerState<VendorKycPage> createState() => _VendorKycPageState();
}

class _VendorKycPageState extends ConsumerState<VendorKycPage> {
  bool _busy = false;
  Map<String, dynamic> _documents(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final value = jsonDecode(raw);
        if (value is Map) return Map<String, dynamic>.from(value);
      } catch (_) {}
    }
    return {};
  }

  Future<void> _upload(String key) async {
    final vendorId = ref.read(vendorIdProvider);
    if (vendorId == null) return;
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf']);
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final profile =
          await ref.read(vendorRepositoryProvider).profile(vendorId);
      final documents =
          _documents(profile['documentsJson'] ?? profile['documents_json']);
      final ext = path.split('.').last.toLowerCase();
      final url = await ref.read(vendorRepositoryProvider).uploadVendorAsset(
          vendorId,
          File(path),
          'vendor-kyc',
          result!.files.single.name,
          ext == 'pdf' ? 'application/pdf' : 'image/$ext');
      documents[key] = url;
      documents['${key}UploadedAt'] = DateTime.now().toUtc().toIso8601String();
      await ref
          .read(vendorRepositoryProvider)
          .updateProfile(vendorId, {'documentsJson': documents});
      ref.invalidate(vendorProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('KYC document saved')));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(vendorProfileProvider);
    return VendorScaffold(
        title: 'KYC & Verification',
        child: profile.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (vendor) {
              final docs = _documents(
                  vendor['documentsJson'] ?? vendor['documents_json']);
              final status = (vendor['status'] ?? 'pending').toString();
              const fields = <(String, String, IconData)>[
                (
                  'gstCertificate',
                  'GST certificate',
                  Icons.receipt_long_rounded
                ),
                ('panCardUrl', 'PAN card', Icons.badge_rounded),
                ('aadhaarFront', 'Aadhaar front', Icons.credit_card_rounded),
                ('aadhaarBack', 'Aadhaar back', Icons.credit_card_rounded),
                ('fssai', 'FSSAI certificate', Icons.restaurant_rounded),
              ];
              return ListView(padding: const EdgeInsets.all(16), children: [
                AppCard(
                    child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                            status == 'approved'
                                ? Icons.verified_rounded
                                : Icons.pending_actions_rounded,
                            color: status == 'approved'
                                ? Colors.green
                                : Colors.orange),
                        title: Text('Verification: ${status.toUpperCase()}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text(
                            'Upload clear JPG, PNG or PDF files. Admin approval controls your verification status.'))),
                const SizedBox(height: 12),
                ...fields.map((field) {
                  final value = docs[field.$1]?.toString() ?? '';
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                          child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(field.$3),
                              title: Text(field.$2,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  value.isEmpty ? 'Not uploaded' : 'Uploaded'),
                              trailing: OutlinedButton(
                                  onPressed:
                                      _busy ? null : () => _upload(field.$1),
                                  child: Text(
                                      value.isEmpty ? 'Upload' : 'Replace')))));
                }),
                if (_busy) const LinearProgressIndicator(),
              ]);
            }));
  }
}
