import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

final mediaFolderProvider = StateProvider<String>((_) => 'all');
final mediaSearchProvider = StateProvider<String>((_) => '');

final vendorMediaProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  final folder = ref.watch(mediaFolderProvider);
  final search = ref.watch(mediaSearchProvider);
  return ref
      .watch(vendorRepositoryProvider)
      .media(vendorId, folder: folder, search: search);
});

class MediaLibraryPage extends ConsumerWidget {
  const MediaLibraryPage({super.key});

  static const folders = [
    'all',
    'products',
    'logos',
    'backgrounds',
    'icons',
    'general'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(vendorMediaProvider);
    final folder = ref.watch(mediaFolderProvider);
    return VendorScaffold(
      title: 'Media Library',
      actions: [
        IconButton(
            onPressed: () => _upload(ref),
            icon: const Icon(Icons.upload_rounded)),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search files...'),
                  onChanged: (v) =>
                      ref.read(mediaSearchProvider.notifier).state = v,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: folder,
                  items: folders
                      .map((f) => DropdownMenuItem(
                          value: f, child: Text(f == 'all' ? 'All Files' : f)))
                      .toList(),
                  onChanged: (v) =>
                      ref.read(mediaFolderProvider.notifier).state = v ?? 'all',
                ),
              ],
            ),
          ),
          Expanded(
            child: media.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyState(
                          icon: Icons.perm_media_outlined,
                          title: 'No files yet'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(vendorMediaProvider.future),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: item['file_type'] == 'video'
                                        ? const Icon(Icons.videocam_rounded,
                                            size: 42, color: Colors.black38)
                                        : Image.network(
                                            item['file_url']?.toString() ?? '',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                    Icons.image_rounded)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item['file_name']?.toString() ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12)),
                                      Text(
                                          (item['folder'] ?? '')
                                              .toString()
                                              .split('/')
                                              .last,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton.filled(
                                style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.red.withValues(alpha: .84)),
                                onPressed: () async {
                                  await ref
                                      .read(vendorRepositoryProvider)
                                      .deleteMedia(item);
                                  ref.invalidate(vendorMediaProvider);
                                },
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _upload(WidgetRef ref) async {
    final vendorId = ref.read(vendorIdProvider);
    if (vendorId == null) return;
    final result = await FilePicker.platform
        .pickFiles(allowMultiple: true, type: FileType.media);
    if (result == null) return;
    final folder = ref.read(mediaFolderProvider) == 'all'
        ? 'general'
        : ref.read(mediaFolderProvider);
    for (final file in result.files) {
      if (file.path == null) continue;
      final type = (file.extension ?? '').toLowerCase().contains('mp4')
          ? 'video'
          : 'image';
      await ref
          .read(vendorRepositoryProvider)
          .uploadMedia(vendorId, File(file.path!), file.name, folder, type);
    }
    ref.invalidate(vendorMediaProvider);
  }
}
