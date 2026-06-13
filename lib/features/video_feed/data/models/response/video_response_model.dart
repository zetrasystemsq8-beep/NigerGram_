import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';

class VideoResponseModel {
  final String id;
  final String username;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String profileImageUrl;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime timestamp;

  const VideoResponseModel({
    required this.id,
    required this.username,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.profileImageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.timestamp,
  });

  /// Factory constructor to safely parse incoming Firestore documents.
  /// Includes strong type protection and defensive fallbacks to prevent crashes.
  factory VideoResponseModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    // Safely handle Firestore Timestamp mappings
    DateTime parsedDate = DateTime.now();
    if (data['timestamp'] != null) {
      if (data['timestamp'] is Timestamp) {
        parsedDate = (data['timestamp'] as Timestamp).toDate();
      } else if (data['timestamp'] is String) {
        parsedDate = DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now();
      }
    }

    return VideoResponseModel(
      id: doc.id,
      username: data['username'] as String? ?? '',
      description: data['description'] as String? ?? '',
      videoUrl: data['videoUrl'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      profileImageUrl: data['profileImageUrl'] as String? ?? '',
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      shareCount: (data['shareCount'] as num?)?.toInt() ?? 0,
      timestamp: parsedDate,
    );
  }

  /// Transforms the Data Layer Model into the Domain Layer Entity.
  VideoEntity toEntity() {
    return VideoEntity(
      id: id,
      username: username,
      description: description,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      profileImageUrl: profileImageUrl,
      likeCount: likeCount,
      commentCount: commentCount,
      shareCount: shareCount,
      timestamp: timestamp,
    );
  }
}
