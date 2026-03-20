// lib/core/services/direct_ad_models.dart

// ========================================
// DIRECT AD MODEL (For serving ads)
// ========================================

class DirectAd {
  final String campaignId;
  final String creativeId;
  final String advertiserId;
  final String headline;
  final String? description;
  final String callToAction;
  final String imageUrl;
  final String? logoUrl;
  final String landingUrl;
  final double bidAmount;
  final String biddingStrategy; // 'cpc' or 'cpm'
  final String mediaType;       // 'image' or 'video'
  final String? videoUrl;
  final String destinationType;  // 'website' | 'whatsapp' | 'profile'
  final String? advertiserUserId;  // auth user_id of the advertiser — used for in-app profile navigation
  final String? linkedPropertyId;  // for destination_type='property' — the property to open in-app

  DirectAd({
    required this.campaignId,
    required this.creativeId,
    required this.advertiserId,
    required this.headline,
    this.description,
    required this.callToAction,
    required this.imageUrl,
    this.logoUrl,
    required this.landingUrl,
    required this.bidAmount,
    this.biddingStrategy = 'cpc',
    this.mediaType = 'image',
    this.videoUrl,
    this.destinationType = 'website',
    this.advertiserUserId,
    this.linkedPropertyId,
  });

  factory DirectAd.fromJson(Map<String, dynamic> json) {
    return DirectAd(
      campaignId:      json['campaign_id'] as String,
      creativeId:      json['creative_id'] as String,
      advertiserId:    json['advertiser_id'] as String,
      headline:        json['headline'] as String,
      description:     json['description'] as String?,
      callToAction:    json['call_to_action'] as String,
      imageUrl:        json['image_url'] as String,
      logoUrl:         json['logo_url'] as String?,
      landingUrl:      json['landing_url'] as String,
      bidAmount:       (json['bid_amount'] as num).toDouble(),
      biddingStrategy: json['bidding_strategy'] as String? ?? 'cpc',
      mediaType:       json['media_type'] as String? ?? 'image',
      videoUrl:        json['video_url'] as String?,
      destinationType:   json['destination_type'] as String? ?? 'website',
      advertiserUserId:  json['advertiser_user_id'] as String?,
      linkedPropertyId:  json['linked_property_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaign_id':      campaignId,
      'creative_id':      creativeId,
      'advertiser_id':    advertiserId,
      'headline':         headline,
      'description':      description,
      'call_to_action':   callToAction,
      'image_url':        imageUrl,
      'logo_url':         logoUrl,
      'landing_url':      landingUrl,
      'bid_amount':       bidAmount,
      'bidding_strategy': biddingStrategy,
      'media_type':       mediaType,
      'video_url':        videoUrl,
      'destination_type':   destinationType,
      'advertiser_user_id': advertiserUserId,
      'linked_property_id': linkedPropertyId,
    };
  }

  /// Cost to record for this impression:
  ///   CPC → 0.0  (cost charged only when user clicks)
  ///   CPM → bidAmount / 1000  (cost per individual impression)
  double get impressionCost =>
      biddingStrategy == 'cpm' ? bidAmount / 1000.0 : 0.0;
}

// ========================================
// ADVERTISER MODEL
// ========================================

class Advertiser {
  final String id;
  final String? userId;
  final String companyName;
  final String contactName;
  final String email;
  final String phone;
  final String companyType;
  final String? companyWebsite;
  final String? companyDescription;
  final bool isVerified;
  final String status;
  final double accountBalance;
  final double totalSpent;
  final String currency;
  final DateTime createdAt;

  Advertiser({
    required this.id,
    this.userId,
    required this.companyName,
    required this.contactName,
    required this.email,
    required this.phone,
    required this.companyType,
    this.companyWebsite,
    this.companyDescription,
    required this.isVerified,
    required this.status,
    required this.accountBalance,
    required this.totalSpent,
    required this.currency,
    required this.createdAt,
  });

  factory Advertiser.fromJson(Map<String, dynamic> json) {
    return Advertiser(
      id:                 json['id'] as String,
      userId:             json['user_id'] as String?,
      companyName:        json['company_name'] as String,
      contactName:        json['contact_name'] as String,
      email:              json['email'] as String,
      phone:              json['phone'] as String,
      companyType:        json['company_type'] as String,
      companyWebsite:     json['company_website'] as String?,
      companyDescription: json['company_description'] as String?,
      isVerified:         json['is_verified'] as bool? ?? false,
      status:             json['status'] as String,
      accountBalance:     (json['account_balance'] as num).toDouble(),
      totalSpent:         (json['total_spent'] as num).toDouble(),
      currency:           json['currency'] as String? ?? 'TZS',
      createdAt:          DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isActive => status == 'active';
  bool get canCreateCampaigns => isActive && accountBalance > 0;
}

// ========================================
// AD CAMPAIGN MODEL
// ========================================

class AdCampaign {
  final String id;
  final String advertiserId;
  final String campaignName;
  final String campaignObjective;
  final List<String> targetPropertyTypes;
  final List<String> targetLocations;
  final List<String> targetCountries; // ISO codes; empty = all East Africa
  final Map<String, dynamic>? targetPriceRange;
  final List<String> targetUserInterests;
  final double dailyBudget;
  final double totalBudget;
  final double bidAmount;
  final String biddingStrategy;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final double spentAmount;
  final int impressionsCount;
  final int clicksCount;
  final int conversionsCount;
  final double ctr;
  final double cpcActual;
  final double conversionRate;
  final DateTime createdAt;

  AdCampaign({
    required this.id,
    required this.advertiserId,
    required this.campaignName,
    required this.campaignObjective,
    required this.targetPropertyTypes,
    required this.targetLocations,
    this.targetCountries = const [],
    this.targetPriceRange,
    required this.targetUserInterests,
    required this.dailyBudget,
    required this.totalBudget,
    required this.bidAmount,
    required this.biddingStrategy,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.spentAmount,
    required this.impressionsCount,
    required this.clicksCount,
    required this.conversionsCount,
    required this.ctr,
    required this.cpcActual,
    required this.conversionRate,
    required this.createdAt,
  });

  factory AdCampaign.fromJson(Map<String, dynamic> json) {
    return AdCampaign(
      id:                  json['id'] as String,
      advertiserId:        json['advertiser_id'] as String,
      campaignName:        json['campaign_name'] as String,
      campaignObjective:   json['campaign_objective'] as String,
      targetPropertyTypes: (json['target_property_types'] as List?)
                               ?.map((e) => e.toString()).toList() ?? [],
      targetLocations:     (json['target_locations'] as List?)
                               ?.map((e) => e.toString()).toList() ?? [],
      targetCountries:     (json['target_countries'] as List?)
                               ?.map((e) => e.toString()).toList() ?? [],
      targetPriceRange:    json['target_price_range'] as Map<String, dynamic>?,
      targetUserInterests: (json['target_user_interests'] as List?)
                               ?.map((e) => e.toString()).toList() ?? [],
      dailyBudget:         (json['daily_budget'] as num).toDouble(),
      totalBudget:         (json['total_budget'] as num).toDouble(),
      bidAmount:           (json['bid_amount'] as num).toDouble(),
      biddingStrategy:     json['bidding_strategy'] as String,
      startDate:           DateTime.parse(json['start_date'] as String),
      endDate:             DateTime.parse(json['end_date'] as String),
      status:              json['status'] as String,
      spentAmount:         (json['spent_amount'] as num).toDouble(),
      impressionsCount:    json['impressions_count'] as int? ?? 0,
      clicksCount:         json['clicks_count'] as int? ?? 0,
      conversionsCount:    json['conversions_count'] as int? ?? 0,
      ctr:                 (json['ctr'] as num?)?.toDouble() ?? 0.0,
      cpcActual:           (json['cpc_actual'] as num?)?.toDouble() ?? 0.0,
      conversionRate:      (json['conversion_rate'] as num?)?.toDouble() ?? 0.0,
      createdAt:           DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isRunning   => status == 'running';
  bool get isPaused    => status == 'paused';
  bool get isCompleted => status == 'completed';
  bool get hasBudget   => spentAmount < totalBudget;

  double get budgetUsagePercentage =>
      totalBudget > 0 ? (spentAmount / totalBudget) * 100 : 0;

  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays;
  }
}

// ========================================
// AD CREATIVE MODEL
// ========================================

class AdCreative {
  final String id;
  final String campaignId;
  final String adFormat;
  final String headline;
  final String? description;
  final String callToAction;
  final String imageUrl;
  final String? logoUrl;
  final String landingUrl;
  final String status;
  final bool isApproved;
  final int impressions;
  final int clicks;
  final DateTime createdAt;
  final String mediaType;       // 'image' or 'video'
  final String? videoUrl;
  final String destinationType; // 'website' | 'whatsapp' | 'profile'

  AdCreative({
    required this.id,
    required this.campaignId,
    required this.adFormat,
    required this.headline,
    this.description,
    required this.callToAction,
    required this.imageUrl,
    this.logoUrl,
    required this.landingUrl,
    required this.status,
    required this.isApproved,
    required this.impressions,
    required this.clicks,
    required this.createdAt,
    this.mediaType = 'image',
    this.videoUrl,
    this.destinationType = 'website',
  });

  factory AdCreative.fromJson(Map<String, dynamic> json) {
    return AdCreative(
      id:              json['id'] as String,
      campaignId:      json['campaign_id'] as String,
      adFormat:        json['ad_format'] as String,
      headline:        json['headline'] as String,
      description:     json['description'] as String?,
      callToAction:    json['call_to_action'] as String,
      imageUrl:        json['image_url'] as String,
      logoUrl:         json['logo_url'] as String?,
      landingUrl:      json['landing_url'] as String,
      status:          json['status'] as String,
      isApproved:      json['is_approved'] as bool? ?? false,
      impressions:     json['impressions'] as int? ?? 0,
      clicks:          json['clicks'] as int? ?? 0,
      createdAt:       DateTime.parse(json['created_at'] as String),
      mediaType:       json['media_type'] as String? ?? 'image',
      videoUrl:        json['video_url'] as String?,
      destinationType: json['destination_type'] as String? ?? 'website',
    );
  }

  double get ctr => impressions > 0 ? (clicks / impressions) * 100 : 0.0;
}

// ========================================
// ADVERTISER PAYMENT MODEL
// ========================================

class AdvertiserPayment {
  final String id;
  final String advertiserId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String transactionId;
  final String? paymentProvider;
  final String? providerReference;
  final String status;
  final DateTime paymentDate;
  final DateTime? completedAt;

  AdvertiserPayment({
    required this.id,
    required this.advertiserId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.transactionId,
    this.paymentProvider,
    this.providerReference,
    required this.status,
    required this.paymentDate,
    this.completedAt,
  });

  factory AdvertiserPayment.fromJson(Map<String, dynamic> json) {
    return AdvertiserPayment(
      id:                json['id'] as String,
      advertiserId:      json['advertiser_id'] as String,
      amount:            (json['amount'] as num).toDouble(),
      currency:          json['currency'] as String,
      paymentMethod:     json['payment_method'] as String,
      transactionId:     json['transaction_id'] as String,
      paymentProvider:   json['payment_provider'] as String?,
      providerReference: json['provider_reference'] as String?,
      status:            json['status'] as String,
      paymentDate:       DateTime.parse(json['payment_date'] as String),
      completedAt:       json['completed_at'] != null
                             ? DateTime.parse(json['completed_at'] as String)
                             : null,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isPending   => status == 'pending';
  bool get isFailed    => status == 'failed';
}

// ========================================
// CAMPAIGN PERFORMANCE MODEL
// ========================================

class CampaignPerformance {
  final int impressions;
  final int clicks;
  final int conversions;
  final double spent;
  final double ctr;
  final double cpc;
  final double conversionRate;
  final double roi;

  CampaignPerformance({
    required this.impressions,
    required this.clicks,
    required this.conversions,
    required this.spent,
    required this.ctr,
    required this.cpc,
    required this.conversionRate,
    required this.roi,
  });

  factory CampaignPerformance.fromJson(Map<String, dynamic> json) {
    final impressions = json['impressions_count'] as int? ?? 0;
    final clicks      = json['clicks_count'] as int? ?? 0;
    final conversions = json['conversions_count'] as int? ?? 0;
    final spent       = (json['spent_amount'] as num?)?.toDouble() ?? 0.0;

    return CampaignPerformance(
      impressions:    impressions,
      clicks:         clicks,
      conversions:    conversions,
      spent:          spent,
      ctr:            impressions > 0 ? (clicks / impressions) * 100 : 0.0,
      cpc:            clicks > 0 ? spent / clicks : 0.0,
      conversionRate: clicks > 0 ? (conversions / clicks) * 100 : 0.0,
      roi:            spent > 0 ? ((conversions * 100000 - spent) / spent) * 100 : 0.0,
    );
  }
}

// ========================================
// ADVERTISER STATISTICS MODEL
// ========================================

class AdvertiserStats {
  final int totalCampaigns;
  final int activeCampaigns;
  final int totalImpressions;
  final int totalClicks;
  final double totalSpent;
  final double averageCtr;

  AdvertiserStats({
    required this.totalCampaigns,
    required this.activeCampaigns,
    required this.totalImpressions,
    required this.totalClicks,
    required this.totalSpent,
    required this.averageCtr,
  });

  double get averageCpc =>
      totalClicks > 0 ? totalSpent / totalClicks : 0.0;
}

// ========================================
// ENUMS
// ========================================

enum CompanyType {
  realEstateAgency('real_estate_agency', 'Real Estate Agency'),
  propertyDeveloper('property_developer', 'Property Developer'),
  mortgageLender('mortgage_lender', 'Mortgage Lender'),
  insuranceCompany('insurance_company', 'Insurance Company'),
  movingCompany('moving_company', 'Moving Company'),
  homeServices('home_services', 'Home Services'),
  furnitureStore('furniture_store', 'Furniture Store'),
  constructionCompany('construction_company', 'Construction Company');

  final String value;
  final String displayName;
  const CompanyType(this.value, this.displayName);
}

enum CampaignObjective {
  brandAwareness('brand_awareness', 'Brand Awareness'),
  propertyInquiries('property_inquiries', 'Property Inquiries'),
  websiteVisits('website_visits', 'Website Visits'),
  phoneCalls('phone_calls', 'Phone Calls'),
  appInstalls('app_installs', 'App Installs');

  final String value;
  final String displayName;
  const CampaignObjective(this.value, this.displayName);
}

enum AdFormat {
  banner300x250('banner_300x250', 'Banner 300×250'),
  banner320x50('banner_320x50', 'Banner 320×50'),
  banner728x90('banner_728x90', 'Banner 728×90'),
  nativeSmall('native_small', 'Native Small'),
  nativeMedium('native_medium', 'Native Medium'),
  nativeLarge('native_large', 'Native Large'),
  videoAd('video_ad', 'Video Ad');

  final String value;
  final String displayName;
  const AdFormat(this.value, this.displayName);
}

// ========================================
// REFUND REQUEST MODEL
// ========================================

class RefundRequest {
  final String id;
  final String advertiserId;
  final String? campaignId;
  final double amount;
  final String? phone;
  final String? reason;
  final String type;   // 'balance' | 'cash'
  final String status; // 'pending' | 'approved' | 'paid' | 'rejected'
  final String? adminNotes;
  final DateTime requestedAt;
  final DateTime? processedAt;

  RefundRequest({
    required this.id,
    required this.advertiserId,
    this.campaignId,
    required this.amount,
    this.phone,
    this.reason,
    required this.type,
    required this.status,
    this.adminNotes,
    required this.requestedAt,
    this.processedAt,
  });

  factory RefundRequest.fromJson(Map<String, dynamic> json) {
    return RefundRequest(
      id:           json['id'] as String,
      advertiserId: json['advertiser_id'] as String,
      campaignId:   json['campaign_id'] as String?,
      amount:       (json['amount'] as num).toDouble(),
      phone:        json['phone'] as String?,
      reason:       json['reason'] as String?,
      type:         json['type'] as String,
      status:       json['status'] as String,
      adminNotes:   json['admin_notes'] as String?,
      requestedAt:  DateTime.parse(json['requested_at'] as String),
      processedAt:  json['processed_at'] != null
                        ? DateTime.parse(json['processed_at'] as String)
                        : null,
    );
  }

  bool get isPending  => status == 'pending';
  bool get isPaid     => status == 'paid';
  bool get isRejected => status == 'rejected';
  bool get isBalance  => type == 'balance';
  bool get isCash     => type == 'cash';
}

enum CallToAction {
  learnMore('Learn More'),
  viewProperty('View Property'),
  contactUs('Contact Us'),
  getQuote('Get Quote'),
  callNow('Call Now'),
  visitWebsite('Visit Website'),
  applyNow('Apply Now'),
  scheduleTour('Schedule Tour'),
  watchVideo('Watch Video');

  final String text;
  const CallToAction(this.text);
}