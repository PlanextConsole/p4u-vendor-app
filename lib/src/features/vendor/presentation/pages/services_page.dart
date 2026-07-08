import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';
import 'products_page.dart';

class ServicesPage extends ConsumerStatefulWidget {
  const ServicesPage({super.key});

  @override
  ConsumerState<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends ConsumerState<ServicesPage> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(vendorServicesProvider);
    return VendorScaffold(
      title: 'My Services',
      actions: [IconButton(onPressed: () => _showServiceForm(context, ref), icon: const Icon(Icons.add_rounded))],
      child: services.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          final filtered = items.where((s) => search.isEmpty || (s['title'] ?? '').toString().toLowerCase().contains(search.toLowerCase())).toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(vendorServicesProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search services...'),
                  onChanged: (v) => setState(() => search = v),
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  const EmptyState(icon: Icons.handyman_outlined, title: 'No services yet', subtitle: 'Add your first service.')
                else
                  ...filtered.map((s) => CatalogTile(
                        item: s,
                        fallbackIcon: Icons.handyman_rounded,
                        onEdit: () => _showServiceForm(context, ref, item: s),
                        onDelete: () async {
                          await ref.read(vendorRepositoryProvider).deleteService(s['id'].toString());
                          ref.invalidate(vendorServicesProvider);
                        },
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<void> _showServiceForm(BuildContext context, WidgetRef ref, {Map<String, dynamic>? item}) async {
  final vendorId = ref.read(vendorIdProvider);
  if (vendorId == null) return;
  final title = TextEditingController(text: item?['title']?.toString() ?? '');
  final description = TextEditingController(text: item?['description']?.toString() ?? '');
  final price = TextEditingController(text: item?['price']?.toString() ?? '');
  final tax = TextEditingController(text: item?['tax']?.toString() ?? '0');
  final discount = TextEditingController(text: item?['discount']?.toString() ?? '0');
  final duration = TextEditingController(text: item?['duration']?.toString() ?? '');
  final area = TextEditingController(text: item?['service_area']?.toString() ?? '');
  final image = TextEditingController(text: item?['image']?.toString() ?? '');
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.viewInsetsOf(sheetContext).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item == null ? 'Add Service' : 'Edit Service', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title *')),
            const SizedBox(height: 10),
            TextField(controller: description, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Description *')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price Rs. *'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: tax, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tax'))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: discount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: duration, decoration: const InputDecoration(labelText: 'Duration *'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: area, decoration: const InputDecoration(labelText: 'Service Area *'))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: image, decoration: const InputDecoration(labelText: 'Image URL *')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final url = await pickVendorImage(ref, vendorId, 'services');
                if (url != null) image.text = url;
              },
              icon: const Icon(Icons.image_rounded),
              label: const Text('Upload Service Image'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty || description.text.trim().isEmpty || price.text.trim().isEmpty) return;
                await ref.read(vendorRepositoryProvider).upsertService(
                  vendorId,
                  {
                    'title': title.text.trim(),
                    'description': description.text.trim(),
                    'price': price.text.trim(),
                    'tax': tax.text.trim(),
                    'discount': discount.text.trim(),
                    'duration': duration.text.trim(),
                    'service_area': area.text.trim(),
                    'image': image.text.trim(),
                    'status': item?['status'] ?? 'pending_approval',
                  },
                  id: item?['id']?.toString(),
                );
                ref.invalidate(vendorServicesProvider);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: Text(item == null ? 'Submit for Approval' : 'Update Service'),
            ),
          ],
        ),
      ),
    ),
  );
}
