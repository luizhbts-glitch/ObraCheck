import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/inspection_record.dart';
import '../services/photo_service.dart';
import 'inspection_photo_image.dart';

class PhotoViewer extends StatelessWidget {
  const PhotoViewer({
    super.key,
    required this.photo,
    required this.onDeleted,
    this.cacheWidth = 640,
  });

  final InspectionPhotoData photo;
  final Future<void> Function(InspectionPhotoData photo) onDeleted;
  final int cacheWidth;

  Future<void> _openExpandedViewer(BuildContext context) async {
    final canPreview = PhotoService.instance.canRenderPhotoOnCurrentPlatform(photo);
    if (!canPreview) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagem indisponível para visualização ampliada')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: InspectionPhotoImage(
                      photo: photo,
                      fit: BoxFit.contain,
                      logContext: '[PHOTO][VIEWER][EXPANDED]',
                      placeholderColor: Colors.black,
                      placeholderText: 'Imagem indisponível para visualização ampliada',
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasOnlineUrl = PhotoService.instance.hasOnlineUrl(photo);

    if (kDebugMode) {
      debugPrint(
        '[PHOTO][VIEWER] platform=${kIsWeb ? 'web' : 'mobile'} '
        'photoUrl="${photo.photoUrl}"(${PhotoService.instance.classifyPhotoValue(photo.photoUrl)}) '
        'localPath="${photo.localPath}"(${PhotoService.instance.classifyPhotoValue(photo.localPath)}) '
        'storagePath="${photo.storagePath}" '
        'hasOnlineUrl=$hasOnlineUrl pendingSync=${photo.pendingSync}',
      );
    }

    final imageWidget = InspectionPhotoImage(
      photo: photo,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      logContext: '[PHOTO][VIEWER][WIDGET]',
      placeholderText: 'Imagem indisponível no navegador',
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openExpandedViewer(context),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageWidget,
              ),
            ),
            if (photo.pendingSync)
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Pendente sync',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  if (hasOnlineUrl) ...[
                    _RoundButton(
                      icon: Icons.download_outlined,
                      onPressed: () async {
                        try {
                          await PhotoService.instance.downloadPhoto(photo.photoUrl);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Falha ao baixar foto: $e')),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                  _RoundButton(
                    icon: Icons.delete_outline,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Excluir foto'),
                          content: const Text('Deseja realmente excluir esta foto?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      await onDeleted(photo);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoViewerGrid extends StatelessWidget {
  const PhotoViewerGrid({
    super.key,
    required this.photos,
    required this.onDeleted,
    this.crossAxisCount = 3,
    this.cacheWidth = 640,
  });

  final List<InspectionPhotoData> photos;
  final Future<void> Function(InspectionPhotoData photo) onDeleted;
  final int crossAxisCount;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final photo = photos[index];
        return PhotoViewer(
          photo: photo,
          cacheWidth: cacheWidth,
          onDeleted: onDeleted,
        );
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onPressed});

  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async => await onPressed(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
