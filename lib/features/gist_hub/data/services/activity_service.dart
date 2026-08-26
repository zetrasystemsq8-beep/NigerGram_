import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/core/utils/app_auth.dart';

/// One unified system for every activity type instead of a separate
/// feature per type. Every activity is one of three underlying shapes:
///
/// - poll      → debate, quick_battle, quiz, prediction (a question +
///               options + votes)
/// - goal      → goal, challenge (a target number + progress + who has
///               contributed)
/// - announcement → announcement, event (a message + optional date/location)
///
/// `type` drives behavior (which actions apply); `subtype` is just the
/// display label the user picked when creating it.
class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _activities(String communityId) =>
      _firestore.collection('communities').doc(communityId).collection('activities');

  Future<String?> _getMemberRole(String communityId, String userId) async {
    final doc = await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(userId)
        .get();
    return doc.exists ? (doc.data()?['role'] as String?) : null;
  }

  /// Creates a new activity. Open to any member — not restricted to
  /// owner/mod, unlike posts in channel-type communities.
  Future<String> createActivity({
    required String communityId,
    required String type, // 'poll' | 'goal' | 'announcement'
    required String subtype, // 'debate' | 'quick_battle' | 'quiz' | 'prediction' | 'goal' | 'challenge' | 'announcement' | 'event'
    required String title,
    String? description,
    List<String>? pollOptions,
    int? targetCount,
    DateTime? eventDate,
    String? location,
    DateTime? expiresAt,
  }) async {
    if (!AppAuth.isLoggedIn) throw Exception('Not logged in');
    final role = await _getMemberRole(communityId, AppAuth.uid);
    if (role == null) throw Exception('Only members can create activities');

    final data = <String, dynamic>{
      'creatorId': AppAuth.uid,
      'creatorName': AppAuth.displayHandle,
      'type': type,
      'subtype': subtype,
      'title': title,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
    };

    if (type == 'poll') {
      if (pollOptions == null || pollOptions.length < 2) {
        throw Exception('A poll needs at least 2 options');
      }
      data['options'] = pollOptions
          .map((label) => {'id': label.toLowerCase().replaceAll(RegExp(r'\s+'), '_'), 'label': label, 'votes': 0})
          .toList();
      data['voters'] = <String, String>{};
      data['participantCount'] = 0;
    } else if (type == 'goal') {
      data['targetCount'] = targetCount ?? 100;
      data['currentCount'] = 0;
      data['participants'] = <String>[];
    } else if (type == 'announcement') {
      data['eventDate'] = eventDate != null ? Timestamp.fromDate(eventDate) : null;
      data['location'] = location;
    } else {
      throw Exception('Unknown activity type: $type');
    }

    final docRef = await _activities(communityId).add(data);
    return docRef.id;
  }

  /// Live feed of activities for a community, newest first. Optionally
  /// filters out ones that have already expired.
  Stream<List<Map<String, dynamic>>> getActivitiesStream(String communityId, {bool activeOnly = false}) {
    return _activities(communityId).orderBy('createdAt', descending: true).limit(50).snapshots().map((snap) {
      final now = Timestamp.now();
      final docs = snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
      if (!activeOnly) return docs;
      return docs.where((a) {
        final expiresAt = a['expiresAt'] as Timestamp?;
        return expiresAt == null || expiresAt.compareTo(now) > 0;
      }).toList();
    });
  }

  /// Votes on a poll-shaped activity. Voting again with a different
  /// option switches the vote; voting the same option again removes it
  /// (toggle off).
  Future<void> voteOnPoll({
    required String communityId,
    required String activityId,
    required String optionId,
  }) async {
    if (!AppAuth.isLoggedIn) throw Exception('Not logged in');
    final uid = AppAuth.uid;
    final ref = _activities(communityId).doc(activityId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Activity not found');
      final data = snap.data() as Map<String, dynamic>;
      if (data['type'] != 'poll') throw Exception('Not a poll');

      final options = List<Map<String, dynamic>>.from(
        (data['options'] as List).map((o) => Map<String, dynamic>.from(o)),
      );
      final voters = Map<String, dynamic>.from(data['voters'] ?? {});
      final previousVote = voters[uid] as String?;

      if (previousVote == optionId) {
        // Toggle off.
        final idx = options.indexWhere((o) => o['id'] == optionId);
        if (idx != -1) options[idx]['votes'] = (options[idx]['votes'] as int) - 1;
        voters.remove(uid);
      } else {
        if (previousVote != null) {
          final prevIdx = options.indexWhere((o) => o['id'] == previousVote);
          if (prevIdx != -1) options[prevIdx]['votes'] = (options[prevIdx]['votes'] as int) - 1;
        }
        final idx = options.indexWhere((o) => o['id'] == optionId);
        if (idx == -1) throw Exception('Option not found');
        options[idx]['votes'] = (options[idx]['votes'] as int) + 1;
        voters[uid] = optionId;
      }

      tx.update(ref, {
        'options': options,
        'voters': voters,
        'participantCount': voters.length,
      });
    });
  }

  /// Marks the current user as having contributed to a goal-shaped
  /// activity (e.g. "completed today's challenge"). Each person can only
  /// count once.
  Future<void> contributeToGoal({
    required String communityId,
    required String activityId,
  }) async {
    if (!AppAuth.isLoggedIn) throw Exception('Not logged in');
    final uid = AppAuth.uid;
    final ref = _activities(communityId).doc(activityId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Activity not found');
      final data = snap.data() as Map<String, dynamic>;
      if (data['type'] != 'goal') throw Exception('Not a goal');

      final participants = List<String>.from(data['participants'] ?? []);
      if (participants.contains(uid)) return; // already contributed

      participants.add(uid);
      tx.update(ref, {
        'participants': participants,
        'currentCount': FieldValue.increment(1),
      });
    });
  }

  /// Owner/mod, or the activity's own creator, can remove it.
  Future<void> deleteActivity({
    required String communityId,
    required String activityId,
  }) async {
    if (!AppAuth.isLoggedIn) throw Exception('Not logged in');
    final uid = AppAuth.uid;
    final ref = _activities(communityId).doc(activityId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final isCreator = data['creatorId'] == uid;
    final role = await _getMemberRole(communityId, uid);
    final isModOrOwner = role == 'owner' || role == 'moderator';

    if (!isCreator && !isModOrOwner) {
      throw Exception('Not authorized to remove this activity');
    }

    await ref.delete();
  }
}
