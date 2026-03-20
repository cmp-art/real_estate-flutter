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

  void _handleDragOver(html.MouseEvent event) {
    event.preventDefault();
    event.stopPropagation();
    if (!_isDragging && mounted) setState(() => _isDragging = true);
  }

  void _handleDragLeave(html.MouseEvent event) {
    if (_isDragging && mounted) setState(() => _isDragging = false);
  }

  void _handleDrop(html.MouseEvent event) {
    event.preventDefault();
    event.stopPropagation();
    if (mounted) setState(() => _isDragging = false);

    final dt = (event as html.DragEvent).dataTransfer;
    if (dt == null) return;

    final files = dt.files;
    if (files == null || files.isEmpty) return;

    _processFiles(files);
  }

  Future<void> _processFiles(html.FileList files) async {
    final validXFiles = <XFile>[];
    int skipped = 0;

    final allowed = <String>['image/jpeg', 'image/jpg', 'image/png', 'image/webp',
                             'image/heic', 'image/heif'];

    for (int i = 0; i < files.length && validXFiles.length < widget.maxFiles; i++) {
      final file = files[i]!;
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
      final blob = html.Blob([bytes], file.type);
      final url  = html.Url.createObjectUrl(blob);
      validXFiles.add(XFile(url, name: file.name, length: file.size));
    }

    if (skipped > 0) {
      widget.onOversized?.call(
          skipped, widget.maxBytesPerFile / (1024 * 1024));
    }

    if (validXFiles.isNotEmpty) {
      widget.onFilesDropped(validXFiles);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Attach native HTML event listeners to the document body so the entire
    // drop zone is covered, regardless of Flutter's event-loop interception.
    return MouseRegion(
      child: Listener(
        onPointerDown: (_) {},
        child: GestureDetector(
          onTap: () {},
          child: _HtmlDropTarget(
            isDragging: _isDragging,
            onDragOver: _handleDragOver,
            onDragLeave: _handleDragLeave,
            onDrop: _handleDrop,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Thin widget that registers dart:html drag event listeners on the Flutter
/// platform view element so OS-level file drags are captured.
class _HtmlDropTarget extends StatefulWidget {
  final Widget child;
  final bool isDragging;
  final void Function(html.MouseEvent) onDragOver;
  final void Function(html.MouseEvent) onDragLeave;
  final void Function(html.MouseEvent) onDrop;

  const _HtmlDropTarget({
    required this.child,
    required this.isDragging,
    required this.onDragOver,
    required this.onDragLeave,
    required this.onDrop,
  });

  @override
  State<_HtmlDropTarget> createState() => _HtmlDropTargetState();
}

class _HtmlDropTargetState extends State<_HtmlDropTarget> {
  List<html.EventListener> _listeners = [];

  @override
  void initState() {
    super.initState();
    _attachListeners();
  }

  void _attachListeners() {
    final body = html.document.body!;

    final overListener  = (html.Event e) => widget.onDragOver(e as html.MouseEvent);
    final leaveListener = (html.Event e) => widget.onDragLeave(e as html.MouseEvent);
    final dropListener  = (html.Event e) => widget.onDrop(e as html.MouseEvent);

    body.addEventListener('dragover',  overListener);
    body.addEventListener('dragleave', leaveListener);
    body.addEventListener('drop',      dropListener);

    _listeners = [overListener, leaveListener, dropListener];
  }

  @override
  void dispose() {
    final body = html.document.body!;
    final events = ['dragover', 'dragleave', 'drop'];
    for (int i = 0; i < _listeners.length; i++) {
      body.removeEventListener(events[i], _listeners[i]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: widget.isDragging
          ? BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.05),
            )
          : null,
      child: widget.child,
    );
  }
}
