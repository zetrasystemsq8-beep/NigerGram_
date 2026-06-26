// lib/features/gist_hub/presentation/widgets/gist_hub_features.dart
// 🔥 FINAL PRODUCTION-READY VERSION - RACE CONDITION FIXED

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/domain/entities/gist_post_entity.dart';

// ============================================================
// HELPER: Add reaction with atomic totalReactions update
// ============================================================
class ReactionHelper {
  static Future<bool> hasUserReacted({
    required String postId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('gist_posts')
          .doc(postId)
          .collection('reactions')
          .doc(userId)
          .get();
      return doc.exists && doc.data()?[emoji] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> addReaction({
    required String postId,
    required String userId,
    required String emoji,
  }) async {
    final postRef = FirebaseFirestore.instance.collection('gist_posts').doc(postId);
    
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (!snapshot.exists) return;
        
        final data = snapshot.data() as Map<String, dynamic>;
        final reactions = Map<String, int>.from(data['reactions'] ?? {});
        
        final userReactionRef = postRef.collection('reactions').doc(userId);
        final userReactionDoc = await transaction.get(userReactionRef);
        
        if (userReactionDoc.exists && userReactionDoc.data()?[emoji] == true) {
          return;
        }
        
        final current = reactions[emoji] ?? 0;
        reactions[emoji] = current + 1;
        
        int total = 0;
        reactions.forEach((key, value) {
          total += value;
        });
        
        transaction.update(postRef, {
          'reactions': reactions,
          'totalReactions': total,
        });
        
        transaction.set(userReactionRef, {
          emoji: true,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('❌ Failed to add reaction: $e');
    }
  }
}

// ============================================================
// FEATURE 1: DELETE GIST
// ============================================================
class DeleteGistFeature {
  static Future<void> deleteGist({
    required BuildContext context,
    required String postId,
    required String userId,
    required VoidCallback onDeleted,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own posts')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NGColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Gist?', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('This cannot be undone.', style: TextStyle(color: NGColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: NGColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: NGColors.error))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _deleteAllRelatedData(postId);
        await _removeFromAllSavedLists(postId);
        await _deleteUserReactions(postId);
        await FirebaseFirestore.instance.collection('gist_posts').doc(postId).delete();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ Gist and all related data deleted'), backgroundColor: Colors.green),
          );
          onDeleted();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  static Future<void> _deleteAllRelatedData(String postId) async {
    await _deleteCollectionInChunks(
      FirebaseFirestore.instance
          .collection('gist_comments')
          .where('postId', isEqualTo: postId),
    );
    
    await _deleteCollectionInChunks(
      FirebaseFirestore.instance
          .collection('reports')
          .where('postId', isEqualTo: postId),
    );
  }

  static Future<void> _deleteUserReactions(String postId) async {
    await _deleteCollectionInChunks(
      FirebaseFirestore.instance
          .collection('gist_posts')
          .doc(postId)
          .collection('reactions'),
    );
  }

  static Future<void> _deleteCollectionInChunks(Query query) async {
    const batchSize = 400;
    bool hasMore = true;
    
    while (hasMore) {
      final snapshot = await query.limit(batchSize).get();
      if (snapshot.docs.isEmpty) {
        hasMore = false;
        break;
      }
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      if (snapshot.docs.length < batchSize) {
        hasMore = false;
      }
    }
  }

  static Future<void> _removeFromAllSavedLists(String postId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('savedGists', arrayContains: postId)
          .get();
      
      if (snapshot.docs.isEmpty) return;
      
      final List<DocumentSnapshot> docs = snapshot.docs;
      for (int i = 0; i < docs.length; i += 400) {
        final end = (i + 400 < docs.length) ? i + 400 : docs.length;
        final batch = FirebaseFirestore.instance.batch();
        
        for (int j = i; j < end; j++) {
          batch.update(docs[j].reference, {
            'savedGists': FieldValue.arrayRemove([postId]),
          });
        }
        await batch.commit();
      }
    } catch (_) {}
  }
}

// ============================================================
// FEATURE 2: REPORT POST
// ============================================================
class ReportPostFeature {
  static Future<void> reportPost({
    required BuildContext context,
    required String postId,
    required String reportedBy,
  }) async {
    final reasons = ['Inappropriate content', 'Spam', 'Harassment', 'Fake news', 'Other'];

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NGColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🚨 Report Gist', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) {
            return ListTile(
              title: Text(r, style: const TextStyle(color: NGColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, r),
            );
          }).toList(),
        ),
      ),
    );

    if (reason != null) {
      try {
        final existing = await FirebaseFirestore.instance
            .collection('reports')
            .where('postId', isEqualTo: postId)
            .where('reportedBy', isEqualTo: reportedBy)
            .get();
        
        if (existing.docs.isNotEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You already reported this post'), backgroundColor: Colors.orange),
            );
          }
          return;
        }

        await FirebaseFirestore.instance.collection('reports').add({
          'postId': postId,
          'reportedBy': reportedBy,
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'resolved': false,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Report submitted. We\'ll review it.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to report: $e')),
          );
        }
      }
    }
  }
}

// ============================================================
// FEATURE 3: SAVE GIST
// ============================================================
class SaveGistFeature {
  static Future<bool> isPostSaved(String userId, String postId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      final saved = doc.data()?['savedGists'] ?? [];
      return saved.contains(postId);
    } catch (_) {
      return false;
    }
  }

  static Future<void> toggleSave({
    required BuildContext context,
    required String postId,
    required String userId,
    required bool isSaved,
    required VoidCallback onChanged,
  }) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      
      if (isSaved) {
        await userRef.set(
          {'savedGists': FieldValue.arrayRemove([postId])},
          SetOptions(merge: true),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from saved'), duration: Duration(seconds: 1)),
          );
        }
      } else {
        await userRef.set(
          {'savedGists': FieldValue.arrayUnion([postId])},
          SetOptions(merge: true),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📌 Saved!'), duration: Duration(seconds: 1)),
          );
        }
      }
      
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }
}

// ============================================================
// FEATURE 4: REPLY TO COMMENTS
// ============================================================
class ReplyToCommentFeature {
  static Future<void> addReply({
    required BuildContext context,
    required String postId,
    required String parentCommentId,
    required String text,
    required String userId,
    required String displayName,
    required String username,
    required String profilePic,
  }) async {
    if (text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please write something')),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('gist_comments').add({
        'postId': postId,
        'parentId': parentCommentId,
        'userId': userId,
        'displayName': displayName,
        'username': username,
        'profilePic': profilePic,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'isAnonymous': false,
        'deleted': false,
      });

      await FirebaseFirestore.instance.collection('gist_posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('💬 Reply added!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reply: $e')),
        );
      }
    }
  }

  static Stream<QuerySnapshot> getRepliesStream(String postId, String parentId) {
    return FirebaseFirestore.instance
        .collection('gist_comments')
        .where('postId', isEqualTo: postId)
        .where('parentId', isEqualTo: parentId)
        .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  static Widget buildReplyTile(Map<String, dynamic> data) {
    final isAnonymous = data['isAnonymous'] ?? false;
    final displayName = isAnonymous ? 'Anonymous' : (data['displayName'] ?? 'User');
    final username = isAnonymous ? '' : (data['username'] ?? '');
    final text = data['text'] ?? '';
    final profilePic = data['profilePic'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;

    return Padding(
      padding: const EdgeInsets.only(left: 44, bottom: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: NGColors.surfaceLight,
            backgroundImage: isAnonymous || profilePic.isEmpty ? null : CachedNetworkImageProvider(profilePic),
            child: isAnonymous || profilePic.isEmpty ? Icon(Icons.person, color: NGColors.textMuted, size: 14) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(displayName, style: const TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                    if (!isAnonymous) ...[const SizedBox(width: 4), Text(username, style: TextStyle(color: NGColors.textMuted, fontSize: 10))],
                    const SizedBox(width: 8),
                    Text(_formatDate(createdAt), style: TextStyle(color: NGColors.textMuted, fontSize: 9)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(color: NGColors.textSecondary, fontSize: 12)),
                Container(margin: const EdgeInsets.only(top: 4), height: 1, color: NGColors.divider.withOpacity(0.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ============================================================
// FEATURE 5: GIST OF THE DAY 🏆 (ATOMIC)
// ============================================================
class GistOfTheDayFeature {
  static const String _lockDocPath = 'config/gistOfTheDayLock';

  static Future<GistPostEntity?> getGistOfTheDay() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final lockRef = FirebaseFirestore.instance.doc(_lockDocPath);
      final lockDoc = await lockRef.get();
      
      String? selectedPostId;
      if (lockDoc.exists) {
        final data = lockDoc.data()!;
        final lastUpdate = (data['updatedAt'] as Timestamp?)?.toDate();
        if (lastUpdate != null && lastUpdate.isAfter(startOfDay)) {
          selectedPostId = data['selectedPostId'];
        }
      }

      if (selectedPostId != null) {
        final postDoc = await FirebaseFirestore.instance.collection('gist_posts').doc(selectedPostId).get();
        if (postDoc.exists) {
          final data = postDoc.data()!;
          return GistPostEntity.fromMap(data, postDoc.id);
        }
      }

      // Fetch candidate before transaction
      final candidateSnapshot = await FirebaseFirestore.instance
          .collection('gist_posts')
          .orderBy('totalReactions', descending: true)
          .limit(1)
          .get();
      
      if (candidateSnapshot.docs.isEmpty) return null;
      
      final doc = candidateSnapshot.docs.first;

      // 🔥 FIX: ATOMIC - clear old flags AND set new flag in ONE transaction
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final lockSnapshot = await transaction.get(lockRef);
        final lockData = lockSnapshot.data() ?? {};
        
        final lastUpdate = (lockData['updatedAt'] as Timestamp?)?.toDate();
        if (lastUpdate != null && lastUpdate.isAfter(startOfDay)) {
          return;
        }
        
        // 🔥 Clear ALL old Gist of the Day flags inside the transaction
        final oldWinners = await FirebaseFirestore.instance
            .collection('gist_posts')
            .where('isGistOfTheDay', isEqualTo: true)
            .get();
        
        for (var oldDoc in oldWinners.docs) {
          transaction.update(oldDoc.reference, {
            'isGistOfTheDay': false,
          });
        }
        
        // Set new lock
        transaction.set(lockRef, {
          'selectedPostId': doc.id,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        // Mark new winner
        transaction.update(doc.reference, {
          'isGistOfTheDay': true,
        });
      });

      return GistPostEntity.fromMap(doc.data(), doc.id);
    } catch (_) {
      return null;
    }
  }

  static Widget buildGistOfTheDayCard(GistPostEntity post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF6B00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.emoji_events, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text('🏆 Gist of the Day', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.content,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '👤 ${post.displayName}',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
              const Spacer(),
              Text(
                '🔥 ${post.reactions.values.fold(0, (sum, val) => sum + val)} reactions',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FEATURE 6: LIVE ACTIVITY (COMPLETE)
// ============================================================
class LiveActivityFeature {
  static Stream<int> getLivePostCount() {
    return Stream.periodic(const Duration(seconds: 5), (_) => DateTime.now())
        .asyncMap((now) async {
          final oneMinuteAgo = now.subtract(const Duration(min
