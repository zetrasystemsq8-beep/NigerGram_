// lib/features/gist_hub/domain/entities/audio_post_entity.dart

enum AudioPermission { private, approvedUsers, public }

enum AudioCategory { educational, idea, motivation, story, original }

AudioPermission audioPermissionFromString(String? value) {
  switch (value) {
    case 'approved_users':
      return AudioPermission.approvedUsers;
    case 'public':
      return AudioPermission.public;
    default:
      return AudioPermission.private;
  }
}

String audioPermissionToString(AudioPermission permission) {
  switch (permission) {
    case AudioPermission.approvedUsers:
      return 'approved_users';
    case AudioPermission.public:
      return 'public';
    case AudioPermission.private:
      return 'private';
  }
}

AudioCategory audioCategoryFromString(String? value) {
  switch (value) {
    case 'idea':
      return AudioCategory.idea;
    case 'motivation':
      return AudioCategory.motivation;
    case 'story':
      return AudioCategory.story;
    case 'original':
      return AudioCategory.original;
    default:
      return AudioCategory.educational;
  }
}

String audioCategoryToString(AudioCategory category) {
  switch (category) {
    case AudioCategory.idea:
      return 'idea';
    case AudioCategory.motivation:
      return 'motivation';
    case AudioCategory.story:
      return 'story';
    case AudioCategory.original:
      return 'original';
    case AudioCategory.educational:
      return 'educational';
  }
}

class AudioPostEntity {
  final String id;
  final String creatorId;
  final String creatorUsername;
  final String creatorDisplayName;
  final String creatorProfilePic;
  final String title;
  final String audioUrl;
  final int durationSeconds;
  final AudioCategory category;
  final AudioPermission permission;
  final List<String> approvedUserIds;
  final int useCount;
  final int trendingScore;
  final DateTime? createdAt;

  const AudioPostEntity({
    required this.id,
    required this.creatorId,
    required this.creatorUsername,
    required this.creatorDisplayName,
    required this.creatorProfilePic,
    required this.title,
    required this.audioUrl,
    required this.durationSeconds,
    required this.category,
    required this.permission,
    required this.approvedUserIds,
    required this.useCount,
    required this.trendingScore,
    required this.createdAt,
  });

  factory AudioPostEntity.fromMap(Map<String, dynamic> map, String id) {
    return AudioPostEntity(
      id: id,
      creatorId: map['creatorId']?.toString() ?? '',
      creatorUsername: map['creatorUsername']?.toString() ?? '',
      creatorDisplayName: map['creatorDisplayName']?.toString() ?? '',
      creatorProfilePic: map['creatorProfilePic']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      audioUrl: map['audioUrl']?.toString() ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      category: audioCategoryFromString(map['category']?.toString()),
      permission: audioPermissionFromString(map['permission']?.toString()),
      approvedUserIds: List<String>.from(map['approvedUserIds'] ?? []),
      useCount: (map['useCount'] as num?)?.toInt() ?? 0,
      trendingScore: (map['trendingScore'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null && map['createdAt'] is! String
          ? (map['createdAt'] as dynamic).toDate()
          : null,
    );
  }

  /// Whether [userId] is allowed to reuse this audio in their own post.
  bool canBeUsedBy(String userId) {
    if (creatorId == userId) return true;
    switch (permission) {
      case AudioPermission.public:
        return true;
      case AudioPermission.approvedUsers:
        return approvedUserIds.contains(userId);
      case AudioPermission.private:
        return false;
    }
  }
}
