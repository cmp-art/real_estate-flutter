// lib/features/advertising/presentation/screens/create_campaign_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme_config.dart';
import '../../../../core/algorithm/ad_display_algorithm.dart';

import '../../../../core/services/direct_ad_models.dart';
import '../provider/ad_providers.dart';
import 'add_funds_screen.dart';
import '../../../../core/utils/responsive_helper.dart';

class CreateCampaignScreen extends ConsumerStatefulWidget {
  final String advertiserId;
  final double currentBalance;
  final Advertiser advertiser;

  const CreateCampaignScreen({
    super.key,
    required this.advertiserId,
    required this.currentBalance,
    required this.advertiser,
  });

  @override
  ConsumerState<CreateCampaignScreen> createState() =>
      _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends ConsumerState<CreateCampaignScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Step controller
  int _currentStep = 0;
  bool _isCreating = false;

  // Step 1 – Campaign details
  final _nameController = TextEditingController();
  String _objective = 'brand_awareness';

  // Step 2 – Budget & bidding
  final _dailyBudgetController = TextEditingController();
  final _totalBudgetController = TextEditingController();
  String _biddingStrategy = 'cpm';
  double _bidAmount = 500.0; // TSh 500 CPM default (launch phase)
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  // Step 3 – Targeting
  final List<String> _selectedPropertyTypes = [];
  final List<String> _selectedLocations = [];
  bool _targetWholeCountry = true; // default: target all of Tanzania

  // Revenue estimate
  AdRevenueEstimate? _estimate;

  // Insufficient-funds overlay
  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;
  int _overlayCountdown = 5;

  // ── formatters ──────────────────────────────────────────────────────────

  final _currencyFmt =
      NumberFormat.currency(symbol: 'TSh ', decimalDigits: 0);

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _nameController.dispose();
    _dailyBudgetController.dispose();
    _totalBudgetController.dispose();
    _overlayTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  void _recalcEstimate() {
    final total = double.tryParse(_totalBudgetController.text) ?? 0;
    if (total <= 0) return;
    final algo = ref.read(directAdAlgorithmProvider);
    setState(() {
      _estimate = algo.estimateCampaignRevenue(
        totalBudget: total,
        bidAmount: _bidAmount,
        biddingStrategy: _biddingStrategy,
        estimatedDays: _endDate.difference(_startDate).inDays.clamp(1, 999),
      );
    });
  }

  bool get _hasEnoughFunds {
    final total = double.tryParse(_totalBudgetController.text) ?? 0;
    return widget.currentBalance >= total && total > 0;
  }

  double get _deficit {
    final total = double.tryParse(_totalBudgetController.text) ?? 0;
    return (total - widget.currentBalance).clamp(0, double.infinity);
  }

  // ── insufficient-funds 5-second overlay ─────────────────────────────────

  void _showInsufficientFundsOverlay() {
    _overlayCountdown = 5;
    _overlayEntry?.remove();
    _overlayEntry = null;

    _overlayEntry = OverlayEntry(
      builder: (_) => _InsufficientFundsOverlay(
        balance: widget.currentBalance,
        required: double.tryParse(_totalBudgetController.text) ?? 0,
        deficit: _deficit,
        countdown: _overlayCountdown,
        onAddFunds: () {
          _dismissOverlay();
          _navigateToAddFunds();
        },
        onDismiss: _dismissOverlay,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    // Tick every second and auto-dismiss at 0
    _overlayTimer?.cancel();
    _overlayTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _overlayCountdown--;
      // Rebuild the overlay with new countdown
      _overlayEntry?.markNeedsBuild();
      if (_overlayCountdown <= 0) {
        t.cancel();
        _dismissOverlay();
      }
    });
  }

  void _dismissOverlay() {
    _overlayTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {});
  }

  // ── navigation ───────────────────────────────────────────────────────────

  Future<void> _navigateToAddFunds() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFundsScreen(advertiser: widget.advertiser),
      ),
    );
    if (result == true && mounted) {
      // After adding funds, retry campaign creation
      await _createCampaign();
    }
  }

  // ── step validation ───────────────────────────────────────────────────────

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          _snackError('Please enter a campaign name.');
          return false;
        }
        return true;
      case 1:
        final daily = double.tryParse(_dailyBudgetController.text) ?? 0;
        final total = double.tryParse(_totalBudgetController.text) ?? 0;
        if (daily < 2000) {
          _snackError('Minimum daily budget is TSh 2,000.');
          return false;
        }
        if (total < 5000) {
          _snackError('Minimum total budget is TSh 5,000.');
          return false;
        }
        if (daily > total) {
          _snackError('Daily budget cannot exceed total budget.');
          return false;
        }
        return true;
      case 2:
        // Targeting step: if specific regions mode, must pick at least one
        if (!_targetWholeCountry && _selectedLocations.isEmpty) {
          _snackError(
              'Please select at least one region, or choose "Whole Tanzania".');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _onContinue() {
    if (!_validateCurrentStep()) return;
    if (_currentStep == 1) _recalcEstimate();
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _checkFundsAndCreate();
    }
  }

  void _onBack() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // ── funds check + create ─────────────────────────────────────────────────

  Future<void> _checkFundsAndCreate() async {
    if (!_hasEnoughFunds) {
      _showInsufficientFundsOverlay();
      return;
    }
    await _createCampaign();
  }

  Future<void> _createCampaign() async {
    setState(() => _isCreating = true);
    try {
      final svc = ref.read(directAdServiceProvider);
      final campaign = await svc.createCampaign(
        advertiserId: widget.advertiserId,
        campaignName: _nameController.text.trim(),
        campaignObjective: _objective,
        dailyBudget: double.parse(_dailyBudgetController.text),
        totalBudget: double.parse(_totalBudgetController.text),
        bidAmount: _bidAmount,
        biddingStrategy: _biddingStrategy,
        startDate: _startDate,
        endDate: _endDate,
        targetPropertyTypes: _selectedPropertyTypes,
        targetLocations: _targetWholeCountry ? [] : _selectedLocations,
      );

      if (!mounted) return;
      if (campaign != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Campaign created! Now add your ad creative.'),
            ]),
            backgroundColor: ThemeConfig.successColor,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, campaign);
      } else {
        _snackError('Failed to create campaign. Please try again.');
      }
    } catch (e) {
      if (mounted) _snackError('Error: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _snackError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ThemeConfig.errorColor,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightAppBarBackground,
          darkColor: ThemeConfig.darkAppBarBackground,
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: ThemeConfig.getColor(
                context,
                lightColor: ThemeConfig.lightAppBarForeground,
                darkColor: ThemeConfig.darkAppBarForeground,
              )),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Campaign',
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
        // Balance chip in app bar
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: ResponsiveHelper.getResponsiveIconSize(context)),
                    const SizedBox(width: 6),
                    Text(
                      _currencyFmt.format(widget.currentBalance),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Step progress indicator
          _buildStepIndicator(),

          // Step content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStep(),
              ),
            ),
          ),

          // Bottom navigation bar
          _buildBottomNav(),
        ],
      ),
    );
  }

  // ── step indicator ────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    final steps = ['Details', 'Budget', 'Targeting', 'Review'];
    return Container(
      color: ThemeConfig.getCardColor(context),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // connector line
            final stepIndex = i ~/ 2;
            final done = _currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: done
                    ? ThemeConfig.getPrimaryColor(context)
                    : ThemeConfig.getColor(
                        context,
                        lightColor: ThemeConfig.lightBorder,
                        darkColor: ThemeConfig.darkBorder,
                      ),
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final isActive = _currentStep == stepIndex;
          final isDone = _currentStep > stepIndex;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone || isActive
                      ? ThemeConfig.getPrimaryColor(context)
                      : ThemeConfig.getColor(
                          context,
                          lightColor: ThemeConfig.lightInputFill,
                          darkColor: ThemeConfig.darkInputFill,
                        ),
                  border: Border.all(
                    color: isDone || isActive
                        ? ThemeConfig.getPrimaryColor(context)
                        : ThemeConfig.getColor(
                            context,
                            lightColor: ThemeConfig.lightBorder,
                            darkColor: ThemeConfig.darkBorder,
                          ),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check_rounded,
                          color: Colors.white, size: ResponsiveHelper.getResponsiveIconSize(context))
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? Colors.white
                                : ThemeConfig.getTextSecondaryColor(context),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                steps[stepIndex],
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive
                      ? ThemeConfig.getPrimaryColor(context)
                      : ThemeConfig.getTextSecondaryColor(context),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── current step dispatcher ───────────────────────────────────────────────

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Details();
      case 1:
        return _buildStep2Budget();
      case 2:
        return _buildStep3Targeting();
      case 3:
        return _buildStep4Review();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── STEP 1: Campaign details ──────────────────────────────────────────────

  Widget _buildStep1Details() {
    final objectives = [
      ('brand_awareness', Icons.visibility_rounded, 'Brand Awareness',
          'Get your listings seen — includes property inquiries, website and WhatsApp visits'),
    ];

    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Campaign Name'),
        const SizedBox(height: 10),
        TextFormField(
          controller: _nameController,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
          decoration: _inputDeco(
            hint: 'e.g. Dar es Salaam Luxury Apartments',
            icon: Icons.campaign_rounded,
          ),
          maxLength: 60,
        ),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
        _sectionTitle('Campaign Objective'),
        const SizedBox(height: 10),
        ...objectives.map((o) {
          final selected = _objective == o.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ObjectiveCard(
              icon: o.$2,
              title: o.$3,
              subtitle: o.$4,
              isSelected: selected,
              onTap: () => setState(() => _objective = o.$1),
            ),
          );
        }),
      ],
    );
  }

  // ── STEP 2: Budget & bidding ──────────────────────────────────────────────

  Widget _buildStep2Budget() {
    final quickAmounts = [10000.0, 25000.0, 50000.0, 100000.0, 250000.0];

    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Balance card
        _buildBalanceBanner(),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

        _sectionTitle('Daily Budget (TSh)'),
        const SizedBox(height: 6),
        Text(
          'Minimum: TSh 2,000/day — controls how fast your budget is spent',
          style: TextStyle(fontSize: 12, color: ThemeConfig.getTextSecondaryColor(context)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dailyBudgetController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
          decoration: _inputDeco(
              hint: 'e.g. 5,000', icon: Icons.calendar_today_rounded),
          onChanged: (_) => _recalcEstimate(),
        ),
        const SizedBox(height: 20),

        _sectionTitle('Total Campaign Budget (TSh)'),
        const SizedBox(height: 6),
        Text(
          'Minimum: TSh 5,000 — your ad stops when this is used up',
          style: TextStyle(fontSize: 12, color: ThemeConfig.getTextSecondaryColor(context)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _totalBudgetController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
          decoration:
              _inputDeco(hint: 'e.g. 50,000', icon: Icons.savings_rounded),
          onChanged: (_) => _recalcEstimate(),
        ),

        // Quick-select amounts
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        Wrap(
          spacing: 8,
          children: quickAmounts.map((amt) {
            return ActionChip(
              label: Text(_currencyFmt.format(amt)),
              onPressed: () {
                _totalBudgetController.text = amt.toStringAsFixed(0);
                if (_dailyBudgetController.text.isEmpty) {
                  _dailyBudgetController.text =
                      (amt / 30).toStringAsFixed(0);
                }
                _recalcEstimate();
              },
              backgroundColor:
                  ThemeConfig.getPrimaryColor(context).withOpacity(0.1),
              labelStyle: TextStyle(
                color: ThemeConfig.getPrimaryColor(context),
                fontWeight: FontWeight.w600,
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

        // Bidding strategy
        _sectionTitle('Bidding Strategy'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _BidCard(
                label: 'CPM',
                description: 'Pay per 1,000 views\nMin: TSh 500',
                icon: Icons.visibility_rounded,
                isSelected: _biddingStrategy == 'cpm',
                onTap: () {
                  setState(() {
                    _biddingStrategy = 'cpm';
                    _bidAmount = 500;
                  });
                  _recalcEstimate();
                },
              ),
            ),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Expanded(
              child: _BidCard(
                label: 'CPC',
                description: 'Pay per click\nMin: TSh 50',
                icon: Icons.touch_app_rounded,
                isSelected: _biddingStrategy == 'cpc',
                onTap: () {
                  setState(() {
                    _biddingStrategy = 'cpc';
                    _bidAmount = 50;
                  });
                  _recalcEstimate();
                },
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
        // Bid label row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _biddingStrategy == 'cpm' ? 'Per 1,000 views' : 'Per click',
              style: TextStyle(color: ThemeConfig.getTextSecondaryColor(context), fontSize: 12),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ThemeConfig.getPrimaryColor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currencyFmt.format(_bidAmount)} / ${_biddingStrategy == "cpm" ? "1K views" : "click"}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        Slider(
          value: _bidAmount,
          min: _biddingStrategy == 'cpm' ? 500 : 50,
          max: _biddingStrategy == 'cpm' ? 3000 : 500,
          divisions: _biddingStrategy == 'cpm' ? 25 : 45,
          activeColor: ThemeConfig.getPrimaryColor(context),
          inactiveColor: ThemeConfig.getPrimaryColor(context).withOpacity(0.2),
          onChanged: (v) {
            setState(() => _bidAmount = v);
            _recalcEstimate();
          },
        ),
        // Live impact preview — always visible, uses actual budget or TSh 50,000 example
        _buildBidImpactPreview(),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

        // Dates
        _sectionTitle('Campaign Schedule'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: 'Start Date',
                date: _startDate,
                onPick: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: ColorScheme.light(
                            primary: ThemeConfig.getPrimaryColor(context)),
                      ),
                      child: child!,
                    ),
                  );
                  if (d != null) setState(() => _startDate = d);
                },
              ),
            ),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Expanded(
              child: _DateField(
                label: 'End Date',
                date: _endDate,
                onPick: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: _startDate.add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: ColorScheme.light(
                            primary: ThemeConfig.getPrimaryColor(context)),
                      ),
                      child: child!,
                    ),
                  );
                  if (d != null) setState(() => _endDate = d);
                },
              ),
            ),
          ],
        ),

      ],
    );
  }

  /// Live impact preview shown directly below the bid slider.
  /// Uses the actual total budget if entered, otherwise shows a TSh 50,000 example.
  Widget _buildBidImpactPreview() {
    final enteredBudget = double.tryParse(_totalBudgetController.text) ?? 0;
    final previewBudget = enteredBudget > 0 ? enteredBudget : 50000.0;
    final isExample    = enteredBudget <= 0;
    final days = _endDate.difference(_startDate).inDays.clamp(1, 999);

    final algo = ref.read(directAdAlgorithmProvider);
    final est  = algo.estimateCampaignRevenue(
      totalBudget: previewBudget,
      bidAmount: _bidAmount,
      biddingStrategy: _biddingStrategy,
      estimatedDays: days,
    );

    final impressionsFmt = NumberFormat.compact().format(est.estimatedImpressions);
    final clicksFmt      = NumberFormat.compact().format(est.estimatedClicks);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ThemeConfig.getPrimaryColor(context).withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ThemeConfig.getPrimaryColor(context).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph_rounded, size: 15, color: ThemeConfig.getPrimaryColor(context)),
              const SizedBox(width: 6),
              Text(
                isExample
                    ? 'Example with TSh 50,000 budget'
                    : 'Estimated results for your budget',
                style: TextStyle(
                  fontSize: 11,
                  color: ThemeConfig.getTextSecondaryColor(context),
                  fontStyle: isExample ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _impactStat(impressionsFmt, 'Views'),
              _impactStat(clicksFmt, 'Clicks'),
              _impactStat('${est.ctr.toStringAsFixed(1)}%', 'CTR'),
              _impactStat('${days}d', 'Duration'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Higher bid → wins more auctions → more people see your ad',
            style: TextStyle(fontSize: 10, color: ThemeConfig.getTextSecondaryColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _impactStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ThemeConfig.getPrimaryColor(context))),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: ThemeConfig.getTextSecondaryColor(context))),
      ],
    );
  }

  Widget _buildBalanceBanner() {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThemeConfig.getPrimaryColor(context),
            ThemeConfig.getPrimaryColor(context).withOpacity(0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white, size: ResponsiveHelper.getResponsiveIconSize(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  _currencyFmt.format(widget.currentBalance),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 22),
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateCard() {
    final e = _estimate!;
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: ThemeConfig.infoColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeConfig.infoColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph_rounded,
                  color: ThemeConfig.infoColor, size: ResponsiveHelper.getResponsiveIconSize(context)),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
              Text('Estimated Results',
                  style: TextStyle(
                      color: ThemeConfig.getTextPrimaryColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _estimateStat(
                  NumberFormat.compact().format(e.estimatedImpressions),
                  'Impressions'),
              _estimateStat(
                  NumberFormat.compact().format(e.estimatedClicks),
                  'Clicks'),
              _estimateStat('${e.ctr.toStringAsFixed(1)}%', 'CTR'),
              _estimateStat(
                  '${e.estimatedDuration}d', 'Duration'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _estimateStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                fontWeight: FontWeight.bold,
                color: ThemeConfig.getTextPrimaryColor(context))),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                color: ThemeConfig.getTextSecondaryColor(context))),
      ],
    );
  }

  // ── STEP 3: Targeting ─────────────────────────────────────────────────────

  Widget _buildStep3Targeting() {
    final propertyTypes = [
      ('apartment', 'Apartment'),
      ('house', 'House'),
      ('land', 'Land'),
      ('commercial', 'Commercial'),
      ('villa', 'Villa'),
      ('office', 'Office'),
    ];

    // All 31 Tanzania regions (mainland + Zanzibar islands)
    const tanzaniaRegions = [
      'Arusha',
      'Dar es Salaam',
      'Dodoma',
      'Geita',
      'Iringa',
      'Kagera',
      'Katavi',
      'Kigoma',
      'Kilimanjaro',
      'Lindi',
      'Manyara',
      'Mara',
      'Mbeya',
      'Morogoro',
      'Mtwara',
      'Mwanza',
      'Njombe',
      'Pwani',        // Coast Region
      'Rukwa',
      'Ruvuma',
      'Shinyanga',
      'Simiyu',
      'Singida',
      'Songwe',
      'Tabora',
      'Tanga',
      'Kaskazini Unguja',   // Zanzibar North
      'Kusini Unguja',      // Zanzibar South
      'Mjini Magharibi',    // Zanzibar Urban/West
      'Kaskazini Pemba',    // Pemba North
      'Kusini Pemba',       // Pemba South
    ];

    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Target Property Types'),
        const SizedBox(height: 6),
        Text('Select all that apply (or leave blank for all)',
            style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                color: ThemeConfig.getTextSecondaryColor(context))),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: propertyTypes.map((pt) {
            final sel = _selectedPropertyTypes.contains(pt.$1);
            return FilterChip(
              label: Text(pt.$2),
              selected: sel,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _selectedPropertyTypes.add(pt.$1);
                  } else {
                    _selectedPropertyTypes.remove(pt.$1);
                  }
                });
              },
              selectedColor:
                  ThemeConfig.getPrimaryColor(context).withOpacity(0.15),
              checkmarkColor: ThemeConfig.getPrimaryColor(context),
              labelStyle: TextStyle(
                color: sel
                    ? ThemeConfig.getPrimaryColor(context)
                    : ThemeConfig.getTextPrimaryColor(context),
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),

        // ── Geographic targeting ───────────────────────────────────────────
        _sectionTitle('Geographic Targeting'),
        const SizedBox(height: 6),
        Text(
          'Choose your coverage area across Tanzania.',
          style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
              color: ThemeConfig.getTextSecondaryColor(context)),
        ),
        const SizedBox(height: 14),

        // Whole Tanzania toggle
        GestureDetector(
          onTap: () => setState(() {
            _targetWholeCountry = true;
            _selectedLocations.clear();
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _targetWholeCountry
                  ? ThemeConfig.getPrimaryColor(context).withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _targetWholeCountry
                    ? ThemeConfig.getPrimaryColor(context)
                    : ThemeConfig.getTextSecondaryColor(context)
                        .withOpacity(0.3),
                width: _targetWholeCountry ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  color: _targetWholeCountry
                      ? ThemeConfig.getPrimaryColor(context)
                      : ThemeConfig.getTextSecondaryColor(context),
                  size: 22,
                ),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Whole Tanzania',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                          color: _targetWholeCountry
                              ? ThemeConfig.getPrimaryColor(context)
                              : ThemeConfig.getTextPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Show your ad to users in all 31 regions',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                          color: ThemeConfig.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_targetWholeCountry)
                  Icon(Icons.check_circle_rounded,
                      color: ThemeConfig.getPrimaryColor(context), size: ResponsiveHelper.getResponsiveIconSize(context)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Specific regions toggle
        GestureDetector(
          onTap: () => setState(() {
            _targetWholeCountry = false;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: !_targetWholeCountry
                  ? ThemeConfig.getPrimaryColor(context).withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: !_targetWholeCountry
                    ? ThemeConfig.getPrimaryColor(context)
                    : ThemeConfig.getTextSecondaryColor(context)
                        .withOpacity(0.3),
                width: !_targetWholeCountry ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pin_drop_rounded,
                  color: !_targetWholeCountry
                      ? ThemeConfig.getPrimaryColor(context)
                      : ThemeConfig.getTextSecondaryColor(context),
                  size: 22,
                ),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Specific Regions',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                          color: !_targetWholeCountry
                              ? ThemeConfig.getPrimaryColor(context)
                              : ThemeConfig.getTextPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !_targetWholeCountry && _selectedLocations.isNotEmpty
                            ? '${_selectedLocations.length} region${_selectedLocations.length == 1 ? '' : 's'} selected'
                            : 'Select one or more regions below',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                          color: ThemeConfig.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_targetWholeCountry)
                  Icon(Icons.check_circle_rounded,
                      color: ThemeConfig.getPrimaryColor(context), size: ResponsiveHelper.getResponsiveIconSize(context)),
              ],
            ),
          ),
        ),

        // Region chips — only shown when specific regions mode is active
        if (!_targetWholeCountry) ...[
          const SizedBox(height: 14),
          Text(
            'Select regions (tap to toggle):',
            style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                fontWeight: FontWeight.w600,
                color: ThemeConfig.getTextSecondaryColor(context)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tanzaniaRegions.map((region) {
              final sel = _selectedLocations.contains(region);
              return FilterChip(
                label: Text(region),
                selected: sel,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedLocations.add(region);
                    } else {
                      _selectedLocations.remove(region);
                    }
                  });
                },
                selectedColor:
                    ThemeConfig.getPrimaryColor(context).withOpacity(0.15),
                checkmarkColor: ThemeConfig.getPrimaryColor(context),
                labelStyle: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: sel
                      ? ThemeConfig.getPrimaryColor(context)
                      : ThemeConfig.getTextPrimaryColor(context),
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          if (_selectedLocations.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '⚠ No regions selected — please select at least one.',
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                    color: ThemeConfig.errorColor,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ],
    );
  }

  // ── STEP 4: Review ────────────────────────────────────────────────────────

  Widget _buildStep4Review() {
    final total = double.tryParse(_totalBudgetController.text) ?? 0;
    final daily = double.tryParse(_dailyBudgetController.text) ?? 0;
    final enoughFunds = widget.currentBalance >= total;

    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Review Your Campaign'),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

        // Summary card
        _ReviewCard(children: [
          _reviewRow('Campaign Name', _nameController.text.trim()),
          _reviewRow('Objective', _formatObjective(_objective)),
          _reviewRow('Daily Budget', _currencyFmt.format(daily)),
          _reviewRow('Total Budget', _currencyFmt.format(total)),
          _reviewRow('Bidding', '${_biddingStrategy.toUpperCase()} – ${_currencyFmt.format(_bidAmount)}'),
          _reviewRow('Start', DateFormat('MMM d, yyyy').format(_startDate)),
          _reviewRow('End', DateFormat('MMM d, yyyy').format(_endDate)),
          _reviewRow('Duration',
              '${_endDate.difference(_startDate).inDays} days'),
          if (_selectedPropertyTypes.isNotEmpty)
            _reviewRow('Property Types', _selectedPropertyTypes.join(', ')),
          _reviewRow(
            'Locations',
            _targetWholeCountry
                ? 'Whole Tanzania (all 31 regions)'
                : _selectedLocations.isEmpty
                    ? 'Not set'
                    : _selectedLocations.join(', '),
          ),
        ]),

        const SizedBox(height: 20),

        // Fund status
        _buildFundStatus(total, enoughFunds),

        if (_estimate != null) ...[
          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
          _buildEstimateCard(),
        ],
      ],
    );
  }

  Widget _buildFundStatus(double total, bool enough) {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: (enough ? ThemeConfig.successColor : ThemeConfig.errorColor)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (enough ? ThemeConfig.successColor : ThemeConfig.errorColor)
              .withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            enough
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: enough
                ? ThemeConfig.successColor
                : ThemeConfig.errorColor,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enough ? 'Sufficient Funds' : 'Insufficient Funds',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
                    color: enough
                        ? ThemeConfig.successColor
                        : ThemeConfig.errorColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enough
                      ? 'Balance: ${_currencyFmt.format(widget.currentBalance)} ✓ Ready to launch'
                      : 'Need ${_currencyFmt.format(_deficit)} more — you\'ll be prompted to add funds.',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                    color: ThemeConfig.getTextSecondaryColor(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                    color: ThemeConfig.getTextSecondaryColor(context))),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                    fontWeight: FontWeight.w600,
                    color: ThemeConfig.getTextPrimaryColor(context))),
          ),
        ],
      ),
    );
  }

  // ── bottom nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final isLastStep = _currentStep == 3;
    final total = double.tryParse(_totalBudgetController.text) ?? 0;
    final enough = widget.currentBalance >= total && total > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: ThemeConfig.getCardColor(context),
        border: Border(
          top: BorderSide(
            color: ThemeConfig.getColor(
              context,
              lightColor: ThemeConfig.lightBorder,
              darkColor: ThemeConfig.darkBorder,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _isCreating ? null : _onBack,
                icon: Icon(Icons.arrow_back_rounded, size: ResponsiveHelper.getResponsiveIconSize(context)),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ThemeConfig.getTextPrimaryColor(context),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: ThemeConfig.getColor(
                      context,
                      lightColor: ThemeConfig.lightBorder,
                      darkColor: ThemeConfig.darkBorder,
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStep && !enough
                    ? ThemeConfig.warningColor
                    : ThemeConfig.getPrimaryColor(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLastStep
                              ? (enough
                                  ? Icons.rocket_launch_rounded
                                  : Icons.add_card_rounded)
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                        Text(
                          isLastStep
                              ? (enough
                                  ? 'Launch Campaign'
                                  : 'Add Funds & Launch')
                              : 'Continue',
                          style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── utility builders ──────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Text(
        text,
        style: TextStyle(
          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
          fontWeight: FontWeight.w700,
          color: ThemeConfig.getTextPrimaryColor(context),
        ),
      );

  InputDecoration _inputDeco({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: ThemeConfig.getTextSecondaryColor(context)),
      prefixIcon: Icon(icon,
          color: ThemeConfig.getTextSecondaryColor(context), size: ResponsiveHelper.getResponsiveIconSize(context)),
      filled: true,
      fillColor: ThemeConfig.getColor(
        context,
        lightColor: ThemeConfig.lightInputFill,
        darkColor: ThemeConfig.darkInputFill,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
            color: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightInputBorder,
          darkColor: ThemeConfig.darkInputBorder,
        )),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
            color: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightInputBorder,
          darkColor: ThemeConfig.darkInputBorder,
        )),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
            color: ThemeConfig.getPrimaryColor(context), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ThemeConfig.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: ThemeConfig.errorColor, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  String _formatObjective(String o) => o
      .split('_')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

// ════════════════════════════════════════════════════════════════════════════
// INSUFFICIENT FUNDS OVERLAY (5-second auto-dismiss)
// ════════════════════════════════════════════════════════════════════════════

class _InsufficientFundsOverlay extends StatefulWidget {
  final double balance;
  final double required;
  final double deficit;
  final int countdown;
  final VoidCallback onAddFunds;
  final VoidCallback onDismiss;

  const _InsufficientFundsOverlay({
    required this.balance,
    required this.required,
    required this.deficit,
    required this.countdown,
    required this.onAddFunds,
    required this.onDismiss,
  });

  @override
  State<_InsufficientFundsOverlay> createState() =>
      _InsufficientFundsOverlayState();
}

class _InsufficientFundsOverlayState
    extends State<_InsufficientFundsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Timer _tick;
  late int _countdown;

  final _fmt = NumberFormat.currency(symbol: 'TSh ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _countdown = widget.countdown;

    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scaleAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _anim.forward();

    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getResponsiveHorizontalPadding(context)),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with ring
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ThemeConfig.errorColor.withOpacity(0.15),
                            ),
                          ),
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: ThemeConfig.errorColor,
                            size: 42,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Insufficient Funds',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 22),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),

                      // Amounts table
                      Container(
                        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _overlayRow(
                                'Your Balance',
                                _fmt.format(widget.balance),
                                Colors.white70),
                            const SizedBox(height: 10),
                            _overlayRow(
                                'Campaign Cost',
                                _fmt.format(widget.required),
                                Colors.white70),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(color: Colors.white12),
                            ),
                            _overlayRow(
                              'You Need',
                              _fmt.format(widget.deficit),
                              ThemeConfig.errorColor,
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Countdown ring + text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                  begin: 1.0,
                                  end: _countdown / widget.countdown),
                              duration: const Duration(milliseconds: 900),
                              builder: (_, v, __) => CircularProgressIndicator(
                                value: v,
                                strokeWidth: 3,
                                color: ThemeConfig.warningColor,
                                backgroundColor:
                                    Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Closing in $_countdown second${_countdown == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                      // Buttons
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.onAddFunds,
                          icon: const Icon(Icons.add_card_rounded,
                              color: Colors.white),
                          label: Text(
                            'Add Funds Now',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
                                fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeConfig.successColor,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: widget.onDismiss,
                        child: const Text(
                          'Dismiss',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayRow(String label, String value, Color valueColor,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: bold ? 16 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PRIVATE HELPER WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _ObjectiveCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ObjectiveCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = ThemeConfig.getPrimaryColor(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withOpacity(0.09)
              : ThemeConfig.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primary
                : ThemeConfig.getColor(
                    context,
                    lightColor: ThemeConfig.lightBorder,
                    darkColor: ThemeConfig.darkBorder,
                  ),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withOpacity(0.15)
                    : ThemeConfig.getColor(
                        context,
                        lightColor: ThemeConfig.lightInputFill,
                        darkColor: ThemeConfig.darkInputFill,
                      ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 22,
                  color: isSelected
                      ? primary
                      : ThemeConfig.getTextSecondaryColor(context)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                          color: ThemeConfig.getTextPrimaryColor(context))),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                          color: ThemeConfig.getTextSecondaryColor(context))),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primary, size: ResponsiveHelper.getResponsiveIconSize(context)),
          ],
        ),
      ),
    );
  }
}

class _BidCard extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _BidCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = ThemeConfig.getPrimaryColor(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withOpacity(0.09)
              : ThemeConfig.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primary
                : ThemeConfig.getColor(
                    context,
                    lightColor: ThemeConfig.lightBorder,
                    darkColor: ThemeConfig.darkBorder,
                  ),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 28,
                color: isSelected
                    ? primary
                    : ThemeConfig.getTextSecondaryColor(context)),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                    color: isSelected
                        ? primary
                        : ThemeConfig.getTextPrimaryColor(context))),
            const SizedBox(height: 4),
            Text(description,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                    color: ThemeConfig.getTextSecondaryColor(context))),
            if (isSelected) ...[
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              Icon(Icons.check_circle_rounded, color: primary, size: ResponsiveHelper.getResponsiveIconSize(context)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onPick;

  const _DateField(
      {required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightInputFill,
            darkColor: ThemeConfig.darkInputFill,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ThemeConfig.getColor(
              context,
              lightColor: ThemeConfig.lightInputBorder,
              darkColor: ThemeConfig.darkInputBorder,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                    color: ThemeConfig.getTextSecondaryColor(context),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 16,
                    color: ThemeConfig.getPrimaryColor(context)),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                      color: ThemeConfig.getTextPrimaryColor(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final List<Widget> children;
  const _ReviewCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: children
            .map((w) => w)
            .toList()
            .expand((w) => [
                  w,
                  Divider(
                      height: 1,
                      color: ThemeConfig.getColor(
                        context,
                        lightColor: ThemeConfig.lightDivider,
                        darkColor: ThemeConfig.darkDivider,
                      )),
                ])
            .toList()
          ..removeLast(), // remove trailing divider
      ),
    );
  }
}

// Providers (directAdServiceProvider, directAdAlgorithmProvider) are defined in
// lib/core/providers/ad_providers.dart — no duplicates needed here.