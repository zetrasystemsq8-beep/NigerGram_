import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nigergram/features/gist_hub/domain/entities/gist_post_entity.dart';

class GistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get feed stream - no ordering to avoid index errors
  Stream<List<Map<String, dynamic>>> getGistFeedStream({required String filter}) {
    return _firestore
        .collection('gist_posts')
        .snapshots()
        .map((snap) {
          return snap.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              ...data,
            };
          }).toList();
        });
  }

  Future<void> createPost({
    required String type,
    required String content,
    File? imageFile,
    List<String>? pollOptions,
    bool isAnonymous = false,
  }) async {
    try {
      final user = _auth.currentUser;
      String userId = user?.uid ?? '';
      String displayName = user?.displayName ?? 'Anonymous';
      String username = user?.email?.split('@').first ?? 'anonymous';
      String profilePic = '';

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

      // 🔥 FIX: Use Supabase for images
      String? imageUrl;
      if (imageFile != null) {
        try {
          final String filePath = 'gist_images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
          
          final bytes = await imageFile.readAsBytes();
          await _supabase.storage
              .from('images')
              .uploadBinary(
                filePath,
                bytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
          
          imageUrl = _supabase.storage
              .from('images')
              .getPublicUrl(filePath);
              
        } catch (e) {
          print('❌ Image upload error: $e');
          imageUrl = null;
        }
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
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addReaction({
    required String postId,
    required String emoji,
  }) async {
    final postRef = _firestore.collection('gist_posts').doc(postId);
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
    } catch (e) {
      rethrow;
    }
  }

  Future<void> castVote({
    required String postId,
    required int choiceIndex,
  }) async {
    final postRef = _firestore.collection('gist_posts').doc(postId);
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
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _firestore
        .collection('gist_comments')
        .where('postId', isEqualTo: postId)
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
        'isAnonymous': false,
      });

      final postRef = _firestore.collection('gist_posts').doc(postId);
      batch.update(postRef, {'commentCount': FieldValue.increment(1)});

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}
