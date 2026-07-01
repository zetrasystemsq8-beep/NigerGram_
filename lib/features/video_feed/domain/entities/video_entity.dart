// lib/features/video_feed/domain/entities/video_entity.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoEntity {
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
  final bool? isLiked;
  final bool? isBookmarked;
  final bool? isFollowing;
  final bool? isVerified;
  final bool? isPremium;
  final DateTime createdAt;

  VideoEntity({
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
    this.isLiked = false,
    this.isBookmarked = false,
    this.isFollowing = false,
    this.isVerified = false,
    this.isPremium = false,
    required this.createdAt,
  });

  factory VideoEntity.fromFirestore(
    DocumentSnapshot doc, {
    bool? isLiked,
    bool? isBookmarked,
    bool? isFollowing,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoEntity(
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
      isLiked: isLiked ?? false,
      isBookmarked: isBookmarked ?? false,
      isFollowing: isFollowing ?? false,
      isVerified: data['isVerified'] ?? false,
      isPremium: data['isPremium'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  VideoEntity copyWith({
    String? id,
    String? videoUrl,
    String? creatorId,
    String? username,
    String? profileImageUrl,
    String? description,
    String? soundName,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? viewCount,
    int? loopCount,
    bool? isLiked,
    bool? isBookmarked,
    bool? isFollowing,
    bool? isVerified,
    bool? isPremium,
    DateTime? createdAt,
  }) {
    return VideoEntity(
      id: id ?? this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      creatorId: creatorId ?? this.creatorId,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      description: description ?? this.description,
      soundName: soundName ?? this.soundName,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      viewCount: viewCount ?? this.viewCount,
      loopCount: loopCount ?? this.loopCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isFollowing: isFollowing ?? this.isFollowing,
      isVerified: isVerified ?? this.isVerified,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'videoUrl': videoUrl,
      'creatorId': creatorId,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'description': description,
      'soundName': soundName,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'viewCount': viewCount,
      'loopCount': loopCount,
      'isVerified': isVerified,
      'isPremium': isPremium,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
