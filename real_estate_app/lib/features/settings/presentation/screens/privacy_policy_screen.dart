// lib/features/settings/presentation/screens/privacy_policy_screen.dart
//
// Displays the Patamjengo Privacy Policy inside the app.
// On Android/iOS  → loads the bundled HTML asset via WebView.
// On Web (PWA)    → navigates to /privacy_policy.html in the same origin.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public URL where the privacy policy is hosted.
/// Update this once you deploy the PWA to a real domain.
const String kPrivacyPolicyUrl =
    'https://patamjengo.com/privacy_policy.html';

/// Effective date shown in the app bar subtitle.
const String kPrivacyPolicyDate = 'March 2026';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError  = false;

  @override
  void initState() {
    super.initState();

    // WebView is only available on mobile platforms.
    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() { _isLoading = true;  _hasError = false; }),
            onPageFinished: (_) => setState(() => _isLoading = false),
            onWebResourceError: (_) => setState(() {
              _isLoading = false;
              _hasError  = true;
            }),
          ),
        )
        ..loadFlutterAsset('assets/docs/privacy_policy.html');
    } else {
      _controller = null;
      _isLoading  = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: kIsWeb ? _buildWebBody(theme) : _buildMobileBody(theme),
    );
  }

  // ── Web: show a card with a link (can't load local HTML in PWA) ──────────
  Widget _buildWebBody(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.privacy_tip_outlined, size: 64, color: theme.primaryColor),
                const SizedBox(height: 16),
                Text('Privacy Policy',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Effective: $kPrivacyPolicyDate',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 20),
                const Text(
                  'Our Privacy Policy explains what data Patamjengo collects, '
                  'how it is used, and your rights under Tanzanian law.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Read Full Privacy Policy'),
                  onPressed: _openInBrowser,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mobile: WebView showing the bundled HTML ──────────────────────────────
  Widget _buildMobileBody(ThemeData theme) {
    if (_hasError) {
      return _buildErrorView(theme);
    }
    return Stack(
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            const Text('Could not load the privacy policy.',
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open in Browser'),
              onPressed: _openInBrowser,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(kPrivacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
