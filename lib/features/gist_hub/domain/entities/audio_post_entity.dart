// lib/features/gist_hub/domain/entities/audio_post_entity.dart
import 'package:flutter/material.dart';

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

Color audioCategoryColor(AudioCategory category) {
  switch (category) {
    case AudioCategory.idea:
      return const Color(0xFFFFC107);
    case AudioCategory.motivation:
      return const Color(0xFFFF5252);
    case AudioCategory.story:
      return const Color(0xFF9C27B0);
    case AudioCategory.original:
      return const Color(0xFF00C853);
    case AudioCategory.educational:
      return const Color(0xFF2196F3);
  }
}

String audioCategoryEmoji(AudioCategory category) {
  switch (category) {
    case AudioCategory.idea:
      return '💡';
    case AudioCategory.motivation:
      return '🔥';
    case AudioCategory.story:
      return '📖';
    case AudioCategory.original:
      return '🎙️';
    case AudioCategory.educational:
      return '📚';
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

  // Non-destructive trim points — the underlying audio file always
  // contains the full original recording; every playback surface
  // (preview, detail page, published post) is expected to start
  // exactly at trimStartMs and stop exactly at trimEndMs, so it plays
  // back as if the file itself had been physically cut.
  final int trimStartMs;
  final int trimEndMs;

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
    this.trimStartMs = 0,
    int? trimEndMs,
  }) : trimEndMs = trimEndMs ?? durationSeconds * 1000;

  factory AudioPostEntity.fromMap(Map<String, dynamic> map, String id) {
    final durationSeconds = (map['durationSeconds'] as num?)?.toInt() ?? 0;
    return AudioPostEntity(
      id: id,
      creatorId: map['creatorId']?.toString() ?? '',
      creatorUsername: map['creatorUsername']?.toString() ?? '',
      creatorDisplayName: map['creatorDisplayName']?.toString() ?? '',
      creatorProfilePic: map['creatorProfilePic']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      audioUrl: map['audioUrl']?.toString() ?? '',
      durationSeconds: durationSeconds,
      category: audioCategoryFromString(map['category']?.toString()),
      permission: audioPermissionFromString(map['permission']?.toString()),
      approvedUserIds: List<String>.from(map['approvedUserIds'] ?? []),
      useCount: (map['useCount'] as num?)?.toInt() ?? 0,
      trendingScore: (map['trendingScore'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null && map['createdAt'] is! String
          ? (map['createdAt'] as dynamic).toDate()
          : null,
      trimStartMs: (map['trimStartMs'] as num?)?.toInt() ?? 0,
      trimEndMs: (map['trimEndMs'] as num?)?.toInt() ?? durationSeconds * 1000,
    );
  }

  Duration get trimStart => Duration(milliseconds: trimStartMs);
  Duration get trimEnd => Duration(milliseconds: trimEndMs);
  Duration get trimmedDuration => trimEnd - trimStart;

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
