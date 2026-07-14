import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

/// API `type` filter: images | documents | all
final mediaTypeProvider = StateProvider<String>((_) => 'all');
final mediaSearchProvider = StateProvider<String>((_) => '');
final mediaUploadFolderIdProvider = StateProvider<String?>((_) => null);

final vendorMediaFoldersProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  return ref.watch(vendorRepositoryProvider).mediaFolders(vendorId);
});

final vendorMediaProvider = FutureProvider((ref) async {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return <Map<String, dynamic>>[];
  final type = ref.watch(mediaTypeProvider);
  final search = ref.watch(mediaSearchProvider);
  return ref
      .watch(vendorRepositoryProvider)
      .media(vendorId, type: type, search: search);
});

class MediaLibraryPage extends ConsumerWidget {
  const MediaLibraryPage({super.key});

  static const types = [
    ('all', 'All files'),
    ('images', 'Images'),
    ('documents', 'Documents'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(vendorMediaProvider);
    final type = ref.watch(mediaTypeProvider);
    final folders = ref.watch(vendorMediaFoldersProvider);
    return VendorScaffold(
      title: 'Media Library',
      actions: [
        IconButton(
            onPressed: () => _upload(context, ref),
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
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'File type'),
                  items: types
                      .map((t) =>
                          DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                      .toList(),
                  onChanged: (v) =>
                      ref.read(mediaTypeProvider.notifier).state = v ?? 'all',
                ),
                const SizedBox(height: 10),
                folders.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (items) {
                    if (items.isEmpty) {
                      return OutlinedButton.icon(
                        onPressed: () => _ensureUploadFolder(ref),
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('Create upload folder'),
                      );
                    }
                    final selected = ref.watch(mediaUploadFolderIdProvider) ??
                        items.first['id']?.toString();
                    return DropdownButtonFormField<String>(
                      initialValue: selected,
                      decoration:
                          const InputDecoration(labelText: 'Upload folder'),
                      items: items
                          .map((f) => DropdownMenuItem(
                                value: f['id']?.toString(),
                                child: Text(f['name']?.toString() ?? 'Folder'),
                              ))
                          .toList(),
                      onChanged: (v) => ref
                          .read(mediaUploadFolderIdProvider.notifier)
                          .state = v,
                    );
                  },
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
                                    child: item['file_type'] == 'video' ||
                                            item['file_type'] == 'document'
                                        ? Icon(
                                            item['file_type'] == 'video'
                                                ? Icons.videocam_rounded
                                                : Icons.description_rounded,
                                            size: 42,
                                            color: Colors.black38)
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

  Future<void> _ensureUploadFolder(WidgetRef ref) async {
    final vendorId = ref.read(vendorIdProvider);
    if (vendorId == null) return;
    final created = await ref
        .read(vendorRepositoryProvider)
        .createMediaFolder(vendorId, 'General');
    final id = (created['id'] ?? created['folderId'])?.toString();
    if (id != null) {
      ref.read(mediaUploadFolderIdProvider.notifier).state = id;
    }
    ref.invalidate(vendorMediaFoldersProvider);
  }

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final vendorId = ref.read(vendorIdProvider);
    if (vendorId == null) return;

    var folderId = ref.read(mediaUploadFolderIdProvider);
    final folders = await ref.read(vendorMediaFoldersProvider.future);
    if (folderId == null || folderId.isEmpty) {
      if (folders.isEmpty) {
        await _ensureUploadFolder(ref);
        folderId = ref.read(mediaUploadFolderIdProvider);
      } else {
        folderId = folders.first['id']?.toString();
        ref.read(mediaUploadFolderIdProvider.notifier).state = folderId;
      }
    }
    if (folderId == null || folderId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create a folder before uploading')),
        );
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null) return;
    for (final file in result.files) {
      if (file.path == null) continue;
      final ext = (file.extension ?? '').toLowerCase();
      final contentType = ext == 'pdf'
          ? 'application/pdf'
          : ext == 'png'
              ? 'image/png'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg';
      await ref.read(vendorRepositoryProvider).uploadMedia(
            vendorId,
            File(file.path!),
            file.name,
            folderId,
            contentType,
          );
    }
    ref.invalidate(vendorMediaProvider);
  }
}
