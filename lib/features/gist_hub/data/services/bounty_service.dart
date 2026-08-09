import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/gist_hub/domain/entities/bounty_entity.dart';

class BountyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  CollectionReference get _bounties => _firestore.collection('bounties');

  /// Escrows [rewardCp] via Supabase (real money leaves the poster's
  /// wallet immediately and sits held), then creates the bounty doc in
  /// Firestore referencing that escrow.
  Future<String> createBounty({
    required String title,
    required String description,
    required String category,
    required double rewardCp,
  }) async {
    if (!AppAuth.isLoggedIn) throw Exception('Not logged in');
    final uid = AppAuth.uid;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final username = userDoc.data()?['username']?.toString() ?? AppAuth.displayHandle;

    String escrowId;
    try {
      final response = await _supabase.rpc('escrow_bounty_cp', params: {
        'p_amount': rewardCp,
        'p_bounty_title': title,
      });
      if (response is! Map || response['success'] != true) {
        throw Exception('Could not hold reward CP');
      }
      escrowId = response['escrow_id'] as String;
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }

    final docRef = _bounties.doc();
    await docRef.set({
      'title': title,
      'description': description,
      'category': category,
      'rewardCp': rewardCp,
      'posterId': uid,
      'posterUsername': username,
      'status': 'open',
      'escrowId': escrowId,
      'claimedByUserId': null,
      'claimedByUsername': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Stream<List<BountyEntity>> browseStream({String? category, String? status}) {
    Query query = _bounties.orderBy('createdAt', descending: true).limit(50);
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((snap) {
      var list = snap.docs
          .map((d) => BountyEntity.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      if (category != null && category.isNotEmpty) {
        list = list.where((b) => b.category == category).toList();
      }
      return list;
    });
  }

  Stream<BountyEntity> watchBounty(String bountyId) {
    return _bounties.doc(bountyId).snapshots().map(
          (d) => BountyEntity.fromMap(d.data() as Map<String, dynamic>, d.id),
        );
  }

  /// Any logged-in user (other than the poster) can claim an open bounty.
  Future<void> claimBounty(String bountyId) async {
    if (!AppAuth.isLoggedIn) throw Exception('Not logged in');
    final uid = AppAuth.uid;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final username = userDoc.data()?['username']?.toString() ?? AppAuth.displayHandle;

    final docRef = _bounties.doc(bountyId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() as Map<String, dynamic>;
      if (data['status'] != 'open') {
        throw Exception('This bounty is no longer open');
      }
      if (data['posterId'] == uid) {
        throw Exception('You cannot claim your own bounty');
      }
      tx.update(docRef, {
        'status': 'inProgress',
        'claimedByUserId': uid,
        'claimedByUsername': username,
      });
    });
  }

  /// Poster-only: releases the held CP to whoever claimed it and marks
  /// the bounty completed.
  Future<void> markComplete(String bountyId) async {
    final docRef = _bounties.doc(bountyId);
    final snap = await docRef.get();
    final data = snap.data() as Map<String, dynamic>;

    if (data['posterId'] != AppAuth.uid) {
      throw Exception('Only the bounty poster can mark this complete');
    }
    if (data['claimedByUserId'] == null) {
      throw Exception('No one has claimed this bounty yet');
    }

    try {
      final response = await _supabase.rpc('release_bounty_cp', params: {
        'p_escrow_id': data['escrowId'],
        'p_recipient_user_id': data['claimedByUserId'],
        'p_bounty_title': data['title'],
      });
      if (response is! Map || response['success'] != true) {
        throw Exception('Could not release payment');
      }
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }

    await docRef.update({'status': 'completed'});
  }

  /// Poster-only: cancels an open (unclaimed) bounty and refunds the CP.
  Future<void> cancelBounty(String bountyId) async {
    final docRef = _bounties.doc(bountyId);
    final snap = await docRef.get();
    final data = snap.data() as Map<String, dynamic>;

    if (data['posterId'] != AppAuth.uid) {
      throw Exception('Only the bounty poster can cancel this');
    }
    if (data['status'] != 'open') {
      throw Exception('Only an unclaimed bounty can be cancelled');
    }

    try {
      final response = await _supabase.rpc('refund_bounty_cp', params: {
        'p_escrow_id': data['escrowId'],
      });
      if (response is! Map || response['success'] != true) {
        throw Exception('Could not refund CP');
      }
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }

    await docRef.update({'status': 'cancelled'});
  }
}
