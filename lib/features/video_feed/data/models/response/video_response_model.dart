import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';

class VideoResponseModel {
  final String id;
  final String username;
  final String description;
  final String? videoKey;
  final String? legacyVideoUrl;
  final String profileImageUrl;
  final String? category;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime timestamp;

  const VideoResponseModel({
    required this.id,
    required this.username,
    required this.description,
    this.videoKey,
    this.legacyVideoUrl,
    required this.profileImageUrl,
    this.category,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.timestamp,
  });

  factory VideoResponseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parsedDate = DateTime.now();
    if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
      parsedDate = (data['timestamp'] as Timestamp).toDate();
    }

    return VideoResponseModel(
      id: doc.id,
      username: data['username'] as String? ?? '',
      description: data['description'] as String? ?? '',
      videoKey: data['videoKey'] as String?,
      legacyVideoUrl: data['videoUrl'] as String?,
      profileImageUrl: data['profileImageUrl'] as String? ?? '',
      category: data['category'] as String?,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      shareCount: (data['shareCount'] as num?)?.toInt() ?? 0,
      timestamp: parsedDate,
    );
  }

  VideoEntity toEntity() {
    return VideoEntity(
      id: id,
      username: username,
      description: description,
      videoKey: videoKey,
      legacyVideoUrl: legacyVideoUrl,
      profileImageUrl: profileImageUrl,
      category: category,
      likeCount: likeCount,
      commentCount: commentCount,
      shareCount: shareCount,
      timestamp: timestamp,
    );
  }
}
