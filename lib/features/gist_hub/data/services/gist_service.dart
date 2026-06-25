// lib/features/gist_hub/data/services/gist_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class GistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Stream of posts based on filter: 'Latest' (createdAt desc), 'Trending' (commentCount desc), 'Polls' (type == 'poll')
  Stream<List<Map<String, dynamic>>> getGistFeedStream({required String filter}) {
    Query<Map<String, dynamic>> q = _firestore.collection('gist_posts').withConverter(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (m, _) => m,
        );

    if (filter == 'Latest') {
      q = q.orderBy('createdAt', descending: true);
    } else if (filter == 'Trending') {
      q = q.orderBy('commentCount', descending: true);
    } else if (filter == 'Polls') {
      q = q.where('type', isEqualTo: 'poll').orderBy('createdAt', descending: true);
    } else {
      q = q.orderBy('createdAt', descending: true);
    }

    return q.snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {
          'id': d.id,
          ...data,
        };
      }).toList();
    });
  }

  Future<void> createPost({
    required String type, // 'text'|'image'|'poll'
    required String content,
    File? imageFile,
    List<String>? pollOptions, // exactly 2 when poll
    bool isAnonymous = false,
  }) async {
    try {
      final user = _auth.currentUser;
      String userId = user?.uid ?? '';
      String displayName = user?.displayName ?? 'Anonymous';
      String username = user?.email?.split('@').first ?? 'anonymous';
      String profilePic = '';
      // Attempt to fetch profile pic if user doc exists
      if (userId.isNotEmpty) {
        final doc = await _firestore.collection('users').doc(userId).get();
        if (doc.exists) {
          final d = doc.data()!;
          displayName = d['displayName']?.toString() ?? displayName;
          username = d['username']?.toString() ?? username;
          profilePic = d['profilePicUrl']?.toString() ?? '';
        }
      }

      if (isAnonymous) {
        displayName = 'Anonymous';
        username = 'anonymous';
        profilePic = '';
      }

      String? imageUrl;
      if (imageFile != null) {
        final path = 'gist_images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
        final ref = _storage.ref().child(path);
        final uploadTask = ref.putFile(imageFile);
        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      final postRef = _firestore.collection('gist_posts').doc();
      final now = FieldValue.serverTimestamp();
      final initialReactions = {
        "😂": 0,
        "😱": 0,
        "👀": 0,
        "🥴": 0,
        "🇳🇬": 0,
      };

      final Map<String, int> initialPollVotes = {"0": 0, "1": 0};

      await postRef.set({
        'userId': userId,
        'displayName': displayName,
        'username': username,
        'profilePic': profilePic,
        'type': type,
        'content': content,
        'imageUrl': imageUrl,
        'pollOptions': pollOptions,
        'pollVotes': initialPollVotes,
        'reactions': initialReactions,
        'commentCount': 0,
        'createdAt': now,
        'isAnonymous': isAnonymous,
      });
      print('✅ Gist post created: ${postRef.id}');
    } catch (e) {
      print('❌ createPost error: $e');
      rethrow;
    }
  }

  Future<void> addReaction({
    required String postId,
    required String emoji, // one of the keys
  }) async {
    final DocumentReference postRef = _firestore.collection('gist_posts').doc(postId);
    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(postRef);
        if (!snapshot.exists) throw Exception('Post not found');
        final data = snapshot.data() as Map<String, dynamic>;
        final Map<String, dynamic> reactions = (data['reactions'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k.toString(), v ?? 0)) ?? {};
        final current = (reactions[emoji] is int) ? reactions[emoji] as int : int.tryParse(reactions[emoji]?.toString() ?? '0') ?? 0;
        reactions[emoji] = current + 1;
        tx.update(postRef, {'reactions': reactions});
      });
      print('✅ Reaction added $emoji on $postId');
    } catch (e) {
      print('❌ addReaction error: $e');
      rethrow;
    }
  }

  Future<void> castVote({
    required String postId,
    required int choiceIndex, // 0 or 1
  }) async {
    final DocumentReference postRef = _firestore.collection('gist_posts').doc(postId);
    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(postRef);
        if (!snapshot.exists) throw Exception('Post not found');
        final data = snapshot.data() as Map<String, dynamic>;
        final Map<String, dynamic> pollVotes = (data['pollVotes'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k.toString(), v ?? 0)) ?? {'0': 0, '1': 0};
        final key = choiceIndex.toString();
        final current = (pollVotes[key] is int) ? pollVotes[key] as int : int.tryParse(pollVotes[key]?.toString() ?? '0') ?? 0;
        pollVotes[key] = current + 1;
        tx.update(postRef, {'pollVotes': pollVotes});
      });
      print('✅ Vote cast for choice $choiceIndex on $postId');
    } catch (e) {
      print('❌ castVote error: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _firestore
        .collection('gist_comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final batch = _firestore.batch();
    try {
      final commentRef = _firestore.collection('gist_comments').doc();
      final now = FieldValue.serverTimestamp();
      final user = _auth.currentUser;
      final userId = user?.uid ?? '';
      // Attempt to fetch displayName quickly, fallback gracefully
      String displayName = 'Unknown';
      String username = 'unknown';
      String profilePic = '';
      if (userId.isNotEmpty) {
        final udoc = await _firestore.collection('users').doc(userId).get();
        if (udoc.exists) {
          displayName = udoc.data()?['displayName']?.toString() ?? displayName;
          username = udoc.data()?['username']?.toString() ?? username;
          profilePic = udoc.data()?['profilePicUrl']?.toString() ?? '';
        }
      }

      batch.set(commentRef, {
        'postId': postId,
        'userId': userId,
        'displayName': displayName,
        'username': username,
        'profilePic': profilePic,
        'text': text,
        'createdAt': now,
      });

      final postRef = _firestore.collection('gist_posts').doc(postId);
      batch.update(postRef, {'commentCount': FieldValue.increment(1)});

      await batch.commit();
      print('✅ Comment added to $postId');
    } catch (e) {
      print('❌ addComment error: $e');
      rethrow;
    }
  }
}
