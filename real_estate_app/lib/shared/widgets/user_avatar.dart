// lib/shared/widgets/user_avatar.dart
//
// A circular user avatar that is robust on every platform (native, web, PWA).
//
// The old pattern — CircleAvatar(backgroundImage: CachedNetworkImageProvider,
// child: url == null ? letter : null) — shows a BLANK circle whenever the URL
// is non-null but fails to load (404, slow network, transform endpoint off),
// because the letter only renders when the URL is null. This widget instead
// uses CachedNetworkImage with a placeholder AND error fallback, so the user
// always sees either the photo or their initial — never an empty circle.
//
// It also accepts in-memory [previewBytes] so a freshly-picked image shows
// instantly (no upload round-trip), and an optional [onTap] for opening the
// photo full-screen via [FullScreenAvatarViewer].

import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String fullName;
  final double radius;

  /// Locally-held bytes for an instant preview (e.g. a just-picked image).
  /// Takes precedence over [avatarUrl] when present.
  final Uint8List? previewBytes;

  final Color? backgroundColor;
  final Color? letterColor;
  final double? letterFontSize;
  final VoidCallback? onTap;

  /// Shared element tag for a Hero transition into the full-screen viewer.
  final String? heroTag;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.fullName,
    this.radius = 50,
    this.previewBytes,
    this.backgroundColor,
    this.letterColor,
    this.letterFontSize,
    this.onTap,
    this.heroTag,
  });

  String get _initial {
    final n = fullName.trim();
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final bg = backgroundColor ?? Colors.grey.shade200;
    final fg = letterColor ?? Theme.of(context).primaryColor;

    Widget letter() => Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          color: bg,
          child: Text(
            _initial,
            style: TextStyle(
              fontSize: letterFontSize ?? radius * 0.8,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        );

    Widget content;
    if (previewBytes != null && previewBytes!.isNotEmpty) {
      content = Image.memory(
        previewBytes!,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => letter(),
      );
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      content = CachedNetworkImage(
        imageUrl: avatarUrl!,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        placeholder: (_, __) => letter(),
        errorWidget: (_, __, ___) => letter(),
      );
    } else {
      content = letter();
    }

    Widget avatar = SizedBox(
      width: diameter,
      height: diameter,
      child: ClipOval(child: content),
    );

    if (heroTag != null) {
      avatar = Hero(tag: heroTag!, child: avatar);
    }

    if (onTap != null) {
      avatar = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}

/// Full-screen, pinch-to-zoom viewer for a single avatar image. Accepts either
/// a network [imageUrl] or in-memory [imageBytes] (a just-picked photo). Opens
/// as a full-screen dialog; tap the close button or swipe back to dismiss.
class FullScreenAvatarViewer extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? heroTag;

  const FullScreenAvatarViewer({
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.heroTag,
  });

  /// Returns true if there is something to show, and pushes the viewer.
  static bool open(
    BuildContext context, {
    String? imageUrl,
    Uint8List? imageBytes,
    String? heroTag,
  }) {
    final hasImage = (imageBytes != null && imageBytes.isNotEmpty) ||
        (imageUrl != null && imageUrl.isNotEmpty);
    if (!hasImage) return false;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenAvatarViewer(
          imageUrl: imageUrl,
          imageBytes: imageBytes,
          heroTag: heroTag,
        ),
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      provider = MemoryImage(imageBytes!);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      provider = CachedNetworkImageProvider(imageUrl!);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: provider == null
          ? const Center(
              child: Icon(Icons.person, color: Colors.white54, size: 96),
            )
          : PhotoView(
              imageProvider: provider,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3.0,
              heroAttributes: heroTag != null
                  ? PhotoViewHeroAttributes(tag: heroTag!)
                  : null,
              loadingBuilder: (_, __) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 96),
              ),
            ),
    );
  }
}
