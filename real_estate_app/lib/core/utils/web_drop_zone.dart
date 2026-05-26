// lib/core/utils/web_drop_zone.dart
// Web-only implementation — imported conditionally (see web_drop_zone_stub.dart).
// Wraps a child widget with an OS-level file-drop overlay.
//
// History / why this is written with package:web instead of dart:html:
// the previous version read the dropped FileList via dynamic access
// (`(event as dynamic).dataTransfer`) inside a try/catch that swallowed errors.
// Under dart2js (release builds / installed PWA) that dynamic native-property
// read could fail and silently return null, so dropped images never reached the
// form. Typed access via DragEvent.dataTransfer.files removes that failure mode.

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

/// Wraps [child] with a drag-and-drop zone that accepts image files dropped
/// from the OS. Decoded [XFile]s (byte-backed) are passed to [onFilesDropped].
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

  // Keep the exact JSFunction references so removeEventListener can match them.
  late final JSFunction _enterJs;
  late final JSFunction _overJs;
  late final JSFunction _leaveJs;
  late final JSFunction _dropJs;

  // useCapture = true: receive events BEFORE Flutter's canvas can stopPropagation.
  static final JSAny _capture = true.toJS;

  void _setDragging(bool value) {
    if (_isDragging != value && mounted) setState(() => _isDragging = value);
  }

  @override
  void initState() {
    super.initState();
    _enterJs = _onDragEnter.toJS;
    _overJs = _onDragOver.toJS;
    _leaveJs = _onDragLeave.toJS;
    _dropJs = _onDrop.toJS;

    web.window.addEventListener('dragenter', _enterJs, _capture);
    web.window.addEventListener('dragover', _overJs, _capture);
    web.window.addEventListener('dragleave', _leaveJs, _capture);
    web.window.addEventListener('drop', _dropJs, _capture);
  }

  @override
  void dispose() {
    web.window.removeEventListener('dragenter', _enterJs, _capture);
    web.window.removeEventListener('dragover', _overJs, _capture);
    web.window.removeEventListener('dragleave', _leaveJs, _capture);
    web.window.removeEventListener('drop', _dropJs, _capture);
    super.dispose();
  }

  // dragenter/dragover MUST call preventDefault or the browser never fires `drop`.
  void _onDragEnter(web.Event e) {
    e.preventDefault();
    _dragDepth++;
    _setDragging(true);
  }

  void _onDragOver(web.Event e) {
    e.preventDefault();
    _setDragging(true);
  }

  void _onDragLeave(web.Event e) {
    e.preventDefault();
    if (--_dragDepth <= 0) {
      _dragDepth = 0;
      _setDragging(false);
    }
  }

  void _onDrop(web.Event e) {
    e.preventDefault();
    e.stopPropagation();
    _dragDepth = 0;
    _setDragging(false);

    final dataTransfer = (e as web.DragEvent).dataTransfer;
    if (dataTransfer == null) {
      debugPrint('[WebDropZone] drop event had no dataTransfer');
      return;
    }
    final files = dataTransfer.files;
    debugPrint('[WebDropZone] drop: ${files.length} file(s)');
    if (files.length > 0) {
      unawaited(_processFiles(files));
    }
  }

  Future<void> _processFiles(web.FileList files) async {
    const imageTypes = <String>{
      'image/jpeg', 'image/jpg', 'image/png',
      'image/webp', 'image/gif', 'image/heic', 'image/heif',
    };
    const extToMime = <String, String>{
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
      'png': 'image/png', 'webp': 'image/webp',
      'heic': 'image/heic', 'heif': 'image/heif', 'gif': 'image/gif',
    };

    final validImages = <XFile>[];

    for (var i = 0; i < files.length; i++) {
      if (validImages.length >= widget.maxFiles) break;
      final file = files.item(i);
      if (file == null) continue;

      // Some OS/browser combos report an empty MIME type for dragged files —
      // fall back to the file extension so a valid image isn't skipped.
      var fileType = file.type;
      if (fileType.isEmpty) {
        final parts = file.name.split('.');
        final ext = parts.length > 1 ? parts.last.toLowerCase() : '';
        fileType = extToMime[ext] ?? '';
      }
      if (!imageTypes.contains(fileType)) {
        debugPrint('[WebDropZone] skipped "${file.name}" (type "$fileType")');
        continue;
      }

      try {
        // Read bytes straight from the dropped File and keep them in memory via
        // XFile.fromData. We deliberately rely on the in-memory bytes (never a
        // re-fetch of a blob: URL): in an installed PWA the service worker can
        // answer a blob: fetch with its offline HTML page and corrupt the image.
        final buffer = await file.arrayBuffer().toDart;
        final bytes = buffer.toDart.asUint8List();
        if (bytes.isEmpty) continue;
        validImages.add(XFile.fromData(
          bytes,
          name: file.name,
          length: bytes.length,
          mimeType: fileType,
        ));
      } catch (err) {
        debugPrint('[WebDropZone] failed to read "${file.name}": $err');
      }
    }

    debugPrint('[WebDropZone] ${validImages.length} image(s) ready');
    if (validImages.isNotEmpty && mounted) widget.onFilesDropped(validImages);
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
