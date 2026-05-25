// lib/core/utils/web_drop_zone_stub.dart
// Native stub — drag-and-drop from OS is not supported on mobile/desktop.
// The widget simply renders its child unchanged.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class WebDropZone extends StatelessWidget {
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
  Widget build(BuildContext context) => child;
}
