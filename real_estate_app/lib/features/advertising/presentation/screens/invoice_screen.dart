// lib/features/advertising/presentation/screens/invoice_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/theme_config.dart';
import '../../../../core/services/direct_ad_models.dart';
import '../../../../core/utils/responsive_helper.dart';

class InvoiceScreen extends StatelessWidget {
  final AdCampaign campaign;
  final Advertiser advertiser;

  const InvoiceScreen({
    super.key,
    required this.campaign,
    required this.advertiser,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'TSh ', decimalDigits: 0);
    final dateFmt = DateFormat('dd MMM yyyy');
    final hPad = ResponsiveHelper.getContentHorizontalPadding(context);

    final unspent = (campaign.totalBudget - campaign.spentAmount)
        .clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Campaign Invoice'),
        backgroundColor: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightAppBarBackground,
          darkColor: ThemeConfig.darkAppBarBackground,
        ),
        foregroundColor: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightAppBarForeground,
          darkColor: ThemeConfig.darkAppBarForeground,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Invoice',
            onPressed: () => _shareInvoice(context, fmt, dateFmt, unspent),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Invoice header ────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ThemeConfig.getPrimaryColor(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('INVOICE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1.5)),
                          ),
                          const Spacer(),
                          Text(
                            'PataMjengo',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        campaign.campaignName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Campaign ID: ${campaign.id.substring(0, 8).toUpperCase()}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Advertiser info ────────────────────────────────────────
                _SectionCard(
                  title: 'Advertiser',
                  child: Column(
                    children: [
                      _InvoiceRow(label: 'Company', value: advertiser.companyName),
                      _InvoiceRow(label: 'Contact', value: advertiser.contactName),
                      _InvoiceRow(label: 'Email', value: advertiser.email),
                      _InvoiceRow(label: 'Phone', value: advertiser.phone),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Campaign period ────────────────────────────────────────
                _SectionCard(
                  title: 'Campaign Period',
                  child: Column(
                    children: [
                      _InvoiceRow(
                          label: 'Start Date',
                          value: dateFmt.format(campaign.startDate)),
                      _InvoiceRow(
                          label: 'End Date',
                          value: dateFmt.format(campaign.endDate)),
                      _InvoiceRow(
                          label: 'Duration',
                          value:
                              '${campaign.endDate.difference(campaign.startDate).inDays} days'),
                      _InvoiceRow(
                          label: 'Status',
                          value: campaign.status.toUpperCase()),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Performance ───────────────────────────────────────────
                _SectionCard(
                  title: 'Performance',
                  child: Column(
                    children: [
                      _InvoiceRow(
                          label: 'Impressions',
                          value: NumberFormat.compact()
                              .format(campaign.impressionsCount)),
                      _InvoiceRow(
                          label: 'Clicks',
                          value: NumberFormat.compact()
                              .format(campaign.clicksCount)),
                      _InvoiceRow(
                          label: 'CTR',
                          value: '${campaign.ctr.toStringAsFixed(2)}%'),
                      _InvoiceRow(
                          label: 'Avg. CPC',
                          value: campaign.clicksCount > 0
                              ? fmt.format(campaign.cpcActual)
                              : '—'),
                      _InvoiceRow(
                          label: 'Bidding',
                          value: campaign.biddingStrategy.toUpperCase()),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Billing summary ───────────────────────────────────────
                _SectionCard(
                  title: 'Billing Summary',
                  child: Column(
                    children: [
                      _InvoiceRow(
                          label: 'Total Budget',
                          value: fmt.format(campaign.totalBudget)),
                      _InvoiceRow(
                          label: 'Amount Spent',
                          value: fmt.format(campaign.spentAmount),
                          valueColor: ThemeConfig.errorColor),
                      if (unspent > 0)
                        _InvoiceRow(
                          label: 'Unused Budget',
                          value: fmt.format(unspent),
                          valueColor: Colors.orange,
                        ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Charged',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: ThemeConfig.getTextPrimaryColor(context),
                            ),
                          ),
                          Text(
                            fmt.format(campaign.spentAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: ThemeConfig.getPrimaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Footer note ───────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeConfig.getCardColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ThemeConfig.getColor(
                        context,
                        lightColor: ThemeConfig.lightBorder,
                        darkColor: ThemeConfig.darkBorder,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.verified_outlined,
                          color: ThemeConfig.getPrimaryColor(context), size: 28),
                      const SizedBox(height: 8),
                      Text(
                        'Generated by PataMjengo Advertising',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: ThemeConfig.getTextPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Invoice generated on ${dateFmt.format(DateTime.now())}',
                        style: TextStyle(
                          fontSize: 11,
                          color: ThemeConfig.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _shareInvoice(BuildContext context, NumberFormat fmt,
      DateFormat dateFmt, double unspent) {
    final text = '''
PATAMJENGO ADVERTISING — INVOICE

Campaign: ${campaign.campaignName}
ID: ${campaign.id.substring(0, 8).toUpperCase()}

ADVERTISER
Company: ${advertiser.companyName}
Contact: ${advertiser.contactName}
Email: ${advertiser.email}

CAMPAIGN PERIOD
Start: ${dateFmt.format(campaign.startDate)}
End: ${dateFmt.format(campaign.endDate)}
Status: ${campaign.status.toUpperCase()}

PERFORMANCE
Impressions: ${campaign.impressionsCount}
Clicks: ${campaign.clicksCount}
CTR: ${campaign.ctr.toStringAsFixed(2)}%

BILLING
Total Budget: ${fmt.format(campaign.totalBudget)}
Amount Spent: ${fmt.format(campaign.spentAmount)}
${unspent > 0 ? 'Unused Budget: ${fmt.format(unspent)}\n' : ''}Total Charged: ${fmt.format(campaign.spentAmount)}

Generated by PataMjengo — ${dateFmt.format(DateTime.now())}
''';
    Share.share(text, subject: 'Invoice — ${campaign.campaignName}');
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ThemeConfig.getCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightBorder,
            darkColor: ThemeConfig.darkBorder,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: ThemeConfig.getTextSecondaryColor(context),
              ),
            ),
          ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InvoiceRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: ThemeConfig.getTextSecondaryColor(context),
                fontSize: 13,
              )),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? ThemeConfig.getTextPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
