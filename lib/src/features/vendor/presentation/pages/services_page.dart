import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';
import 'products_page.dart' show pickVendorImage;

/// Price-type options — must mirror the vendor web (fixed / starting_from / hourly).
const _priceTypes = <String, String>{
  'fixed': 'Fixed',
  'starting_from': 'Starting from',
  'hourly': 'Hourly',
};

class ServicesPage extends ConsumerStatefulWidget {
  const ServicesPage({super.key});

  @override
  ConsumerState<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends ConsumerState<ServicesPage> {
  String search = '';
  String status = 'all';

  bool _matchesStatus(Map<String, dynamic> s) {
    final mod = (s['moderationStatus'] ?? 'approved').toString().toLowerCase();
    final active = s['is_active'] == true;
    switch (status) {
      case 'pending':
        return mod == 'pending';
      case 'active':
        return mod != 'pending' && active;
      case 'inactive':
        return mod != 'pending' && !active;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(vendorServicesProvider);
    return VendorScaffold(
      title: 'My Services',
      actions: [
        IconButton(
          tooltip: 'Add Service',
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add_rounded),
        )
      ],
      child: services.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          final filtered = items.where((s) {
            final matchesSearch = search.isEmpty ||
                (s['title'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(search.toLowerCase());
            return matchesSearch && _matchesStatus(s);
          }).toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(vendorServicesProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Search services...'),
                        onChanged: (v) => setState(() => search = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: status,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: (v) => setState(() => status = v ?? 'all'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  EmptyState(
                    icon: Icons.handyman_outlined,
                    title: items.isEmpty
                        ? 'No linked services yet'
                        : 'No services match',
                    subtitle: items.isEmpty
                        ? 'Tap + to add a catalog service, set your price and submit for review.'
                        : 'Try a different search or status filter.',
                  )
                else
                  ...filtered.map((s) => _ServiceTile(
                        item: s,
                        onEdit: () => _openForm(context, item: s),
                        onToggle: () => _toggle(s),
                        onDelete: () => _delete(context, s),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {Map<String, dynamic>? item}) {
    final vendorId = ref.read(vendorIdProvider);
    if (vendorId == null) return Future.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ServiceFormSheet(vendorId: vendorId, item: item),
    );
  }

  Future<void> _toggle(Map<String, dynamic> s) async {
    final pending =
        (s['moderationStatus'] ?? '').toString().toLowerCase() == 'pending';
    if (pending) {
      _snack('This listing is pending admin approval and cannot be activated yet.');
      return;
    }
    try {
      await ref
          .read(vendorRepositoryProvider)
          .setServiceActive(s['id'].toString(), s['is_active'] != true);
      ref.invalidate(vendorServicesProvider);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove service?'),
        content: const Text('This removes the service from your listings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(vendorRepositoryProvider)
          .deleteService(s['id'].toString());
      ref.invalidate(vendorServicesProvider);
    } catch (e) {
      _snack('$e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.item,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.', decimalDigits: 0);
    final image = item['image']?.toString();
    final pending =
        (item['moderationStatus'] ?? '').toString().toLowerCase() == 'pending';
    final active = item['is_active'] == true;
    final duration = item['duration']?.toString() ?? '';
    final city = item['city']?.toString() ?? '';
    final meta = [duration, city].where((v) => v.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 58,
                height: 58,
                color: Colors.black.withValues(alpha: .04),
                child: image != null && image.isNotEmpty
                    ? Image.network(image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.handyman_rounded))
                    : const Icon(Icons.handyman_rounded),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(item['title']?.toString() ?? 'Service',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    StatusBadge(pending
                        ? 'pending_approval'
                        : (active ? 'active' : 'inactive')),
                  ]),
                  const SizedBox(height: 5),
                  Text(currency.format(item['price'] ?? 0),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'toggle':
                    onToggle();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'toggle',
                  enabled: !pending,
                  child: Text(active ? 'Deactivate' : 'Activate'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add / Edit service offering — mirrors the vendor web "My Services" form:
/// pick a catalog template (category → subcategory), then set your price,
/// price type, duration, flags, description and image.
class _ServiceFormSheet extends ConsumerStatefulWidget {
  const _ServiceFormSheet({required this.vendorId, this.item});

  final String vendorId;
  final Map<String, dynamic>? item;

  @override
  ConsumerState<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends ConsumerState<_ServiceFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _basePrice;
  late final TextEditingController _duration;

  String _categoryId = '';
  String _serviceId = '';
  String _priceType = 'fixed';
  String _iconUrl = '';
  String _city = '';
  bool _availability = true;
  bool _trending = false;
  bool _emergency = false;
  bool _isActive = true;

  bool _saving = false;
  bool _uploading = false;
  String? _error;

  bool get _isEdit => widget.item != null;
  bool get _pending =>
      (widget.item?['moderationStatus'] ?? '').toString().toLowerCase() ==
      'pending';

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?['title']?.toString() ?? '');
    _description =
        TextEditingController(text: item?['description']?.toString() ?? '');
    _basePrice = TextEditingController(
        text: item?['base_price']?.toString() ??
            item?['price']?.toString() ??
            '');
    _duration =
        TextEditingController(text: item?['duration']?.toString() ?? '');
    _categoryId = item?['category_id']?.toString() ?? '';
    _serviceId = item?['service_id']?.toString() ?? '';
    final pt = item?['price_type']?.toString() ?? 'fixed';
    _priceType = _priceTypes.containsKey(pt) ? pt : 'fixed';
    _iconUrl = item?['image']?.toString() ?? '';
    _city = item?['city']?.toString() ?? '';
    _availability = item?['availability'] != false;
    _trending = item?['trending'] == true;
    _emergency = item?['emergency'] == true;
    _isActive = item?['is_active'] != false;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _basePrice.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _onSelectSubcategory(String serviceId, List<Map<String, dynamic>> catalog) {
    final match =
        catalog.where((c) => c['id']?.toString() == serviceId).toList();
    final item = match.isEmpty ? null : match.first;
    final meta = (item?['metadata'] as Map?)?.cast<String, dynamic>() ?? {};
    setState(() {
      _serviceId = serviceId;
      if (item != null) {
        final name = item['name']?.toString() ?? '';
        if (name.isNotEmpty) _title.text = name;
        final desc = item['description']?.toString() ?? '';
        if (desc.isNotEmpty) _description.text = desc;
        final icon = item['icon_url']?.toString() ?? '';
        if (icon.isNotEmpty) _iconUrl = icon;
        final base = item['base_price']?.toString() ?? '';
        if (base.isNotEmpty && base != 'null') _basePrice.text = base;
        if (item['availability'] == true) _availability = true;
        if (item['trending'] == true) _trending = true;
        if (meta['emergency'] == true) _emergency = true;
        final mpt = meta['priceType']?.toString() ?? '';
        if (_priceTypes.containsKey(mpt)) _priceType = mpt;
        final md = meta['duration'];
        if (md is String && md.isNotEmpty) _duration.text = md;
      }
    });
  }

  Future<void> _pickImage() async {
    setState(() => _uploading = true);
    try {
      final url =
          await pickVendorImage(ref, widget.vendorId, 'services');
      if (url != null) setState(() => _iconUrl = url);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_isEdit && _categoryId.trim().isEmpty) {
      setState(() => _error = 'Select a service category.');
      return;
    }
    if (!_isEdit && _serviceId.trim().isEmpty) {
      setState(() => _error = 'Select a subcategory.');
      return;
    }
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a service title.');
      return;
    }
    if (_basePrice.text.trim().isEmpty) {
      setState(() => _error = 'Enter a base price.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(vendorRepositoryProvider).upsertService(
            widget.vendorId,
            {
              'service_id': _serviceId,
              'title': _title.text.trim(),
              'description': _description.text.trim(),
              'image': _iconUrl.trim(),
              'base_price': _basePrice.text.trim(),
              'price': _basePrice.text.trim(),
              'price_type': _priceType,
              'duration': _duration.text.trim(),
              'city': _city,
              'availability': _availability,
              'trending': _trending,
              'emergency': _emergency,
              'is_active': _isActive,
            },
            id: _isEdit ? widget.item!['id']?.toString() : null,
          );
      ref.invalidate(vendorServicesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(serviceCategoriesProvider);
    final catalog = ref.watch(catalogServiceItemsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEdit ? 'Edit Service' : 'New Service',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (_pending)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'This listing is pending admin approval. It will reflect on the user service flow after approval.',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            if (_error != null) ...[
              Text(_error!,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
            ],

            // ── Service image ──
            _ImagePreview(url: _iconUrl),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickImage,
                  icon: const Icon(Icons.image_rounded),
                  label:
                      Text(_uploading ? 'Uploading...' : 'Upload Service Image'),
                ),
              ),
              if (_iconUrl.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove image',
                  onPressed: () => setState(() => _iconUrl = ''),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ]),
            const SizedBox(height: 12),

            // ── Title ──
            TextField(
              controller: _title,
              maxLength: 255,
              decoration: const InputDecoration(
                  labelText: 'Title *', counterText: ''),
            ),
            const SizedBox(height: 10),

            // ── Category / Subcategory ──
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load categories: $e',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
              data: (cats) => DropdownButtonFormField<String>(
                initialValue: _categoryId.isEmpty ? null : _categoryId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Service category *'),
                items: cats
                    .map((c) => DropdownMenuItem(
                          value: c['id']?.toString(),
                          child: Text(c['name']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _isEdit
                    ? null
                    : (v) => setState(() {
                          _categoryId = v ?? '';
                          _serviceId = '';
                        }),
              ),
            ),
            const SizedBox(height: 10),
            catalog.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load services: $e',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
              data: (items) {
                final options = items
                    .where((c) =>
                        c['service_category_id']?.toString() == _categoryId)
                    .toList();
                final valid = options
                    .any((c) => c['id']?.toString() == _serviceId);
                return DropdownButtonFormField<String>(
                  initialValue: valid ? _serviceId : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Subcategory *',
                    hintText: _categoryId.isEmpty
                        ? 'Select category first'
                        : 'Select subcategory',
                  ),
                  items: options
                      .map((c) => DropdownMenuItem(
                            value: c['id']?.toString(),
                            child: Text(c['name']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (_isEdit || _categoryId.isEmpty)
                      ? null
                      : (v) {
                          if (v != null) _onSelectSubcategory(v, items);
                        },
                );
              },
            ),
            const SizedBox(height: 12),

            // ── Flags ──
            _YesNoField(
              label: 'Availability',
              value: _availability,
              onChanged: _pending
                  ? null
                  : (v) => setState(() => _availability = v),
            ),
            _YesNoField(
              label: 'Trending',
              value: _trending,
              onChanged: (v) => setState(() => _trending = v),
            ),
            _YesNoField(
              label: 'Emergency service',
              value: _emergency,
              onChanged: (v) => setState(() => _emergency = v),
            ),
            const SizedBox(height: 6),

            // ── Pricing ──
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _basePrice,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  maxLength: 32,
                  decoration: const InputDecoration(
                      labelText: 'Base Price (Rs.) *', counterText: ''),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _priceType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Price type'),
                  items: _priceTypes.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _priceType = v ?? 'fixed'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _duration,
              maxLength: 64,
              decoration: const InputDecoration(
                  labelText: 'Duration', hintText: 'e.g. 1-2 hours', counterText: ''),
            ),
            const SizedBox(height: 10),

            // ── Description ──
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving
                  ? 'Saving...'
                  : _isEdit
                      ? 'Save'
                      : 'Create Service'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: .08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined, color: Colors.black38),
                  SizedBox(height: 6),
                  Text('No image', style: TextStyle(color: Colors.black45)),
                ],
              ),
            )
          : Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image_outlined))),
    );
  }
}

class _YesNoField extends StatelessWidget {
  const _YesNoField(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
