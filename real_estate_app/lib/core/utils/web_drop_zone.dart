// lib/core/utils/web_drop_zone.dart
// Web-only implementation — imported conditionally.
// Wraps a child widget with an OS-level file-drop overlay using dart:html.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Wraps [child] with a drag-and-drop zone that accepts files dropped from
/// the OS.  Images are passed to [onFilesDropped]; video files are passed to
/// [onVideoDropped] if provided, otherwise silently ignored.
class WebDropZone extends StatefulWidget {
  final Widget child;
  final int maxFiles;
  final int maxBytesPerFile;
  final void Function(List<XFile> files) onFilesDropped;
  final void Function(List<XFile> videos)? onVideoDropped;
  final void Function(int skipped, double maxMB)? onOversized;

  const WebDropZone({
    super.key,
    required this.child,
    required this.onFilesDropped,
    this.onVideoDropped,
    this.maxFiles = 10,
    this.maxBytesPerFile = 15 * 1024 * 1024,
    this.onOversized,
  });

  @override
  State<WebDropZone> createState() => _WebDropZoneState();
}

class _WebDropZoneState extends State<WebDropZone> {
  bool _isDragging = false;

  // Use html.EventListener type alias (Function(Event)) — avoids DragEvent
  // which is not exported in all dart:html versions.
  late final html.EventListener _overListener;
  late final html.EventListener _leaveListener;
  late final html.EventListener _dropListener;

  @override
  void initState() {
    super.initState();

    _overListener = (html.Event e) {
      e.preventDefault();
      e.stopPropagation();
      if (!_isDragging && mounted) setState(() => _isDragging = true);
    };

    _leaveListener = (html.Event e) {
      e.preventDefault();
      if (_isDragging && mounted) setState(() => _isDragging = false);
    };

    _dropListener = (html.Event e) {
      e.preventDefault();
      e.stopPropagation();
      if (mounted) setState(() => _isDragging = false);

      // Access dataTransfer dynamically — DragEvent may not be exported.
      // ignore: avoid_dynamic_calls
      final dynamic dt = (e as dynamic).dataTransfer;
      if (dt == null) return;

      // ignore: avoid_dynamic_calls
      final html.FileList? files = dt.files as html.FileList?;
      if (files == null || files.isEmpty) return;

      _processFiles(files);
    };

    // Use window + capture=true so our listeners fire BEFORE Flutter's
    // CanvasKit canvas can call stopPropagation() on drag events.
    // Without capture mode, body listeners never receive the events and
    // the drop is silently ignored by the browser.
    html.window.addEventListener('dragover',  _overListener,  true);
    html.window.addEventListener('dragleave', _leaveListener, true);
    html.window.addEventListener('drop',      _dropListener,  true);
  }

  @override
  void dispose() {
    html.window.removeEventListener('dragover',  _overListener,  true);
    html.window.removeEventListener('dragleave', _leaveListener, true);
    html.window.removeEventListener('drop',      _dropListener,  true);
    super.dispose();
  }

  Future<void> _processFiles(html.FileList files) async {
    final validImages = <XFile>[];
    final validVideos = <XFile>[];
    int skipped = 0;

    const imageTypes = <String>[
      'image/jpeg', 'image/jpg', 'image/png',
      'image/webp', 'image/heic', 'image/heif',
    ];
    const videoTypes = <String>[
      'video/mp4', 'video/quicktime', 'video/webm',
      'video/x-m4v', 'video/avi', 'video/3gpp',
    ];
    // 50 MB limit for web video
    const int maxVideoBytes = 50 * 1024 * 1024;

    for (int i = 0; i < files.length; i++) {
      final file = files.item(i);
      if (file == null) continue;

      // Some OS / browser combinations report an empty MIME type for
      // drag-dropped files.  Fall back to the file extension so those
      // files are not silently skipped.
      String fileType = file.type;
      if (fileType.isEmpty) {
        final ext = file.name.split('.').last.toLowerCase();
        const extToMime = <String, String>{
          'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
          'png': 'image/png',  'webp': 'image/webp',
          'heic': 'image/heic', 'heif': 'image/heif',
          'gif': 'image/gif',
          'mp4': 'video/mp4',  'mov': 'video/quicktime',
          'webm': 'video/webm', 'm4v': 'video/x-m4v',
          'avi': 'video/avi',  '3gp': 'video/3gpp',
        };
        fileType = extToMime[ext] ?? '';
      }

      final isImage = imageTypes.contains(fileType);
      final isVideo = videoTypes.contains(fileType);
      if (!isImage && !isVideo) continue;

      if (isImage) {
        if (validImages.length >= widget.maxFiles) continue;
        if (file.size > widget.maxBytesPerFile) { skipped++; continue; }
      } else {
        // video — one at a time, 50 MB cap
        if (file.size > maxVideoBytes) { skipped++; continue; }
      }

      // Read file as bytes and expose as XFile via blob URL.
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final bytes = (reader.result as ByteBuffer).asUint8List();
      // Use resolved fileType (never empty) so the blob has a valid MIME type
      // and XFile.readAsBytes() works correctly across all renderers.
      final blob  = html.Blob([bytes], fileType);
      final url   = html.Url.createObjectUrl(blob);
      // Store bytes in the blob so we can read them back with readAsBytes().
      final xfile = XFile(url, name: file.name, length: file.size, mimeType: fileType);

      if (isImage) {
        validImages.add(xfile);
      } else {
        validVideos.add(xfile);
      }
    }

    if (skipped > 0) {
      widget.onOversized?.call(skipped, widget.maxBytesPerFile / (1024 * 1024));
    }
    if (validImages.isNotEmpty) widget.onFilesDropped(validImages);
    if (validVideos.isNotEmpty) widget.onVideoDropped?.call(validVideos);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: _isDragging
          ? BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            )
          : null,
      child: widget.child,
    );
  }
}
