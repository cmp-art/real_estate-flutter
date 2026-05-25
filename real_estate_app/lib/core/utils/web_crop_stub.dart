// lib/core/utils/web_crop_stub.dart
// No-op stub for Android / iOS — cropToCard uses the Dart image package there.
import 'dart:typed_data';

Future<Uint8List?> webCropToCard(Uint8List bytes) async => null;

Future<Uint8List?> webResizeToMaxEdge(Uint8List bytes,
        {int maxEdge = 1600}) async =>
    null;

Future<({List<Uint8List> bytes, int failed})> pickImagesAsBytesWeb(
        {bool multiple = true, bool capture = false}) async =>
    (bytes: const <Uint8List>[], failed: 0);
