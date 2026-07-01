// lib/features/video_feed/data/models/response/video_response_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';

class VideoResponseModel {
  final String id;
  final String videoUrl;
  final String creatorId;
  final String username;
  final String? profileImageUrl;
  final String description;
  final String? soundName;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int viewCount;
  final int loopCount;
  final bool? isVerified;
  final bool? isPremium;
  final DateTime createdAt;

  VideoResponseModel({
    required this.id,
    required this.videoUrl,
    required this.creatorId,
    required this.username,
    this.profileImageUrl,
    required this.description,
    this.soundName,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.viewCount = 0,
    this.loopCount = 0,
    this.isVerified = false,
    this.isPremium = false,
    required this.createdAt,
  });

  factory VideoResponseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoResponseModel(
      id: doc.id,
      videoUrl: data['videoUrl'] ?? '',
      creatorId: data['creatorId'] ?? '',
      username: data['username'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      description: data['description'] ?? '',
      soundName: data['soundName'],
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      loopCount: data['loopCount'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      isPremium: data['isPremium'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  VideoEntity toEntity({
    bool? isLiked,
    bool? isBookmarked,
    bool? isFollowing,
  }) {
    return VideoEntity(
      id: id,
      videoUrl: videoUrl,
      creatorId: creatorId,
      username: username,
      profileImageUrl: profileImageUrl,
      description: description,
      soundName: soundName,
      likeCount: likeCount,
      commentCount: commentCount,
      shareCount: shareCount,
      viewCount: viewCount,
      loopCount: loopCount,
      isLiked: isLiked ?? false,
      isBookmarked: isBookmarked ?? false,
      isFollowing: isFollowing ?? false,
      isVerified: isVerified ?? false,
      isPremium: isPremium ?? false,
      createdAt: createdAt,
    );
  }
}
