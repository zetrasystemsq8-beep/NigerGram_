// lib/features/gist_hub/data/services/audio_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/gist_hub/domain/entities/audio_post_entity.dart';

class AudioService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<AudioPostEntity>> getAudioFeedStream({required String filter}) {
    Query<Map<String, dynamic>> query = _firestore.collection('audio_posts');

    switch (filter) {
      case 'trending':
        query = query.orderBy('trendingScore', descending: true).limit(50);
        break;
      case 'rising':
        query = query.orderBy('createdAt', descending: true).limit(50);
        break;
      case 'idea':
      case 'educational':
      case 'motivation':
      case 'story':
      case 'original':
        query = query.where('category', isEqualTo: filter).orderBy('createdAt', descending: true).limit(50);
        break;
      default:
        query = query.orderBy('createdAt', descending: true).limit(50);
    }

    return query
        .snapshots()
        .map((snap) => snap.docs.map((d) => AudioPostEntity.fromMap(d.data(), d.id)).toList())
        .asBroadcastStream();
  }

  Stream<AudioPostEntity?> getAudioPostStream(String audioId) {
    return _firestore
        .collection('audio_posts')
        .doc(audioId)
        .snapshots()
        .map((doc) => doc.exists ? AudioPostEntity.fromMap(doc.data()!, doc.id) : null)
        .asBroadcastStream();
  }

  Stream<List<Map<String, dynamic>>> getVideosUsingAudioStream(String audioId) {
    return _firestore
        .collection('innovations')
        .where('audioId', isEqualTo: audioId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .asBroadcastStream();
  }

  Future<AudioPostEntity> createAudioPost({
    required File audioFile,
    required String title,
    required AudioCategory category,
    required AudioPermission permission,
    required int durationSeconds,
    int trimStartMs = 0,
    int? trimEndMs,
    VoiceEffect voiceEffect = VoiceEffect.normal,
  }) async {
    final userId = AppAuth.uid;
    if (userId.isEmpty) throw Exception('Not logged in');

    String creatorUsername = AppAuth.isLoggedIn ? AppAuth.displayHandle : 'unknown';
    String creatorDisplayName = creatorUsername;
    String creatorProfilePic = '';

    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      final d = userDoc.data()!;
      creatorDisplayName = d['displayName']?.toString() ?? creatorDisplayName;
      creatorUsername = d['username']?.toString() ?? creatorUsername;
      creatorProfilePic = d['profilePicUrl']?.toString() ?? '';
    }

    final filePath = 'recordings/${userId}_${DateTime.now().millisecondsSinceEpoch}.wav';
    final bytes = await audioFile.readAsBytes();
    await _supabase.storage.from('audio').uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(contentType: 'audio/wav', upsert: true),
        );
    final audioUrl = _supabase.storage.from('audio').getPublicUrl(filePath);

    final docRef = _firestore.collection('audio_posts').doc();
    await docRef.set({
      'creatorId': userId,
      'creatorUsername': creatorUsername,
      'creatorDisplayName': creatorDisplayName,
      'creatorProfilePic': creatorProfilePic,
      'title': title,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'category': audioCategoryToString(category),
      'permission': audioPermissionToString(permission),
      'approvedUserIds': <String>[],
      'useCount': 0,
      'trendingScore': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'trimStartMs': trimStartMs,
      'trimEndMs': trimEndMs ?? durationSeconds * 1000,
      // Non-destructive voice effect — the file always stores the raw
      // recording; playback engines apply this pitch live via setPitch().
      'voiceEffect': voiceEffectToString(voiceEffect),
    });

    final snap = await docRef.get();
    return AudioPostEntity.fromMap(snap.data()!, snap.id);
  }

  Future<void> registerAudioUse(String audioId) async {
    final userId = AppAuth.uid;
    if (userId.isEmpty) throw Exception('Not logged in');

    final docRef = _firestore.collection('audio_posts').doc(audioId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Audio not found');

      final entity = AudioPostEntity.fromMap(snap.data()!, snap.id);
      if (!entity.canBeUsedBy(userId)) {
        throw Exception('This audio isn\'t available for reuse.');
      }

      tx.update(docRef, {
        'useCount': FieldValue.increment(1),
        'trendingScore': FieldValue.increment(3),
      });
    });
  }

  Future<void> updatePermission({
    required String audioId,
    required AudioPermission permission,
    List<String>? approvedUserIds,
  }) async {
    final userId = AppAuth.uid;
    final docRef = _firestore.collection('audio_posts').doc(audioId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Audio not found');
    if (snap.data()?['creatorId'] != userId) {
      throw Exception('Only the creator can change this audio\'s permissions');
    }

    await docRef.update({
      'permission': audioPermissionToString(permission),
      if (approvedUserIds != null) 'approvedUserIds': approvedUserIds,
    });
  }

  Future<void> reportAudio({
    required String audioId,
    required String reason,
    String? details,
  }) async {
    final userId = AppAuth.uid;
    await _firestore.collection('audio_reports').add({
      'audioId': audioId,
      'reportedBy': userId,
      'reason': reason,
      'details': details ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  Future<void> saveAudioForCurrentUser(String audioId) async {
    final userId = AppAuth.uid;
    if (userId.isEmpty) throw Exception('Not logged in');

    await _firestore.collection('users').doc(userId).set({
      'savedAudioIds': FieldValue.arrayUnion([audioId]),
    }, SetOptions(merge: true));
  }
}
