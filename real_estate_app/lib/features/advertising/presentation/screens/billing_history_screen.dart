// lib/features/advertising/presentation/screens/billing_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme_config.dart';
import '../../../../core/services/direct_ad_models.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../provider/ad_providers.dart';
import '../../../../core/utils/responsive_helper.dart';

class BillingHistoryScreen extends ConsumerStatefulWidget {
  final String advertiserId;

  const BillingHistoryScreen({
    super.key,
    required this.advertiserId,
  });

  @override
  ConsumerState<BillingHistoryScreen> createState() => _BillingHistoryScreenState();
}

class _BillingHistoryScreenState extends ConsumerState<BillingHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<AdvertiserPayment>> _paymentsFuture;
  late Future<List<RefundRequest>> _refundsFuture;
  String _filterStatus = 'all';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPayments();
    _loadRefunds();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadPayments() {
    setState(() {
      _paymentsFuture = ref
          .read(directAdServiceProvider)
          .getPaymentHistory(widget.advertiserId);
    });
  }

  void _loadRefunds() {
    setState(() {
      _refundsFuture = ref
          .read(directAdServiceProvider)
          .getRefundRequests(widget.advertiserId);
    });
  }

  List<AdvertiserPayment> _filterPayments(List<AdvertiserPayment> payments) {
    var filtered = payments;

    // Filter by status
    if (_filterStatus != 'all') {
      filtered = filtered.where((p) => p.status == _filterStatus).toList();
    }

    // Filter by date range
    if (_dateRange != null) {
      filtered = filtered.where((p) {
        return p.paymentDate.isAfter(_dateRange!.start) &&
               p.paymentDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThemeConfig.getPrimaryColor(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _filterStatus = 'all';
      _dateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Billing History',
          style: TextStyle(
            color: ThemeConfig.getColor(
              context,
              lightColor: ThemeConfig.lightAppBarForeground,
              darkColor: ThemeConfig.darkAppBarForeground,
            ),
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 20),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightAppBarBackground,
          darkColor: ThemeConfig.darkAppBarBackground,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list_rounded,
              color: ThemeConfig.getColor(
                context,
                lightColor: ThemeConfig.lightAppBarForeground,
                darkColor: ThemeConfig.darkAppBarForeground,
              ),
            ),
            onPressed: _showFilterSheet,
            tooltip: 'Filter',
          ),
          if (_filterStatus != 'all' || _dateRange != null)
            IconButton(
              icon: Icon(
                Icons.clear_rounded,
                color: ThemeConfig.getColor(
                  context,
                  lightColor: ThemeConfig.lightAppBarForeground,
                  darkColor: ThemeConfig.darkAppBarForeground,
                ),
              ),
              onPressed: _clearFilters,
              tooltip: 'Clear Filters',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightAppBarForeground,
            darkColor: ThemeConfig.darkAppBarForeground,
          ),
          unselectedLabelColor: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightAppBarForeground,
            darkColor: ThemeConfig.darkAppBarForeground,
          ).withOpacity(0.6),
          indicatorColor: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightAppBarForeground,
            darkColor: ThemeConfig.darkAppBarForeground,
          ),
          tabs: const [
            Tab(text: 'Payments'),
            Tab(text: 'Refunds'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPaymentsTab(),
          _buildRefundsTab(),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    return FutureBuilder<List<AdvertiserPayment>>(
        future: _paymentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading payment history...');
          }

          if (snapshot.hasError) {
            return CustomErrorWidget(
              message: 'Failed to load payment history',
              onRetry: _loadPayments,
            );
          }

          final allPayments = snapshot.data ?? [];
          final filteredPayments = _filterPayments(allPayments);

          if (allPayments.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Payments Yet',
              message: 'Your payment history will appear here once you add funds to your account.',
              actionText: null,
              onActionPressed: null,
            );
          }

          if (filteredPayments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: ThemeConfig.getTextSecondaryColor(context),
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                  Text(
                    'No payments match your filters',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                      color: ThemeConfig.getTextSecondaryColor(context),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                  ElevatedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all_rounded),
                    label: const Text('Clear Filters'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.getPrimaryColor(context),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Summary Card
              _buildSummaryCard(allPayments),

              // Payment List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _loadPayments(),
                  color: ThemeConfig.getPrimaryColor(context),
                  child: ListView.builder(
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                    itemCount: filteredPayments.length,
                    itemBuilder: (context, index) {
                      return _buildPaymentCard(filteredPayments[index]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      );
  }

  // ── Refunds tab ────────────────────────────────────────────────────────────
  Widget _buildRefundsTab() {
    return FutureBuilder<List<RefundRequest>>(
      future: _refundsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Loading refunds...');
        }
        if (snapshot.hasError) {
          return CustomErrorWidget(
            message: 'Failed to load refunds',
            onRetry: _loadRefunds,
          );
        }
        final refunds = snapshot.data ?? [];
        if (refunds.isEmpty) {
          return const EmptyState(
            icon: Icons.undo_rounded,
            title: 'No Refunds',
            message: 'You have not requested any refunds yet. You can request a refund from a campaign\'s detail screen.',
            actionText: null,
            onActionPressed: null,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _loadRefunds(),
          color: ThemeConfig.getPrimaryColor(context),
          child: ListView.builder(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
            itemCount: refunds.length,
            itemBuilder: (context, index) => _buildRefundCard(refunds[index]),
          ),
        );
      },
    );
  }

  Widget _buildRefundCard(RefundRequest refund) {
    final fmt = NumberFormat.currency(symbol: 'TSh ', decimalDigits: 0);
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    switch (refund.status) {
      case 'paid':
        statusColor = ThemeConfig.successColor;
        statusIcon = Icons.check_circle_rounded;
        statusText = 'Paid';
        break;
      case 'approved':
        statusColor = ThemeConfig.infoColor;
        statusIcon = Icons.thumb_up_rounded;
        statusText = 'Approved';
        break;
      case 'rejected':
        statusColor = ThemeConfig.errorColor;
        statusIcon = Icons.cancel_rounded;
        statusText = 'Rejected';
        break;
      default: // pending
        statusColor = ThemeConfig.warningColor;
        statusIcon = Icons.schedule_rounded;
        statusText = 'Pending';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightBorder,
            darkColor: ThemeConfig.darkBorder,
          ),
        ),
      ),
      color: ThemeConfig.getCardColor(context),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmt.format(refund.amount),
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context, mobile: 18),
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.getTextPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ThemeConfig.getTextSecondaryColor(context)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            refund.isBalance ? 'Wallet Credit' : 'Cash (Mobile Money)',
                            style: TextStyle(
                              fontSize: 11,
                              color: ThemeConfig.getTextSecondaryColor(context),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1,
              color: ThemeConfig.getColor(context,
                  lightColor: ThemeConfig.lightDivider,
                  darkColor: ThemeConfig.darkDivider)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 13,
                    color: ThemeConfig.getTextSecondaryColor(context)),
                const SizedBox(width: 5),
                Text(
                  'Requested: ${_formatDate(refund.requestedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeConfig.getTextSecondaryColor(context),
                  ),
                ),
                if (refund.processedAt != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.done_all_rounded,
                      size: 13, color: ThemeConfig.successColor),
                  const SizedBox(width: 5),
                  Text(
                    'Processed: ${_formatDate(refund.processedAt!)}',
                    style: const TextStyle(fontSize: 12, color: ThemeConfig.successColor),
                  ),
                ],
              ],
            ),
            if (refund.reason != null && refund.reason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Reason: ${refund.reason}',
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeConfig.getTextSecondaryColor(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (refund.adminNotes != null && refund.adminNotes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeConfig.infoColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Note: ${refund.adminNotes}',
                  style: const TextStyle(
                      fontSize: 12, color: ThemeConfig.infoColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(List<AdvertiserPayment> payments) {
    final completedPayments = payments.where((p) => p.isCompleted).toList();
    final totalAmount = completedPayments.fold<double>(
      0.0,
      (sum, payment) => sum + payment.amount,
    );
    final currency = payments.isNotEmpty ? payments.first.currency : 'TZS';

    return Container(
      margin: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThemeConfig.getPrimaryColor(context),
            ThemeConfig.getPrimaryColor(context).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ThemeConfig.getPrimaryColor(context).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              Expanded(
                child: Text(
                  'Total Funded',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${completedPayments.length} payments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
          Text(
            _formatCurrency(totalAmount, currency),
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 32),
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last payment: ${completedPayments.isNotEmpty ? _formatDate(completedPayments.first.paymentDate) : 'N/A'}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(AdvertiserPayment payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightBorder,
            darkColor: ThemeConfig.darkBorder,
          ),
          width: 1,
        ),
      ),
      color: ThemeConfig.getCardColor(context),
      child: InkWell(
        onTap: () => _showPaymentDetails(payment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status Icon
                  Container(
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
                    decoration: BoxDecoration(
                      color: _getStatusColor(payment.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(payment.status),
                      color: _getStatusColor(payment.status),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),

                  // Amount and Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCurrency(payment.amount, payment.currency),
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                            fontWeight: FontWeight.bold,
                            color: ThemeConfig.getTextPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(payment.status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getStatusText(payment.status),
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(payment.status),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: ThemeConfig.getTextSecondaryColor(context),
                  ),
                ],
              ),

              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              Divider(
                height: 1,
                color: ThemeConfig.getColor(
                  context,
                  lightColor: ThemeConfig.lightDivider,
                  darkColor: ThemeConfig.darkDivider,
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),

              // Payment Details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      icon: Icons.payment_rounded,
                      label: 'Method',
                      value: _formatPaymentMethod(payment.paymentMethod),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: ThemeConfig.getColor(
                      context,
                      lightColor: ThemeConfig.lightDivider,
                      darkColor: ThemeConfig.darkDivider,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: _formatDate(payment.paymentDate),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: ThemeConfig.getTextSecondaryColor(context),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
              color: ThemeConfig.getTextSecondaryColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
              fontWeight: FontWeight.w600,
              color: ThemeConfig.getTextPrimaryColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeConfig.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Filter Payments',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 20),
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.getTextPrimaryColor(context),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: ThemeConfig.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                  // Status Filter
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                      fontWeight: FontWeight.w600,
                      color: ThemeConfig.getTextPrimaryColor(context),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('All', 'all', setModalState),
                      _buildFilterChip('Completed', 'completed', setModalState),
                      _buildFilterChip('Pending', 'pending', setModalState),
                      _buildFilterChip('Failed', 'failed', setModalState),
                    ],
                  ),

                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                  // Date Range
                  Text(
                    'Date Range',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                      fontWeight: FontWeight.w600,
                      color: ThemeConfig.getTextPrimaryColor(context),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _selectDateRange();
                    },
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text(
                      _dateRange == null
                          ? 'Select Date Range'
                          : '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: BorderSide(
                        color: ThemeConfig.getColor(
                          context,
                          lightColor: ThemeConfig.lightInputBorder,
                          darkColor: ThemeConfig.darkInputBorder,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.getPrimaryColor(context),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, StateSetter setModalState) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          _filterStatus = value;
        });
        setState(() {});
      },
      selectedColor: ThemeConfig.getPrimaryColor(context).withOpacity(0.2),
      checkmarkColor: ThemeConfig.getPrimaryColor(context),
      labelStyle: TextStyle(
        color: isSelected
            ? ThemeConfig.getPrimaryColor(context)
            : ThemeConfig.getTextSecondaryColor(context),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  void _showPaymentDetails(AdvertiserPayment payment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeConfig.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                    decoration: BoxDecoration(
                      color: _getStatusColor(payment.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(payment.status),
                      color: _getStatusColor(payment.status),
                      size: 28,
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Details',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 20),
                            fontWeight: FontWeight.bold,
                            color: ThemeConfig.getTextPrimaryColor(context),
                          ),
                        ),
                        Text(
                          _formatCurrency(payment.amount, payment.currency),
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 24),
                            fontWeight: FontWeight.bold,
                            color: ThemeConfig.getPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

              _buildDetailRow('Transaction ID', payment.transactionId),
              _buildDetailRow('Payment Method', _formatPaymentMethod(payment.paymentMethod)),
              _buildDetailRow('Status', _getStatusText(payment.status)),
              _buildDetailRow('Date', _formatDateTime(payment.paymentDate)),
              if (payment.completedAt != null)
                _buildDetailRow('Completed', _formatDateTime(payment.completedAt!)),
              if (payment.paymentProvider != null)
                _buildDetailRow('Provider', payment.paymentProvider!),
              if (payment.providerReference != null)
                _buildDetailRow('Reference', payment.providerReference!),

              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: ThemeConfig.getColor(
                        context,
                        lightColor: ThemeConfig.lightInputBorder,
                        darkColor: ThemeConfig.darkInputBorder,
                      ),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                color: ThemeConfig.getTextSecondaryColor(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                fontWeight: FontWeight.w600,
                color: ThemeConfig.getTextPrimaryColor(context),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return ThemeConfig.successColor;
      case 'pending':
        return ThemeConfig.warningColor;
      case 'failed':
        return ThemeConfig.errorColor;
      default:
        return ThemeConfig.infoColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'failed':
        return Icons.error_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getStatusText(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }

  String _formatPaymentMethod(String method) {
    return method.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _formatCurrency(double amount, String currency) {
    final formatter = NumberFormat.currency(
      symbol: currency == 'TZS' ? 'TSh ' : '\$ ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  }

}