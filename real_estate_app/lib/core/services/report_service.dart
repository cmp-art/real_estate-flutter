import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ReportResult { success, alreadyReported, error }

class ReportService {
  final SupabaseClient _supabase;
  ReportService(this._supabase);

  Future<ReportResult> reportProperty({
    required String propertyId,
    String? reporterId,
    required String reason,
    String? description,
  }) async {
    try {
      final response = await _supabase.rpc('report_property', params: {
        'p_property_id': propertyId,
        'p_reporter_id': reporterId,
        'p_reason': reason,
        'p_description': description,
      });
      final data = response as Map<String, dynamic>;
      if (data['message'] == 'already_reported') return ReportResult.alreadyReported;
      return ReportResult.success;
    } catch (e) {
      debugPrint('Error reporting property: $e');
      return ReportResult.error;
    }
  }

  Future<ReportResult> reportAd({
    required String creativeId,
    required String campaignId,
    String? reporterId,
    required String reason,
    String? description,
  }) async {
    try {
      final response = await _supabase.rpc('report_ad', params: {
        'p_creative_id': creativeId,
        'p_campaign_id': campaignId,
        'p_reporter_id': reporterId,
        'p_reason': reason,
        'p_description': description,
      });
      final data = response as Map<String, dynamic>;
      if (data['message'] == 'already_reported') return ReportResult.alreadyReported;
      return ReportResult.success;
    } catch (e) {
      debugPrint('Error reporting ad: $e');
      return ReportResult.error;
    }
  }
}
