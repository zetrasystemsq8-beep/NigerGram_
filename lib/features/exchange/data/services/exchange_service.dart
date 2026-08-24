import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nigergram/core/utils/app_auth.dart';

/// Stages a listing progresses through — idea has no price yet, prototype
/// is seeking funding toward a goal, product is ready to buy/license.
enum ListingStage { idea, prototype, product }

class ExchangeService {
  final SupabaseClient _client = Supabase.instance.client;

  ListingStage _stageFromString(String? value) {
    switch (value) {
      case 'prototype':
        return ListingStage.prototype;
      case 'product':
        return ListingStage.product;
      default:
        return ListingStage.idea;
    }
  }

  String _stageToString(ListingStage stage) {
    switch (stage) {
      case ListingStage.prototype:
        return 'prototype';
      case ListingStage.product:
        return 'product';
      case ListingStage.idea:
        return 'idea';
    }
  }

  /// Creates a new listing. Free to post — no CP cost, matching the
  /// "open by default" principle: publishing itself is never gated.
  Future<String> createListing({
    required String title,
    required String category,
    required ListingStage stage,
    String? oneLiner,
    String? description,
    double? price,
    double? fundingGoal,
    String? licenseType,
  }) async {
    if (!AppAuth.isLoggedIn) throw Exception('Not logged in');

    final row = await _client
        .from('exchange_listings')
        .insert({
          'owner_id': AppAuth.uid,
          'owner_name': AppAuth.displayHandle,
          'title': title,
          'one_liner': oneLiner,
          'description': description,
          'category': category,
          'stage': _stageToString(stage),
          'price': price,
          'funding_goal': fundingGoal,
          'funding_raised': 0,
          'license_type': licenseType,
        })
        .select('id')
        .single();

    return row['id'] as String;
  }

  /// Browses listings, optionally filtered by stage and/or category.
  /// Newest first.
  Future<List<Map<String, dynamic>>> browseListings({
    ListingStage? stage,
    String? category,
    int limit = 50,
  }) async {
    var query = _client.from('exchange_listings').select();

    if (stage != null) {
      query = query.eq('stage', _stageToString(stage));
    }
    if (category != null) {
      query = query.eq('category', category);
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> getListing(String listingId) async {
    final row = await _client.from('exchange_listings').select().eq('id', listingId).maybeSingle();
    return row;
  }

  /// Attaches a Crucible Overview to an existing listing as proof. Verifies
  /// the Overview actually exists first — if the ID is wrong or fake,
  /// this throws instead of silently attaching a broken reference.
  Future<void> attachCrucibleOverview(String listingId, String overviewId) async {
    final overview = await getCrucibleOverview(overviewId);
    if (overview == null) {
      throw Exception('That Overview ID was not found. Double-check it in Crucible and try again.');
    }
    await _client.from('exchange_listings').update({'overview_id': overviewId}).eq('id', listingId);
  }

  Future<Map<String, dynamic>?> getCrucibleOverview(String overviewId) async {
    return await _client.from('overviews').select().eq('id', overviewId).maybeSingle();
  }

  /// Returns the Tribunal review status for a given overview: the
  /// definitive final_reports row if one exists, otherwise how many
  /// individual reviews are in progress, otherwise null (not submitted).
  Future<Map<String, dynamic>?> getTribunalStatus(String overviewId) async {
    final finalReport = await _client
        .from('final_reports')
        .select()
        .eq('overview_id', overviewId)
        .maybeSingle();

    if (finalReport != null) {
      return {'status': 'final', ...finalReport};
    }

    final reviews = await _client.from('reviews').select('id').eq('overview_id', overviewId);
    if (reviews.isNotEmpty) {
      return {'status': 'in_progress', 'review_count': reviews.length};
    }

    return null;
  }

  /// Records an interaction (interest / support / purchase / collaborate
  /// request). For support/purchase, also spends CP via the existing
  /// ledger RPC and bumps funding_raised on the listing.
  Future<void> recordInteraction({
    required String listingId,
    required String type,
    double? amount,
    String? message,
  }) async {
    if (!AppAuth.isLoggedIn) throw Exception('Not logged in');

    if ((type == 'support' || type == 'purchase') && amount != null && amount > 0) {
      final response = await _client.rpc('spend_cp', params: {
        'p_amount': amount,
        'p_reason': type == 'purchase' ? 'Purchased Exchange listing' : 'Supported Exchange listing',
      });
      if (response is! Map || response['success'] != true) {
        throw Exception('Payment failed');
      }

      if (type == 'support') {
        final listing = await getListing(listingId);
        final currentRaised = (listing?['funding_raised'] as num?)?.toDouble() ?? 0;
        await _client
            .from('exchange_listings')
            .update({'funding_raised': currentRaised + amount}).eq('id', listingId);
      }
    }

    await _client.from('exchange_interactions').insert({
      'listing_id': listingId,
      'user_id': AppAuth.uid,
      'type': type,
      'amount': amount,
      'message': message,
    });
  }

  Future<List<Map<String, dynamic>>> getInteractions(String listingId) async {
    final rows = await _client
        .from('exchange_interactions')
        .select()
        .eq('listing_id', listingId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}
