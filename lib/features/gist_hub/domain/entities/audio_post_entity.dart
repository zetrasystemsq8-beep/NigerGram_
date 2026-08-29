// lib/features/gist_hub/domain/entities/audio_post_entity.dart
import 'package:flutter/material.dart';

enum AudioPermission { private, approvedUsers, public }

enum AudioCategory { educational, idea, motivation, story, original }

enum VoiceEffect { normal, deep, high }

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

VoiceEffect voiceEffectFromString(String? value) {
  switch (value) {
    case 'deep':
      return VoiceEffect.deep;
    case 'high':
      return VoiceEffect.high;
    default:
      return VoiceEffect.normal;
  }
}

String voiceEffectToString(VoiceEffect effect) {
  switch (effect) {
    case VoiceEffect.deep:
      return 'deep';
    case VoiceEffect.high:
      return 'high';
    case VoiceEffect.normal:
      return 'normal';
  }
}

/// Non-destructive pitch multiplier — applied live at playback time via
/// just_audio's setPitch(), never baked into the actual audio file.
double voiceEffectPitch(VoiceEffect effect) {
  switch (effect) {
    case VoiceEffect.deep:
      return 0.8;
    case VoiceEffect.high:
      return 1.3;
    case VoiceEffect.normal:
      return 1.0;
  }
}

String voiceEffectLabel(VoiceEffect effect) {
  switch (effect) {
    case VoiceEffect.deep:
      return '🔉 Deep';
    case VoiceEffect.high:
      return '🔊 High';
    case VoiceEffect.normal:
      return '🎤 Normal';
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

  final int trimStartMs;
  final int trimEndMs;
  final VoiceEffect voiceEffect;

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
    this.voiceEffect = VoiceEffect.normal,
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
      voiceEffect: voiceEffectFromString(map['voiceEffect']?.toString()),
    );
  }

  Duration get trimStart => Duration(milliseconds: trimStartMs);
  Duration get trimEnd => Duration(milliseconds: trimEndMs);
  Duration get trimmedDuration => trimEnd - trimStart;

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
