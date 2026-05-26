// lib/core/utils/web_drop_zone.dart
// Web-only implementation — imported conditionally.
// Wraps a child widget with an OS-level file-drop overlay using dart:html.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Wraps [child] with a drag-and-drop zone that accepts image files dropped
/// from the OS.  Images are passed to [onFilesDropped].
class WebDropZone extends StatefulWidget {
  final Widget child;
  final int maxFiles;
  final void Function(List<XFile> files) onFilesDropped;

  const WebDropZone({
    super.key,
    required this.child,
    required this.onFilesDropped,
    this.maxFiles = 10,
  });

  @override
  State<WebDropZone> createState() => _WebDropZoneState();
}

class _WebDropZoneState extends State<WebDropZone> {
  bool _isDragging = false;
  // Tracks dragenter/dragleave nesting so the highlight doesn't flicker as the
  // cursor crosses between child elements during a drag.
  int _dragDepth = 0;

  // Use html.EventListener type alias (Function(Event)) — avoids DragEvent
  // which is not exported in all dart:html versions.
  late final html.EventListener _enterListener;
  late final html.EventListener _overListener;
  late final html.EventListener _leaveListener;
  late final html.EventListener _dropListener;

  void _setDragging(bool value) {
    if (_isDragging != value && mounted) setState(() => _isDragging = value);
  }

  @override
  void initState() {
    super.initState();

    // dragenter: some browsers require preventDefault here (in addition to
    // dragover) before they will deliver a `drop` event at all.
    _enterListener = (html.Event e) {
      e.preventDefault();
      _dragDepth++;
      _setDragging(true);
    };

    // dragover MUST preventDefault on EVERY event or the browser silently
    // refuses to fire `drop`. We do not stopPropagation so Flutter's own
    // handling is left intact.
    _overListener = (html.Event e) {
      e.preventDefault();
      _setDragging(true);
    };

    _leaveListener = (html.Event e) {
      e.preventDefault();
      if (--_dragDepth <= 0) {
        _dragDepth = 0;
        _setDragging(false);
      }
    };

    _dropListener = (html.Event e) {
      e.preventDefault();
      e.stopPropagation();
      _dragDepth = 0;
      _setDragging(false);

      final files = _extractFiles(e);
      if (files != null && files.isNotEmpty) _processFiles(files);
    };

    // Use window + capture=true so our listeners fire BEFORE Flutter's
    // CanvasKit canvas can call stopPropagation() on drag events.
    // Without capture mode, body listeners never receive the events and
    // the drop is silently ignored by the browser.
    html.window.addEventListener('dragenter', _enterListener, true);
    html.window.addEventListener('dragover',  _overListener,  true);
    html.window.addEventListener('dragleave', _leaveListener, true);
    html.window.addEventListener('drop',      _dropListener,  true);
  }

  // Pull the dropped FileList off the event's dataTransfer. DragEvent is not
  // reliably exported by dart:html, so we read it dynamically and guard it.
  html.FileList? _extractFiles(html.Event e) {
    try {
      // ignore: avoid_dynamic_calls
      final dynamic dt = (e as dynamic).dataTransfer;
      if (dt == null) return null;
      // ignore: avoid_dynamic_calls
      return dt.files as html.FileList?;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    html.window.removeEventListener('dragenter', _enterListener, true);
    html.window.removeEventListener('dragover',  _overListener,  true);
    html.window.removeEventListener('dragleave', _leaveListener, true);
    html.window.removeEventListener('drop',      _dropListener,  true);
    super.dispose();
  }

  Future<void> _processFiles(html.FileList files) async {
    final validImages = <XFile>[];

    const imageTypes = <String>[
      'image/jpeg', 'image/jpg', 'image/png',
      'image/webp', 'image/gif', 'image/heic', 'image/heif',
    ];

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
        };
        fileType = extToMime[ext] ?? '';
      }

      if (!imageTypes.contains(fileType)) continue;
      if (validImages.length >= widget.maxFiles) continue;
      // Any size is accepted — the upload pipeline downscales before storing.

      // Read the dropped File directly into bytes and keep them in memory via
      // XFile.fromData. We deliberately do NOT wrap them in a blob: URL: the
      // upload would then have to re-fetch that URL, and in an installed PWA the
      // service worker can answer that fetch with its offline HTML page,
      // corrupting the image. Holding the bytes means there is no re-fetch.
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final bytes = (reader.result as ByteBuffer).asUint8List();
      validImages.add(XFile.fromData(
        bytes,
        name: file.name,
        length: bytes.length,
        mimeType: fileType,
      ));
    }

    if (validImages.isNotEmpty) widget.onFilesDropped(validImages);
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
