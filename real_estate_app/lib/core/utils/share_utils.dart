// lib/core/utils/share_utils.dart
//
// Handles sharing across all platforms:
//   Native (Android/iOS)  → system share sheet via share_plus
//   Desktop web (PC)      → custom dialog with copy, WhatsApp, Email buttons
//   Mobile web            → system share sheet via share_plus (works fine)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme_config.dart';
import '../utils/snackbar_utils.dart';

class ShareUtils {
  /// Share a property. Uses native share sheet on mobile/mobile-web,
  /// custom dialog on desktop web (where share_plus falls back to email only).
  static Future<void> shareProperty(
    BuildContext context, {
    required String title,
    required String price,
    required String location,
    required int bedrooms,
    required int bathrooms,
    required int area,
    required bool isRent,
  }) async {
    final rentSuffix = isRent ? '/month' : '';
    final message = '🏠 *$title*\n\n'
        '💰 $price$rentSuffix\n'
        '📍 $location\n'
        '🛏 $bedrooms beds  🚿 $bathrooms baths  📐 ${area} sqft\n\n'
        'Check it out on Patamjengo 👇\nhttps://patamjengo.netlify.app';

    await _share(context, message: message, subject: title);
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  static Future<void> _share(
    BuildContext context, {
    required String message,
    required String subject,
  }) async {
    // Desktop web: show custom share dialog
    if (kIsWeb && _isDesktopWidth(context)) {
      _showDesktopShareDialog(context, message: message, subject: subject);
      return;
    }

    // Native + mobile web: use system share sheet
    try {
      await Share.share(message, subject: subject);
    } catch (_) {
      // Fallback to custom dialog on any error
      if (context.mounted) {
        _showDesktopShareDialog(context, message: message, subject: subject);
      }
    }
  }

  static bool _isDesktopWidth(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768;

  static void _showDesktopShareDialog(
    BuildContext context, {
    required String message,
    required String subject,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final whatsappUrl =
        'https://wa.me/?text=${Uri.encodeComponent(message)}';
    final emailUrl =
        'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(message)}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.share_outlined,
                color: ThemeConfig.primaryColor, size: 22),
            const SizedBox(width: 8),
            Text(
              'Share',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  height: 1.5,
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            // Share buttons
            _ShareButton(
              icon: Icons.copy_rounded,
              label: 'Copy to Clipboard',
              color: isDark ? Colors.grey[300]! : Colors.black87,
              bgColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: message));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  SnackbarUtils.showSuccess(context, 'Copied to clipboard');
                }
              },
            ),
            const SizedBox(height: 8),
            _ShareButton(
              icon: Icons.chat_rounded,
              label: 'Share via WhatsApp',
              color: Colors.white,
              bgColor: const Color(0xFF25D366),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(whatsappUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 8),
            _ShareButton(
              icon: Icons.email_outlined,
              label: 'Share via Email',
              color: Colors.white,
              bgColor: Colors.blue[600]!,
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(emailUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 20),
        label: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
