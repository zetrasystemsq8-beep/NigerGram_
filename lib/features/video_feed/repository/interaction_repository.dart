// lib/features/video_feed/repository/interaction_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class InteractionRepository {
  final FirebaseFirestore _firestore;

  InteractionRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Toggle like for [videoId] by [userId].
  /// Returns the new like status (true if liked, false if unliked).
  /// Uses transactional atomic operations to ensure consistency.
  /// Maintains both a `likes` subcollection and a `likedBy` array on the video document.
  Future<bool> toggleLike(String videoId, String userId) async {
    final videoRef = _firestore.collection('videos').doc(videoId);
    final likeRef = videoRef.collection('likes').doc(userId);

    return _firestore.runTransaction<bool>((tx) async {
      final likeSnap = await tx.get(likeRef);
      final videoSnap = await tx.get(videoRef);

      // Get current like count for syncing
      int currentLikes = 0;
      List<dynamic> likedBy = [];
      if (videoSnap.exists) {
        currentLikes = (videoSnap.data()?['likeCount'] as num?)?.toInt() ?? 0;
        likedBy = (videoSnap.data()?['likedBy'] as List<dynamic>?) ?? [];
      }

      if (likeSnap.exists) {
        // Currently liked - remove like
        tx.delete(likeRef);
        likedBy.removeWhere((id) => id == userId);
        tx.update(videoRef, {
          'likeCount': FieldValue.increment(-1),
          'likedBy': likedBy,
        });
        return false;
      } else {
        // Not liked - add like
        tx.set(likeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        likedBy.add(userId);
        tx.update(videoRef, {
          'likeCount': FieldValue.increment(1),
          'likedBy': likedBy,
        });
        return true;
      }
    });
  }

  /// Toggle save/bookmark for [videoId] by [userId].
  /// Returns the new save status (true if saved, false if unsaved).
  /// Uses a transactional operation to maintain `savedBy` array on video document.
  Future<bool> toggleSave(String videoId, String userId) async {
    final videoRef = _firestore.collection('videos').doc(videoId);
    final saveRef = videoRef.collection('saves').doc(userId);

    return _firestore.runTransaction<bool>((tx) async {
      final saveSnap = await tx.get(saveRef);
      final videoSnap = await tx.get(videoRef);

      List<dynamic> savedBy = [];
      if (videoSnap.exists) {
        savedBy = (videoSnap.data()?['savedBy'] as List<dynamic>?) ?? [];
      }

      if (saveSnap.exists) {
        // Currently saved - remove save
        tx.delete(saveRef);
        savedBy.removeWhere((id) => id == userId);
        tx.update(videoRef, {'savedBy': savedBy});
        return false;
      } else {
        // Not saved - add save
        tx.set(saveRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        savedBy.add(userId);
        tx.update(videoRef, {'savedBy': savedBy});
        return true;
      }
    });
  }

  /// Adds a comment under videos/{videoId}/comments and increments commentCount.
  /// Comment is stored with userId, username, userAvatar, text, and server timestamp.
  /// Supports realtime streaming from the subcollection.
  Future<String> addComment(
    String videoId,
    String userId,
    String username,
    String text, {
    String? userAvatar,
  }) async {
    final videoRef = _firestore.collection('videos').doc(videoId);
    final commentsRef = videoRef.collection('comments');

    // Create a new document with auto-generated ID
    final newDoc = commentsRef.doc();

    final commentData = {
      'id': newDoc.id,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar ?? '',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
    };

    await _firestore.runTransaction((tx) async {
      tx.set(newDoc, commentData);
      tx.update(videoRef, {'commentCount': FieldValue.increment(1)});
    });

    return newDoc.id; // Return comment ID for potential future operations
  }

  /// Get a stream of comments for a video, ordered by timestamp descending.
  /// Limit to [limit] documents per page for pagination support.
  /// Real-time updates enabled for live comment display.
  Stream<QuerySnapshot> getCommentsStream(String videoId, {int limit = 50}) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
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
        .orderBy('createdAt', descending: true);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.limit(limit).get();
  }

  /// Check if current user has liked a specific video.
  /// Returns true if userId exists in the video's likedBy array.
  Future<bool> isVideoLiked(String videoId, String userId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      final likedBy = (doc.data()?['likedBy'] as List<dynamic>?) ?? [];
      return likedBy.contains(userId);
    } catch (_) {
      return false;
    }
  }

  /// Check if current user has saved a specific video.
  /// Returns true if userId exists in the video's savedBy array.
  Future<bool> isVideoSaved(String videoId, String userId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      final savedBy = (doc.data()?['savedBy'] as List<dynamic>?) ?? [];
      return savedBy.contains(userId);
    } catch (_) {
      return false;
    }
  }

  /// Get a live stream of a video's interaction data (likes, comments, saves).
  /// Useful for UI to stay in sync with backend changes.
  Stream<DocumentSnapshot> getVideoInteractionsStream(String videoId) {
    return _firestore.collection('videos').doc(videoId).snapshots();
  }
}
