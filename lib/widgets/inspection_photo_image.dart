import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/inspection_record.dart';
import '../services/photo_service.dart';

class InspectionPhotoImage extends StatefulWidget {
  const InspectionPhotoImage({
    super.key,
    required this.photo,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.logContext = '[PHOTO][IMAGE]',
    this.debugTrace,
    this.placeholderText = 'Imagem indisponível',
    this.placeholderColor,
    this.placeholderIcon = Icons.broken_image_outlined,
    this.showLoadingIndicator = true,
  });

  final InspectionPhotoData photo;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final String logContext;
  final String? debugTrace;
  final String placeholderText;
  final Color? placeholderColor;
  final IconData placeholderIcon;
  final bool showLoadingIndicator;

  @override
  State<InspectionPhotoImage> createState() => _InspectionPhotoImageState();
}

class _InspectionPhotoImageState extends State<InspectionPhotoImage> {
  Widget _placeholder({String? message}) {
    final placeholderColor = widget.placeholderColor ?? Colors.grey.shade100;
    return Container(
      width: widget.width,
      height: widget.height,
      color: placeholderColor,
      padding: const EdgeInsets.all(10),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.placeholderIcon, color: Colors.black54),
          const SizedBox(height: 6),
          Text(
            message ?? widget.placeholderText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebImage() {
    return FutureBuilder<Uint8List?>(
      future: PhotoService.instance.resolveWebPhotoBytes(
        widget.photo,
        logContext: widget.logContext,
        debugTrace: widget.debugTrace,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.showLoadingIndicator
              ? SizedBox(
                  width: widget.width,
                  height: widget.height,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _placeholder(message: 'Carregando...');
        }

        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return _placeholder(message: 'Foto indisponível no navegador');
        }

        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          cacheWidth: widget.cacheWidth,
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              debugPrint('${widget.logContext} [ERROR][Image.memory] $error');
            }
            return _placeholder();
          },
        );
      },
    );
  }

  Widget _buildMobileImage() {
    final source = PhotoService.instance.resolveBestPhotoSource(widget.photo);

    if (source == null) {
      if (kDebugMode) {
        debugPrint('${widget.logContext} fallback=mobile-source-null');
      }
      return _placeholder();
    }

    if (source == widget.photo.localPath &&
        widget.photo.localPath.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint('${widget.logContext} render=Image.file');
      }
      return Image.file(
        File(widget.photo.localPath),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            debugPrint('${widget.logContext} [ERROR][Image.file] $error');
          }
          return _placeholder();
        },
      );
    }

    if (kDebugMode) {
      debugPrint('${widget.logContext} render=Image.network(mobile-only)');
    }
    return Image.network(
      source,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        if (!widget.showLoadingIndicator) return child;
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          debugPrint('${widget.logContext} [ERROR][Image.network] $error');
        }
        return _placeholder();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'WEBPHOTO123[BUILD] widget=${widget.runtimeType} trace="${widget.debugTrace ?? ''}" '
      'kIsWeb=$kIsWeb photoUrl="${widget.photo.photoUrl}" storagePath="${widget.photo.storagePath}" '
      'localPath="${widget.photo.localPath}"',
    );

    if (kDebugMode) {
      debugPrint(
        '${widget.logContext} platform=${kIsWeb ? 'web' : 'mobile'} '
        'photoUrl="${widget.photo.photoUrl}" '
        'storagePath="${widget.photo.storagePath}" '
        'localPath="${widget.photo.localPath}"',
      );
    }

    return kIsWeb ? _buildWebImage() : _buildMobileImage();
  }
}
