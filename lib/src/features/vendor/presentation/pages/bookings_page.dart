import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

class BookingsPage extends ConsumerWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(vendorBookingsProvider);
    return VendorScaffold(
      title: 'Service Bookings',
      child: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          final pending = items
              .where((b) =>
                  ['pending', 'approved', 'confirmed'].contains(b['status']))
              .toList();
          final active =
              items.where((b) => b['status'] == 'in_progress').toList();
          final completed = items
              .where((b) => ['completed', 'cancelled'].contains(b['status']))
              .toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(vendorBookingsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.1,
                  children: [
                    MetricCard(
                        icon: Icons.schedule_rounded,
                        label: 'Pending',
                        value: '${pending.length}'),
                    MetricCard(
                        icon: Icons.calendar_month_rounded,
                        label: 'In Progress',
                        value: '${active.length}'),
                    MetricCard(
                        icon: Icons.check_circle_rounded,
                        label: 'Completed',
                        value: '${completed.length}'),
                  ],
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const EmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'No service bookings yet')
                else ...[
                  if (pending.isNotEmpty)
                    _Section('Pending / Confirmed', pending),
                  if (active.isNotEmpty) _Section('In Progress', active),
                  if (completed.isNotEmpty)
                    _Section('Completed / Cancelled', completed),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends ConsumerWidget {
  const _Section(this.title, this.items);
  final String title;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.', decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Text('$title (${items.length})',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        ...items.map((b) {
          final service = b['services'] is Map
              ? Map<String, dynamic>.from(b['services'])
              : <String, dynamic>{};
          final status = b['status']?.toString() ?? 'pending';
          final metadata = b['metadata'] is Map
              ? Map<String, dynamic>.from(b['metadata'] as Map)
              : <String, dynamic>{};
          final serviceImage = _serviceImage(b, metadata, service);
          final proofPhotos = _completionPhotoUrls(b, metadata);
          final canCancel = status == 'approved' || status == 'in_progress';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: serviceImage.isNotEmpty
                              ? Image.network(
                                  serviceImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.black12,
                                    child: const Icon(Icons.handyman, size: 20),
                                  ),
                                )
                              : Container(
                                  color: Colors.black12,
                                  child: const Icon(Icons.handyman, size: 20),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              service['title']?.toString() ??
                                  b['serviceName']?.toString() ??
                                  'Service',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      StatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${_date(b['booking_date'] ?? b['bookingDate'])} - ${_slot(b)}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                  if (b['notes'] != null)
                    Text('Note: ${b['notes']}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 10),
                  Text(
                      currency.format(
                          b['total_amount'] ?? service['price'] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (status == 'pending') ...[
                        FilledButton(
                            onPressed: () => _update(ref, b, 'approved'),
                            child: const Text('Accept')),
                        OutlinedButton(
                            onPressed: () => _update(ref, b, 'rejected'),
                            child: const Text('Reject')),
                      ],
                      if (status == 'approved' || status == 'confirmed')
                        FilledButton(
                            onPressed: () => _update(ref, b, 'in_progress'),
                            child: const Text('Start Service')),
                      if (status == 'in_progress')
                        FilledButton(
                            onPressed: () => _complete(context, ref, b),
                            child: const Text('Complete')),
                      if (canCancel)
                        OutlinedButton(
                            onPressed: () => _update(ref, b, 'cancelled'),
                            child: const Text('Cancel')),
                    ],
                  ),
                  if (proofPhotos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: proofPhotos
                          .take(3)
                          .map(
                            (url) => ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(url,
                                  height: 100,
                                  width: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                        height: 100,
                                        width: 140,
                                        color: Colors.black12,
                                        alignment: Alignment.center,
                                        child: const Text('Photo',
                                            style: TextStyle(fontSize: 12)),
                                      )),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _slot(Map<String, dynamic> booking) {
    final slot = booking['timeSlot']?.toString() ??
        booking['time_slot']?.toString() ??
        '';
    if (slot.isNotEmpty) return slot;
    final start = booking['start_time']?.toString() ??
        booking['startTime']?.toString() ??
        '';
    final end =
        booking['end_time']?.toString() ?? booking['endTime']?.toString() ?? '';
    if (start.isEmpty && end.isEmpty) return '';
    return '$start to $end';
  }

  Future<void> _update(
      WidgetRef ref, Map<String, dynamic> booking, String status) async {
    await ref
        .read(vendorRepositoryProvider)
        .updateBookingStatus(booking['id'].toString(), status);
    ref.invalidate(vendorBookingsProvider);
  }

  Future<void> _complete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> booking) async {
    final notes = TextEditingController();
    XFile? photo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: const Text('Complete Service'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await ImagePicker().pickImage(
                              source: ImageSource.camera, imageQuality: 80);
                          if (picked != null) {
                            setDialogState(() => photo = picked);
                          }
                        },
                        icon: Icon(photo == null
                            ? Icons.camera_alt_rounded
                            : Icons.check_circle_rounded),
                        label: Text(photo == null
                            ? 'Take completion photo'
                            : 'Photo selected'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                          controller: notes,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              labelText: 'Completion notes')),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Mark Completed')),
                ],
              )),
    );
    if (ok != true) return;
    if (photo == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Completion photo is required')));
      }
      return;
    }
    await ref.read(vendorRepositoryProvider).completeBooking(
        booking['id'].toString(), File(photo!.path), notes.text.trim());
    if (!context.mounted) return;
    final otpController = TextEditingController();
    final otp = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Customer completion OTP'),
              content: TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: '6-digit OTP')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, otpController.text.trim()),
                    child: const Text('Verify'))
              ],
            ));
    otpController.dispose();
    if (otp != null && RegExp(r'^\d{6}$').hasMatch(otp)) {
      await ref
          .read(vendorRepositoryProvider)
          .verifyBookingCompletionOtp(booking['id'].toString(), otp);
    }
    ref.invalidate(vendorBookingsProvider);
  }

  String _date(Object? value) {
    final d = DateTime.tryParse(value?.toString() ?? '');
    return d == null ? '' : DateFormat('d MMM yyyy').format(d);
  }
}

String _serviceImage(
  Map<String, dynamic> booking,
  Map<String, dynamic> metadata,
  Map<String, dynamic> service,
) {
  final candidates = [
    booking['serviceImage'],
    booking['service_image'],
    metadata['serviceImage'],
    metadata['service_image'],
    metadata['imageUrl'],
    service['image'],
    service['imageUrl'],
  ];
  for (final c in candidates) {
    final s = c?.toString().trim() ?? '';
    if (s.isNotEmpty) return s;
  }
  return '';
}

List<String> _completionPhotoUrls(
  Map<String, dynamic> booking,
  Map<String, dynamic> metadata,
) {
  final urls = <String>[];
  void add(Object? value) {
    final s = value?.toString().trim() ?? '';
    if (s.isNotEmpty && !urls.contains(s)) urls.add(s);
  }

  add(booking['completion_photo_url']);
  add(booking['completionPhotoUrl']);
  add(metadata['completion_photo_url']);
  add(metadata['completionPhotoUrl']);

  final proof = metadata['completionProof'] ??
      metadata['completion_proof'] ??
      booking['completionProof'] ??
      booking['completion_proof'];
  if (proof is Map) {
    final photoUrls = proof['photoUrls'] ??
        proof['photo_urls'] ??
        proof['photos'] ??
        proof['images'];
    if (photoUrls is List) {
      for (final u in photoUrls) {
        add(u);
      }
    } else {
      add(photoUrls);
    }
    add(proof['photoUrl']);
    add(proof['photo_url']);
  }
  return urls;
}
