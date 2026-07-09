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
              .where((b) => ['pending', 'confirmed'].contains(b['status']))
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
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(service['title']?.toString() ?? 'Service',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      StatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${_date(b['booking_date'])} - ${b['start_time'] ?? ''} to ${b['end_time'] ?? ''}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                  if (b['notes'] != null)
                    Text('Note: ${b['notes']}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: Text(
                              currency.format(
                                  b['total_amount'] ?? service['price'] ?? 0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      if (status == 'pending') ...[
                        FilledButton(
                            onPressed: () => _update(ref, b, 'confirmed'),
                            child: const Text('Accept')),
                        const SizedBox(width: 8),
                        OutlinedButton(
                            onPressed: () => _update(ref, b, 'cancelled'),
                            child: const Text('Reject')),
                      ],
                      if (status == 'confirmed')
                        FilledButton(
                            onPressed: () => _update(ref, b, 'in_progress'),
                            child: const Text('Start Service')),
                      if (status == 'in_progress')
                        FilledButton(
                            onPressed: () => _complete(context, ref, b),
                            child: const Text('Complete')),
                    ],
                  ),
                  if (b['completion_photo_url'] != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(b['completion_photo_url'],
                          height: 100, width: 140, fit: BoxFit.cover),
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
    ref.invalidate(vendorBookingsProvider);
  }

  String _date(Object? value) {
    final d = DateTime.tryParse(value?.toString() ?? '');
    return d == null ? '' : DateFormat('d MMM yyyy').format(d);
  }
}
