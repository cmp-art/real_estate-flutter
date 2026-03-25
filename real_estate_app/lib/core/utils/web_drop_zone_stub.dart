// lib/core/utils/web_drop_zone_stub.dart
// Native stub — drag-and-drop from OS is not supported on mobile/desktop.
// The widget simply renders its child unchanged.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class WebDropZone extends StatelessWidget {
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
  Widget build(BuildContext context) => child;
}
