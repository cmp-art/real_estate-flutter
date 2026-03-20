// lib/core/utils/web_drop_zone.dart
// Web-only implementation — imported conditionally.
// Wraps a child widget with an OS-level file-drop overlay using dart:html.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Wraps [child] with a drag-and-drop zone that accepts image files dropped
/// from the operating system.  [onFilesDropped] is called with the list of
/// [XFile] images after they pass the size/type filter.
class WebDropZone extends StatefulWidget {
  final Widget child;
  final int maxFiles;
  final int maxBytesPerFile;
  final void Function(List<XFile> files) onFilesDropped;
  final void Function(int skipped, double maxMB)? onOversized;

  const WebDropZone({
    super.key,
    required this.child,
    required this.onFilesDropped,
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

    final body = html.document.body;
    if (body != null) {
      body.addEventListener('dragover',  _overListener);
      body.addEventListener('dragleave', _leaveListener);
      body.addEventListener('drop',      _dropListener);
    }
  }

  @override
  void dispose() {
    final body = html.document.body;
    if (body != null) {
      body.removeEventListener('dragover',  _overListener);
      body.removeEventListener('dragleave', _leaveListener);
      body.removeEventListener('drop',      _dropListener);
    }
    super.dispose();
  }

  Future<void> _processFiles(html.FileList files) async {
    final validXFiles = <XFile>[];
    int skipped = 0;

    const allowed = <String>[
      'image/jpeg', 'image/jpg', 'image/png',
      'image/webp', 'image/heic', 'image/heif',
    ];

    for (int i = 0; i < files.length && validXFiles.length < widget.maxFiles; i++) {
      final file = files.item(i);
      if (file == null) continue;
      if (!allowed.contains(file.type)) continue;
      if (file.size > widget.maxBytesPerFile) {
        skipped++;
        continue;
      }

      // Read file as bytes then expose as XFile via blob URL
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final bytes = (reader.result as ByteBuffer).asUint8List();
      final blob  = html.Blob([bytes], file.type);
      final url   = html.Url.createObjectUrl(blob);
      validXFiles.add(XFile(url, name: file.name, length: file.size));
    }

    if (skipped > 0) {
      widget.onOversized?.call(skipped, widget.maxBytesPerFile / (1024 * 1024));
    }

    if (validXFiles.isNotEmpty) {
      widget.onFilesDropped(validXFiles);
    }
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
