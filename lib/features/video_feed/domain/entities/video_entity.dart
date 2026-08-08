/// Institutional-grade Domain Entity for NigerGram Video Feed.
/// Updated to remove thumbnailUrl to match the new database schema.
///
/// Storage migration note: Firestore now stores only the object key
/// (e.g. "videos/abc123.mp4") in a `videoKey` field, per the "never
/// store full URLs" rule — the playable URL is built at read time via
/// MediaRepository.publicUrlFor(videoKey). Older documents created
/// before this migration still have a full `videoUrl` field instead;
/// [videoUrl] here transparently returns the right thing either way,
/// so no existing video breaks.
import 'package:nigergram/features/media/repository/media_repository.dart';

class VideoEntity {
  final String id;
  final String username;
  final String description;
  final String? videoKey; // new videos: B2 object key only
  final String? legacyVideoUrl; // old videos: full URL, pre-migration
  final String profileImageUrl;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime timestamp;
  final bool? isLiked;
  final bool? isBookmarked;
  final String? creatorId;

  const VideoEntity({
    required this.id,
    required this.username,
    required this.description,
    this.videoKey,
    this.legacyVideoUrl,
    required this.profileImageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.timestamp,
    this.isLiked,
    this.isBookmarked,
    this.creatorId,
  });

  /// The actual playable URL, regardless of which schema this document
  /// used. Prefers the new B2 key; falls back to the old stored URL
  /// for videos uploaded before the storage migration.
  String get videoUrl {
    if (videoKey != null && videoKey!.isNotEmpty) {
      return MediaRepository.publicUrlFor(videoKey!);
    }
    return legacyVideoUrl ?? '';
  }

  factory VideoEntity.fromMap(String id, Map<String, dynamic> data) {
    return VideoEntity(
      id: id,
      username: data['username'] as String? ?? '',
      description: data['description'] as String? ?? '',
      videoKey: data['videoKey'] as String?,
      legacyVideoUrl: data['videoUrl'] as String?,
      profileImageUrl: data['profileImageUrl'] as String? ?? '',
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      shareCount: (data['shareCount'] as num?)?.toInt() ?? 0,
      timestamp: (data['timestamp'] is DateTime)
          ? data['timestamp'] as DateTime
          : DateTime.now(),
      isLiked: data['isLiked'] as bool?,
      isBookmarked: data['isBookmarked'] as bool?,
      creatorId: data['creatorId'] as String?,
    );
  }
}
