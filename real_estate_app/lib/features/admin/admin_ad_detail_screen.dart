// lib/features/admin/presentation/screens/admin_ad_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme_config.dart';
import 'admin_dashboard_screen.dart';
import '../../../../core/utils/responsive_helper.dart'; // for adminServiceProvider

class AdminAdDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> ad;

  const AdminAdDetailScreen({super.key, required this.ad});

  @override
  ConsumerState<AdminAdDetailScreen> createState() => _AdminAdDetailScreenState();
}

class _AdminAdDetailScreenState extends ConsumerState<AdminAdDetailScreen> {
  late Map<String, dynamic> _ad;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ad = Map.from(widget.ad);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String get _headline   => _ad['headline']            as String? ?? _ad['title']    as String? ?? 'Ad';
  String get _company    => _ad['company_name']        as String? ?? _ad['advertiser_company'] as String? ?? '—';
  String? get _imageUrl  => _ad['image_url']           as String?;
  String? get _desc      => _ad['description']         as String?;
  String? get _cta       => _ad['call_to_action']      as String?;
  String? get _landing   => _ad['landing_url']         as String?;
  String? get _mediaType => _ad['media_type']          as String?;
  String  get _status    => _ad['status']              as String? ?? '—';
  bool   get _isApproved => _ad['is_approved']         as bool?   ?? false;
  bool   get _isDeleted  => _ad['deleted_at']          != null;

  // status badge
  Color get _statusColor {
    if (_isDeleted)                return ThemeConfig.errorColor;
    if (_isApproved)               return ThemeConfig.successColor;
    if (_status == 'rejected')     return ThemeConfig.errorColor;
    return ThemeConfig.warningColor;
  }

  String get _statusLabel {
    if (_isDeleted)                return 'DELETED';
    return _status.toUpperCase();
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _approve() async {
    setState(() => _loading = true);
    final ok = await ref.read(adminServiceProvider).approveAd(_ad['id'] as String);
    if (!mounted) return;
    _snack(ok ? 'Ad approved! Campaign is now running.' : 'Failed to approve', ok);
    if (ok) setState(() { _ad['is_approved'] = true; _ad['status'] = 'active'; });
    setState(() => _loading = false);
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Reject Ad',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
          decoration: const InputDecoration(
              hintText: 'Reason for rejection (required)',
              border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.errorColor, foregroundColor: Colors.white),
            onPressed: () {
              if (ctrl.text.isNotEmpty) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _loading = true);
    final ok = await ref.read(adminServiceProvider).rejectAd(_ad['id'] as String, reason);
    if (!mounted) return;
    _snack(ok ? 'Ad rejected' : 'Failed to reject', ok);
    if (ok) setState(() { _ad['status'] = 'rejected'; });
    setState(() => _loading = false);
  }

  Future<void> _delete() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Delete Ad',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('This will remove the ad and notify the advertiser.',
              style: TextStyle(color: ThemeConfig.getTextSecondaryColor(context))),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          TextField(
            controller: ctrl,
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
            decoration: const InputDecoration(
                hintText: 'Reason (optional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.errorColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    final result = await ref.read(adminServiceProvider).adminDeleteCreative(
      _ad['id'] as String,
      reason: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
    );
    if (!mounted) return;
    _snack(
      result['message'] as String? ??
          (result['success'] == true ? 'Ad deleted. Advertiser notified.' : 'Failed'),
      result['success'] == true,
    );
    if (result['success'] == true) Navigator.pop(context);
    setState(() => _loading = false);
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    final result = await ref.read(adminServiceProvider).adminRestoreCreative(_ad['id'] as String);
    if (!mounted) return;
    _snack(
      result['message'] as String? ??
          (result['success'] == true ? 'Ad restored. Pending review.' : 'Failed'),
      result['success'] == true,
    );
    if (result['success'] == true) setState(() { _ad['deleted_at'] = null; _ad['status'] = 'paused'; _ad['is_approved'] = false; });
    setState(() => _loading = false);
  }

  void _snack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? ThemeConfig.successColor : ThemeConfig.errorColor,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: ThemeConfig.getColor(context,
            lightColor: ThemeConfig.lightAppBarBackground,
            darkColor: ThemeConfig.darkAppBarBackground),
        iconTheme: IconThemeData(
            color: ThemeConfig.getColor(context,
                lightColor: ThemeConfig.lightAppBarForeground,
                darkColor: ThemeConfig.darkAppBarForeground)),
        title: Text('Ad Details',
            style: TextStyle(
                color: ThemeConfig.getColor(context,
                    lightColor: ThemeConfig.lightAppBarForeground,
                    darkColor: ThemeConfig.darkAppBarForeground),
                fontWeight: FontWeight.w600)),
        actions: [
          if (!_isDeleted && !_loading)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  color: ThemeConfig.getColor(context,
                      lightColor: ThemeConfig.lightAppBarForeground,
                      darkColor: ThemeConfig.darkAppBarForeground)),
              color: ThemeConfig.getCardColor(context),
              onSelected: (v) async {
                if (v == 'approve') await _approve();
                if (v == 'reject')  await _reject();
                if (v == 'delete')  await _delete();
              },
              itemBuilder: (_) => [
                if (!_isApproved && _status != 'rejected')
                  PopupMenuItem(value: 'approve', child: _menuItem(
                      Icons.check_circle_rounded, 'Approve',
                      color: ThemeConfig.successColor)),
                if (!_isApproved)
                  PopupMenuItem(value: 'reject', child: _menuItem(
                      Icons.cancel_rounded, 'Reject',
                      color: ThemeConfig.warningColor)),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'delete', child: _menuItem(
                    Icons.delete_outline_rounded, 'Delete Ad',
                    color: ThemeConfig.errorColor)),
              ],
            )
          else if (_isDeleted && !_loading)
            IconButton(
              icon: const Icon(Icons.restore_rounded),
              color: ThemeConfig.successColor,
              tooltip: 'Restore Ad',
              onPressed: _restore,
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ThemeConfig.getPrimaryColor(context)))
          : SingleChildScrollView(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Media Preview ──────────────────────────────────────────────
                if (_imageUrl != null) _buildMediaPreview(),

                SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

                // ── Status Badge ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusColor.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_isDeleted ? Icons.delete_rounded
                        : _isApproved ? Icons.check_circle_rounded
                        : _status == 'rejected' ? Icons.cancel_rounded
                        : Icons.pending_rounded,
                        size: 16, color: _statusColor),
                    const SizedBox(width: 6),
                    Text(_statusLabel,
                        style: TextStyle(
                            color: _statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ]),
                ),

                SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

                // ── Headline & Company ─────────────────────────────────────────
                _detailCard(children: [
                  _row(Icons.title_rounded, 'Headline', _headline),
                  const Divider(),
                  _row(Icons.business_rounded, 'Company', _company),
                  if (_desc != null) ...[
                    const Divider(),
                    _row(Icons.description_rounded, 'Description', _desc!),
                  ],
                  if (_cta != null) ...[
                    const Divider(),
                    _row(Icons.touch_app_rounded, 'Call to Action', _cta!),
                  ],
                  if (_landing != null) ...[
                    const Divider(),
                    _row(Icons.link_rounded, 'Landing URL', _landing!),
                  ],
                  if (_mediaType != null) ...[
                    const Divider(),
                    _row(Icons.perm_media_rounded, 'Media Type', _mediaType!),
                  ],
                ]),

                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),

                // ── Meta info ─────────────────────────────────────────────────
                _detailCard(children: [
                  if (_ad['created_at'] != null)
                    _row(Icons.calendar_today_rounded, 'Created',
                        _ad['created_at'].toString().split('T').first),
                  if (_ad['advertiser_email'] != null) ...[
                    const Divider(),
                    _row(Icons.email_rounded, 'Advertiser Email',
                        _ad['advertiser_email'].toString()),
                  ],
                  if (_ad['clicks'] != null) ...[
                    const Divider(),
                    _row(Icons.mouse_rounded, 'Clicks', '${_ad['clicks']}'),
                  ],
                  if (_ad['impressions'] != null) ...[
                    const Divider(),
                    _row(Icons.visibility_rounded, 'Impressions', '${_ad['impressions']}'),
                  ],
                  if (_ad['deletion_reason'] != null) ...[
                    const Divider(),
                    _row(Icons.info_rounded, 'Deletion Reason',
                        _ad['deletion_reason'].toString(),
                        valueColor: ThemeConfig.errorColor),
                  ],
                  if (_ad['rejection_reason'] != null) ...[
                    const Divider(),
                    _row(Icons.info_rounded, 'Rejection Reason',
                        _ad['rejection_reason'].toString(),
                        valueColor: ThemeConfig.errorColor),
                  ],
                ]),

                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                // ── Action Buttons ─────────────────────────────────────────────
                if (!_isDeleted) ...[
                  if (!_isApproved && _status != 'rejected')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Approve Ad'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeConfig.successColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: _approve,
                      ),
                    ),
                  if (!_isApproved) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject Ad'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: ThemeConfig.warningColor,
                            side: const BorderSide(color: ThemeConfig.warningColor),
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: _reject,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete Ad'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: ThemeConfig.errorColor,
                          side: BorderSide(color: ThemeConfig.errorColor.withOpacity(0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _delete,
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restore Ad'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConfig.successColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _restore,
                    ),
                  ),

                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),
              ]),
            ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────────

  Widget _buildMediaPreview() {
    if (_mediaType == 'video') {
      // Show a playable video. videoUrl preferred, fall back to imageUrl.
      final videoSrc = (_ad['video_url'] as String?)?.isNotEmpty == true
          ? _ad['video_url'] as String
          : _imageUrl;
      if (videoSrc != null && videoSrc.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: _AdVideoPlayer(url: videoSrc),
          ),
        );
      }
    }
    // Image ad
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        _imageUrl!,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 120,
          color: ThemeConfig.getColor(context,
              lightColor: ThemeConfig.lightInputFill,
              darkColor: ThemeConfig.darkInputFill),
          child: Center(child: Icon(Icons.broken_image, size: ResponsiveHelper.getResponsiveIconSize(context))),
        ),
      ),
    );
  }

  Widget _detailCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeConfig.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeConfig.getColor(context,
              lightColor: ThemeConfig.lightBorder,
              darkColor: ThemeConfig.darkBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: ThemeConfig.getPrimaryColor(context)),
        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                    fontWeight: FontWeight.w600,
                    color: ThemeConfig.getTextSecondaryColor(context),
                    letterSpacing: 0.4)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                    color: valueColor ?? ThemeConfig.getTextPrimaryColor(context))),
          ]),
        ),
      ]),
    );
  }

  Widget _menuItem(IconData icon, String label, {Color? color}) {
    return Row(children: [
      Icon(icon, size: 16, color: color ?? ThemeConfig.getTextPrimaryColor(context)),
      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
      Text(label, style: TextStyle(
          color: color ?? ThemeConfig.getTextPrimaryColor(context))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// AD VIDEO PLAYER WIDGET
// ─────────────────────────────────────────────────────────────────────────

class _AdVideoPlayer extends StatefulWidget {
  final String url;
  const _AdVideoPlayer({required this.url});

  @override
  State<_AdVideoPlayer> createState() => _AdVideoPlayerState();
}

class _AdVideoPlayerState extends State<_AdVideoPlayer> {
  VideoPlayerController? _vpc;
  ChewieController? _chc;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await ctrl.initialize();
      final chc = ChewieController(
        videoPlayerController: ctrl,
        autoPlay: false,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: ThemeConfig.primaryColor,
          handleColor: ThemeConfig.primaryColor,
          backgroundColor: Colors.grey.shade700,
          bufferedColor: Colors.grey.shade500,
        ),
      );
      if (mounted) setState(() { _vpc = ctrl; _chc = chc; });
    } catch (e) {
      debugPrint('Ad video error: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _chc?.dispose();
    _vpc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
      color: Colors.black87,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline_rounded, color: Colors.red, size: ResponsiveHelper.getResponsiveIconSize(context)),
          const SizedBox(height: 8),
          const Text('Failed to load video', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
    );
    }
    if (_chc == null) {
      return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          SizedBox(height: 12),
          Text('Loading video...', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
    );
    }
    return Chewie(controller: _chc!);
  }
}