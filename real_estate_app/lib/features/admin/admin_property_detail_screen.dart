// lib/features/admin/presentation/screens/admin_property_detail_screen.dart
// Full-screen admin view for a single property:
//   - View all images
//   - Delete individual media items (with notification to owner)
//   - Delete / restore / feature / verify the property
//   - Send notification to owner

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/responsive_helper.dart';
import 'admin_dashboard_screen.dart' show adminServiceProvider;

class AdminPropertyDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> property;
  const AdminPropertyDetailScreen({super.key, required this.property});

  @override
  ConsumerState<AdminPropertyDetailScreen> createState() =>
      _AdminPropertyDetailScreenState();
}

class _AdminPropertyDetailScreenState
    extends ConsumerState<AdminPropertyDetailScreen> {
  late Map<String, dynamic> _prop;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _prop = Map<String, dynamic>.from(widget.property);
  }

  List<String> get _images =>
      (_prop['images'] as List?)?.cast<String>() ?? [];
  List<String> get _mediaUrls =>
      (_prop['media_urls'] as List?)?.cast<String>() ?? [];

  /// Combined media: images first, then any extra media_urls (images only)
  List<_MediaItem> get _allMedia {
    final items = <_MediaItem>[];
    for (final url in _images) {
      items.add(_MediaItem(url: url));
    }
    for (final url in _mediaUrls) {
      if (!_images.contains(url)) {
        items.add(_MediaItem(url: url));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDeleted = _prop['is_deleted'] as bool? ?? false;
    final isFeatured = _prop['is_featured'] as bool? ?? false;
    final isVerified = _prop['is_verified'] as bool? ?? false;
    final media = _allMedia;

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: ThemeConfig.getColor(context,
            lightColor: ThemeConfig.lightAppBarBackground,
            darkColor: ThemeConfig.darkAppBarBackground),
        title: Text('Property Details',
            style: TextStyle(
                color: ThemeConfig.getColor(context,
                    lightColor: ThemeConfig.lightAppBarForeground,
                    darkColor: ThemeConfig.darkAppBarForeground))),
        iconTheme: IconThemeData(
            color: ThemeConfig.getColor(context,
                lightColor: ThemeConfig.lightAppBarForeground,
                darkColor: ThemeConfig.darkAppBarForeground)),
        actions: [
          if (_processing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  color: ThemeConfig.getColor(context,
                      lightColor: ThemeConfig.lightAppBarForeground,
                      darkColor: ThemeConfig.darkAppBarForeground)),
              color: ThemeConfig.getCardColor(context),
              onSelected: (v) async {
                if (v == 'delete')   await _deleteProperty();
                if (v == 'restore')  await _restoreProperty();
                if (v == 'feature')  await _toggleFeature();
                if (v == 'verify')   await _toggleVerify();
                if (v == 'notify')   await _notifyOwner();
              },
              itemBuilder: (_) => [
                if (!isDeleted) ...[
                  _popItem('feature', isFeatured ? Icons.star_border_rounded : Icons.star_rounded,
                      isFeatured ? 'Unfeature' : 'Feature Property'),
                  _popItem('verify',
                      isVerified ? Icons.verified_outlined : Icons.verified_rounded,
                      isVerified ? 'Remove Verification' : 'Verify Property'),
                  _popItem('notify', Icons.notifications_rounded, 'Notify Owner'),
                  const PopupMenuDivider(),
                  _popItem('delete', Icons.delete_outline_rounded, 'Delete Property',
                      color: ThemeConfig.errorColor),
                ] else
                  _popItem('restore', Icons.restore_rounded, 'Restore Property',
                      color: ThemeConfig.successColor),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        // Responsive container for better layout on larger screens
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Deletion banner — colour and icon differ by who deleted ──
          if (isDeleted) ...[
            if (_prop['deleted_by_user'] == true)
              _StatusBanner(
                icon: Icons.person_remove_rounded,
                message: 'Deleted by the property owner.',
                detail: null,
                subDetail: _prop['deleted_at'] != null
                    ? 'Deleted on ${_fmtDate(_prop['deleted_at'] as String)}'
                    : null,
                color: Colors.orange,
              )
            else
              _StatusBanner(
                icon: Icons.admin_panel_settings_rounded,
                message: 'Deleted by an administrator.',
                detail: _prop['deletion_reason'] as String?,
                subDetail: _prop['deleted_at'] != null
                    ? 'Deleted on ${_fmtDate(_prop['deleted_at'] as String)}'
                    : null,
                color: ThemeConfig.errorColor,
              ),
            const SizedBox(height: 4),
          ],

          // ── Property info ──
          _InfoSection(prop: _prop),
          const SizedBox(height: 20),

          // ── Ownership verification history ──
          _OwnerVerificationSection(
            prop: _prop,
            propertyId: _prop['id'] as String,
          ),
          const SizedBox(height: 20),

          // ── Media gallery ──
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Media (${media.length} items)',
                style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.bold,
                    color: ThemeConfig.getTextPrimaryColor(context))),
            Text('${_images.length} photos',
                style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                    color: ThemeConfig.getTextSecondaryColor(context))),
          ]),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),

          if (media.isEmpty)
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: ThemeConfig.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeConfig.getColor(context,
                    lightColor: ThemeConfig.lightBorder,
                    darkColor: ThemeConfig.darkBorder)),
              ),
              child: Center(child: Text('No media attached',
                  style: TextStyle(color: ThemeConfig.getTextSecondaryColor(context)))),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveHelper.getGridColumns(context, mobile: 1, tablet: 2, desktop: 3),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: media.length,
              itemBuilder: (_, i) {
                final item = media[i];
                return _MediaTile(
                  item: item,
                  onTap: () => _showMediaFullscreen(item),
                  onDelete: isDeleted ? null : () => _deleteMedia(item.url),
                );
              },
            ),

          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),
        ]),
      ),
    );
  }

  void _showMediaFullscreen(_MediaItem item) {
    Navigator.push(context, MaterialPageRoute(builder: (_) =>
        _FullscreenMediaView(item: item)));
  }

  Future<void> _deleteMedia(String mediaUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Delete Media',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Are you sure you want to remove this media item?',
              style: TextStyle(color: ThemeConfig.getTextSecondaryColor(context))),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Text('The property owner will be notified.',
              style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: ThemeConfig.warningColor)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.errorColor,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Reason (Optional)',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: TextField(
          controller: reasonCtrl,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
          decoration: const InputDecoration(
              hintText: 'e.g. Inappropriate content',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Skip')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(context),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    setState(() => _processing = true);
    final result = await ref.read(adminServiceProvider).adminDeletePropertyMedia(
      _prop['id'] as String,
      mediaUrl,
      reason: reason?.isEmpty == true ? null : reason,
    );
    setState(() => _processing = false);

    if (!mounted) return;
    if (result['success'] == true) {
      // Optimistically remove from local state
      setState(() {
        final images = List<String>.from(_prop['images'] as List? ?? []);
        final mediaUrls = List<String>.from(_prop['media_urls'] as List? ?? []);
        images.remove(mediaUrl);
        mediaUrls.remove(mediaUrl);
        _prop['images'] = images;
        _prop['media_urls'] = mediaUrls;
      });
      _snack('Media deleted. Owner has been notified.', true);
    } else {
      _snack('Failed: ${result['error'] ?? 'Unknown error'}', false);
    }
  }

  Future<void> _deleteProperty() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Delete Property',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('This will remove the property and notify the owner.',
              style: TextStyle(color: ThemeConfig.getTextSecondaryColor(context))),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          TextField(
            controller: ctrl,
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
            decoration: const InputDecoration(
                hintText: 'Reason (optional)',
                border: OutlineInputBorder()),
            maxLines: 3,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.errorColor,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;

    setState(() => _processing = true);
    final result = await ref.read(adminServiceProvider).adminDeleteProperty(
        _prop['id'] as String, reason: reason.isEmpty ? null : reason);
    setState(() {
      _processing = false;
      if (result['success'] == true) {
        _prop['is_deleted'] = true;
        _prop['deleted_at'] = DateTime.now().toIso8601String();
        _prop['deletion_reason'] = reason.isEmpty ? null : reason;
      }
    });
    if (mounted) {
      _snack(result['message'] as String? ??
          (result['success'] == true
              ? 'Property deleted. Owner notified.'
              : 'Failed: ${result['error']}'),
          result['success'] == true);
    }
  }

  Future<void> _restoreProperty() async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Restore Property',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'This will restore the property and make it visible again. The owner will be notified.',
            style: TextStyle(color: ThemeConfig.getTextSecondaryColor(context), fontSize: 13),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          TextField(
            controller: noteCtrl,
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
            decoration: const InputDecoration(
                hintText: 'Note to owner (optional)',
                border: OutlineInputBorder()),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.successColor,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    final result = await ref.read(adminServiceProvider).adminRestoreProperty(
        _prop['id'] as String,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
    setState(() {
      _processing = false;
      if (result['success'] == true) {
        _prop['is_deleted']      = false;
        _prop['deleted_at']      = null;
        _prop['deleted_by_user'] = false;
        _prop['deleted_by_admin']= null;
        _prop['deletion_reason'] = null;
      }
    });
    if (mounted) {
      _snack(result['message'] as String? ??
          (result['success'] == true
              ? 'Property restored. Owner notified.'
              : 'Failed: ${result['error']}'),
          result['success'] == true);
    }
  }

  Future<void> _toggleFeature() async {
    final isFeatured = _prop['is_featured'] as bool? ?? false;
    setState(() => _processing = true);
    final ok = await ref.read(adminServiceProvider).adminFeatureProperty(
        _prop['id'] as String, featured: !isFeatured);
    setState(() {
      _processing = false;
      if (ok) _prop['is_featured'] = !isFeatured;
    });
    if (mounted) {
      _snack(ok
          ? (!isFeatured ? '⭐ Property featured! Owner notified.' : 'Feature removed. Owner notified.')
          : 'Failed to update', ok);
    }
  }

  Future<void> _toggleVerify() async {
    final isVerified = _prop['is_verified'] as bool? ?? false;
    setState(() => _processing = true);
    final ok = await ref.read(adminServiceProvider).adminVerifyProperty(
        _prop['id'] as String, verified: !isVerified);
    setState(() {
      _processing = false;
      if (ok) _prop['is_verified'] = !isVerified;
    });
    if (mounted) {
      _snack(ok
          ? (!isVerified ? '✅ Property verified! Owner notified.' : 'Verification removed. Owner notified.')
          : 'Failed to update', ok);
    }
  }

  Future<void> _notifyOwner() async {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Notify Property Owner',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl,
              style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
              decoration: const InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder())),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          TextField(controller: msgCtrl, maxLines: 3,
              style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
              decoration: const InputDecoration(
                  labelText: 'Message', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(context),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (sent == true && titleCtrl.text.isNotEmpty && msgCtrl.text.isNotEmpty) {
      final ok = await ref.read(adminServiceProvider).sendNotificationToUser(
        userId: _prop['owner_id'] as String,
        title: titleCtrl.text.trim(),
        message: msgCtrl.text.trim(),
        type: 'admin_message',
        data: {'property_id': _prop['id']},
      );
      if (mounted) _snack(ok ? 'Notification sent!' : 'Failed to send', ok);
    }
  }

  PopupMenuItem<String> _popItem(String value, IconData icon, String label,
      {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18,
            color: color ?? ThemeConfig.getTextPrimaryColor(context)),
        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
        Text(label, style: TextStyle(
            color: color ?? ThemeConfig.getTextPrimaryColor(context))),
      ]),
    );
  }

  void _snack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? ThemeConfig.successColor : ThemeConfig.errorColor,
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────
// PROPERTY INFO SECTION
// ─────────────────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final Map<String, dynamic> prop;
  const _InfoSection({required this.prop});

  @override
  Widget build(BuildContext context) {
    final isFeatured = prop['is_featured'] as bool? ?? false;
    final isVerified = prop['is_verified'] as bool? ?? false;
    final price = (prop['price'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: ThemeConfig.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeConfig.getColor(context,
            lightColor: ThemeConfig.lightBorder,
            darkColor: ThemeConfig.darkBorder)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(prop['title'] as String? ?? 'Untitled',
                style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18), fontWeight: FontWeight.bold,
                    color: ThemeConfig.getTextPrimaryColor(context))),
          ),
          if (isFeatured)
            const Tooltip(message: 'Featured',
                child: Icon(Icons.star_rounded, color: Colors.amber)),
          if (isVerified)
            const Tooltip(message: 'Verified',
                child: Icon(Icons.verified_rounded, color: Colors.blue)),
        ]),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        _infoRow(context, Icons.location_on_rounded, prop['location'] as String? ?? '—'),
        _infoRow(context, Icons.category_rounded, prop['property_type'] as String? ?? '—'),
        _infoRow(context, Icons.payments_rounded, 'TZS ${_fmt(price)}'),
        _infoRow(context, Icons.circle_rounded,
            (prop['status'] as String? ?? 'available').toUpperCase(),
            valueColor: _statusColor(prop['status'] as String? ?? '')),
        _infoRow(context, Icons.visibility_rounded,
            '${prop['views_count'] ?? 0} views'),
        const Divider(height: 20),
        _infoRow(context, Icons.person_rounded,
            prop['owner_name'] as String? ?? '—'),
        _infoRow(context, Icons.email_rounded,
            prop['owner_email'] as String? ?? '—'),
        if (prop['owner_phone'] != null)
          _infoRow(context, Icons.phone_rounded,
              prop['owner_phone'] as String),
        const Divider(height: 20),
        _infoRow(context, Icons.calendar_today_rounded,
            _fmtDate(prop['created_at'] as String?)),
        if (prop['description'] != null) ...[
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Text('Description',
              style: TextStyle(fontWeight: FontWeight.w600,
                  color: ThemeConfig.getTextPrimaryColor(context))),
          const SizedBox(height: 4),
          Text(prop['description'] as String,
              style: TextStyle(color: ThemeConfig.getTextSecondaryColor(context),
                  fontSize: 13)),
        ],
      ]),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 16, color: ThemeConfig.getTextSecondaryColor(context)),
        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
        Expanded(
          child: Text(value, style: TextStyle(
              color: valueColor ?? ThemeConfig.getTextPrimaryColor(context),
              fontSize: 13)),
        ),
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'available': return Colors.green;
      case 'sold':      return Colors.red;
      case 'rented':    return Colors.orange;
      case 'pending':   return Colors.blue;
      default:          return Colors.grey;
    }
  }

  String _fmt(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  String _fmtDate(String? s) {
    if (s == null) return '—';
    try {
      return DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// OWNERSHIP VERIFICATION SECTION
// ─────────────────────────────────────────────────────────────────────────

class _OwnerVerificationSection extends ConsumerStatefulWidget {
  final Map<String, dynamic> prop;
  final String propertyId;
  const _OwnerVerificationSection({required this.prop, required this.propertyId});

  @override
  ConsumerState<_OwnerVerificationSection> createState() =>
      _OwnerVerificationSectionState();
}

class _OwnerVerificationSectionState
    extends ConsumerState<_OwnerVerificationSection> {
  List<Map<String, dynamic>>? _history;
  bool _loading = false;
  bool _expanded = false;

  bool   get _isOwnerVerified => widget.prop['is_owner_verified'] as bool? ?? false;
  String get _method          => widget.prop['verification_method'] as String? ?? '—';
  String get _verifiedAt      => widget.prop['verified_at']         as String? ?? '';

  Future<void> _loadHistory() async {
    if (_loading || widget.propertyId.isEmpty) return;
    setState(() => _loading = true);
    final svc = ref.read(adminServiceProvider);
    final rows = await svc.getPropertyVerifications(widget.propertyId);
    if (mounted) setState(() { _history = rows; _loading = false; });
  }

  String _fmtDate(String? s) {
    if (s == null || s.isEmpty) return '—';
    try { return DateFormat('MMM d, yyyy  HH:mm').format(DateTime.parse(s)); }
    catch (_) { return s; }
  }

  String _methodLabel(String m) {
    if (m == 'near_owner') return 'Near Owner (GPS + Photo)';
    if (m == 'far_owner')  return 'Far Owner (ID + Hati OCR)';
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verified = _isOwnerVerified;
    final badgeColor   = verified ? Colors.green : Colors.grey;
    final badgeIcon    = verified ? Icons.verified_user_rounded : Icons.gpp_maybe_outlined;
    final badgeLabel   = verified ? 'Owner Verified' : 'Not Verified';

    return Container(
      decoration: BoxDecoration(
        color:        ThemeConfig.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: verified
              ? Colors.green.withOpacity(0.4)
              : ThemeConfig.getColor(context,
                  lightColor: ThemeConfig.lightBorder,
                  darkColor:  ThemeConfig.darkBorder),
          width: verified ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded && _history == null) _loadHistory();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(Icons.security_rounded, size: 18,
                    color: ThemeConfig.getTextSecondaryColor(context)),
                const SizedBox(width: 8),
                Text('Ownership Verification',
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ThemeConfig.getTextPrimaryColor(context))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(color: badgeColor.withOpacity(0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(badgeIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(badgeLabel, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: badgeColor)),
                  ]),
                ),
                const SizedBox(width: 6),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: ThemeConfig.getTextSecondaryColor(context)),
              ]),
            ),
          ),

          if (_expanded) ...[
            Divider(height: 1,
                color: ThemeConfig.getColor(context,
                    lightColor: ThemeConfig.lightBorder,
                    darkColor:  ThemeConfig.darkBorder)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Summary row ─────────────────────────────────────────
                  if (verified) ...[
                    _kvRow(context, 'Method',      _methodLabel(_method)),
                    _kvRow(context, 'Verified at', _fmtDate(_verifiedAt)),
                    const SizedBox(height: 12),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'This property has not been owner-verified yet.',
                        style: TextStyle(fontSize: 13,
                            color: ThemeConfig.getTextSecondaryColor(context)),
                      ),
                    ),

                  // ── Attempt history ──────────────────────────────────────
                  Text('Verification Attempts',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                          color: ThemeConfig.getTextPrimaryColor(context))),
                  const SizedBox(height: 8),

                  if (_loading)
                    const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  else if (_history == null || _history!.isEmpty)
                    Text('No attempts recorded.',
                        style: TextStyle(fontSize: 13,
                            color: ThemeConfig.getTextSecondaryColor(context)))
                  else
                    ..._history!.map((row) => _AttemptTile(row: row, fmtDate: _fmtDate)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kvRow(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(width: 90,
          child: Text(label, style: TextStyle(fontSize: 12,
              color: ThemeConfig.getTextSecondaryColor(context)))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ThemeConfig.getTextPrimaryColor(context)))),
    ]),
  );
}

class _AttemptTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final String Function(String?) fmtDate;
  const _AttemptTile({required this.row, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final status   = row['status']  as String? ?? '—';
    final method   = row['method']  as String? ?? '—';
    final verified = status == 'verified';
    final color    = verified ? Colors.green : Colors.red;

    String detail = '';
    if (method == 'near_owner') {
      final gps   = row['gps_score']   as int?;
      final photo = row['photo_score'] as int?;
      final total = row['total_score'] as int?;
      final dist  = (row['distance_meters'] as num?)?.toStringAsFixed(0);
      detail = 'Score: ${total ?? "??"}/100'
               '${dist != null ? "  •  ${dist}m away" : ""}'
               '${gps   != null ? "  •  GPS $gps/40" : ""}'
               '${photo != null ? "  •  Photo $photo/60" : ""}';
    } else if (method == 'far_owner') {
      final pct = (row['name_match_pct'] as num?)?.toStringAsFixed(1);
      final idN = row['id_name_extracted']   as String?;
      final htN = row['hati_name_extracted'] as String?;
      detail = 'Name match: ${pct ?? "?"}%'
               '${idN  != null && idN.isNotEmpty  ? "\n  ID: $idN"   : ""}'
               '${htN  != null && htN.isNotEmpty  ? "\n  Hati: $htN" : ""}';
    }

    final reason = row['rejection_reason'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(verified ? Icons.verified_user_rounded : Icons.cancel_outlined,
              size: 15, color: color),
          const SizedBox(width: 6),
          Text(verified ? 'Verified ✅' : 'Rejected ❌',
              style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 13, color: color)),
          const Spacer(),
          Text(_methodLabel(method),
              style: TextStyle(fontSize: 11,
                  color: ThemeConfig.getTextSecondaryColor(context))),
          const SizedBox(width: 8),
          Text(fmtDate(row['created_at'] as String?),
              style: TextStyle(fontSize: 11,
                  color: ThemeConfig.getTextSecondaryColor(context))),
        ]),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(detail, style: TextStyle(fontSize: 12,
              color: ThemeConfig.getTextSecondaryColor(context))),
        ],
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Reason: $reason', style: const TextStyle(
              fontSize: 12, color: Colors.red)),
        ],
      ]),
    );
  }

  String _methodLabel(String m) {
    if (m == 'near_owner') return 'Near Owner';
    if (m == 'far_owner')  return 'Far Owner';
    return m;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// MEDIA TILE
// ─────────────────────────────────────────────────────────────────────────

class _MediaItem {
  final String url;
  const _MediaItem({required this.url});
}

class _MediaTile extends StatelessWidget {
  final _MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _MediaTile({required this.item, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(children: [
          // Image thumbnail
          SizedBox.expand(
            child: Image.network(item.url,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2))),
                errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image_rounded,
                        color: Colors.grey))),
          ),
          // Delete button
          if (onDelete != null)
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded,
                      color: Colors.white, size: ResponsiveHelper.getResponsiveIconSize(context)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// FULLSCREEN MEDIA VIEW
// ─────────────────────────────────────────────────────────────────────────

class _FullscreenMediaView extends StatelessWidget {
  final _MediaItem item;
  const _FullscreenMediaView({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Photo', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            item.url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.broken_image, color: Colors.white70, size: ResponsiveHelper.getResponsiveIconSize(context)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// STATUS BANNER
// ─────────────────────────────────────────────────────────────────────────

String _fmtDate(String s) {
  try {
    return DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(s));
  } catch (_) {
    return s;
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? detail;
  final String? subDetail;
  final Color color;

  const _StatusBanner({
    required this.icon,
    required this.message,
    this.detail,
    this.subDetail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: ResponsiveHelper.getResponsiveIconSize(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            if (detail != null)
              Text('Reason: $detail',
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
            if (subDetail != null)
              Text(subDetail!,
                  style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}