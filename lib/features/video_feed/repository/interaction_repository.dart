// lib/features/video_feed/repository/interaction_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class InteractionRepository {
  final FirebaseFirestore _firestore;

  InteractionRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Toggle like for [videoId] by [userId].
  /// Returns the new like status (true if liked, false if unliked).
  /// Uses transactional atomic operations to ensure consistency.
  Future<bool> toggleLike(String videoId, String userId) async {
    final videoRef = _firestore.collection('videos').doc(videoId);
    final likeRef = videoRef.collection('likes').doc(userId);

    return _firestore.runTransaction<bool>((tx) async {
      final likeSnap = await tx.get(likeRef);
      final videoSnap = await tx.get(videoRef);
      int currentLikes = 0;
      if (videoSnap.exists) {
        currentLikes = (videoSnap.data()?['likeCount'] as num?)?.toInt() ?? 0;
      }

      if (likeSnap.exists) {
        // Currently liked - remove like
        tx.delete(likeRef);
        tx.update(videoRef, {'likeCount': FieldValue.increment(-1)});
        return false;
      } else {
        // Not liked - add like
        tx.set(likeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        tx.update(videoRef, {'likeCount': FieldValue.increment(1)});
        return true;
      }
    });
  }

  /// Adds a comment under videos/{videoId}/comments and increments commentCount.
  /// Comment is stored with userId, username, text, and server timestamp.
  /// Supports realtime streaming from the subcollection.
  Future<void> addComment(String videoId, String userId, String username, String text) async {
    final videoRef = _firestore.collection('videos').doc(videoId);
    final commentsRef = videoRef.collection('comments');

    final commentData = {
      'userId': userId,
      'username': username,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore.runTransaction((tx) async {
      tx.set(commentsRef.doc(), commentData);
      tx.update(videoRef, {'commentCount': FieldValue.increment(1)});
    });
  }

  /// Get a stream of comments for a video, ordered by timestamp descending.
  /// Limit to [limit] documents per page for pagination support.
  Stream<QuerySnapshot> getCommentsStream(String videoId, {int limit = 20}) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get paginated comments starting after [lastDocument].
  /// Used for infinite scroll comment loading.
  Future<QuerySnapshot> getCommentsPaginated(
    String videoId, {
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    var query = _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('timestamp', descending: true);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.limit(limit).get();
  }
}
