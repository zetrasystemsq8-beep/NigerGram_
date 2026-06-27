import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nigergram/features/gist_hub/domain/entities/gist_post_entity.dart';

class GistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> getGistFeedStream({required String filter}) {
    Query<Map<String, dynamic>> query = _firestore.collection('gist_posts');

    if (filter == 'trending') {
      query = query.orderBy('totalReactions', descending: true);
    } else if (filter == 'polls') {
      query = query.where('type', isEqualTo: 'poll');
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    return query.limit(50).snapshots().map((snap) {
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
      
      final expiryDate = DateTime.now().add(const Duration(days: 7));
      final int optionCount = pollOptions?.length ?? 0;
      final Map<String, int> initialPollVotes = {};
      for (int i = 0; i < optionCount; i++) {
        initialPollVotes[i.toString()] = 0;
      }
      final Map<String, int> initialPollVoters = {};
      
      final initialReactions = {
        "😂": 0,
        "😱": 0,
        "👀": 0,
        "🥴": 0,
        "🇳🇬": 0,
      };

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
        'pollVoters': initialPollVoters,
        'reactions': initialReactions,
        'commentCount': 0,
        'createdAt': now,
        'expiresAt': type == 'poll' ? Timestamp.fromDate(expiryDate) : null,
        'isAnonymous': isAnonymous,
        'totalReactions': 0,
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
        final reactions = Map<String, int>.from(data['reactions'] ?? {});
        reactions[emoji] = (reactions[emoji] ?? 0) + 1;
        
        int total = 0;
        reactions.forEach((key, value) {
          total += value;
        });
        
        tx.update(postRef, {
          'reactions': reactions,
          'totalReactions': total,
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  // 🔥 FIXED: Correct vote logic with pollVoters
  Future<void> castVote({
    required String postId,
    required int choiceIndex,
  }) async {
    final postRef = _firestore.collection('gist_posts').doc(postId);
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (!snapshot.exists) throw Exception('Post not found');
        
        final data = snapshot.data() as Map<String, dynamic>;
        
        // Check if user already voted
        final voters = Map<String, int>.from(data['pollVoters'] ?? {});
        if (voters.containsKey(user.uid)) {
          throw Exception('You already voted');
        }
        
        // Update vote counts
        final pollVotes = Map<String, int>.from(data['pollVotes'] ?? {});
        final key = choiceIndex.toString();
        pollVotes[key] = (pollVotes[key] ?? 0) + 1;
        
        // Store who voted
        voters[user.uid] = choiceIndex;
        
        transaction.update(postRef, {
          'pollVotes': pollVotes,
          'pollVoters': voters,
        });
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
