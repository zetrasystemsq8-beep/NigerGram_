import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_video_feed/features/video_feed/domain/entities/video_entity.dart';
import 'package:json_annotation/json_annotation.dart';

part 'video_response_model.g.dart';

@JsonSerializable()
class VideoResponseModel {
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

  final String id;
  final String username;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String profileImageUrl;
  final int likeCount;
  final int commentCount;
  final int shareCount;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final Timestamp timestamp;

  factory VideoResponseModel.fromJson(Map<String, dynamic> json) =>
      _$VideoResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$VideoResponseModelToJson(this);

  factory VideoResponseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return VideoResponseModel(
      id: doc.id,
      username: data['username'] is String ? data['username'] as String : '',
      description: data['description'] is String ? data['description'] as String : '',
      videoUrl: data['videoUrl'] is String ? data['videoUrl'] as String : '',
      thumbnailUrl: data['thumbnailUrl'] is String ? data['thumbnailUrl'] as String : '',
      profileImageUrl: data['profileImageUrl'] is String ? data['profileImageUrl'] as String : '',
      likeCount: _safeInt(data['likeCount']),
      commentCount: _safeInt(data['commentCount']),
      shareCount: _safeInt(data['shareCount']),
      timestamp: data['timestamp'] is Timestamp
          ? data['timestamp'] as Timestamp
          : Timestamp.now(),
    );
  }

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
      timestamp: timestamp.toDate(),
    );
  }

  static Timestamp _timestampFromJson(dynamic json) {
    if (json is Timestamp) return json;

    if (json is Map) {
      return Timestamp(
        json['_seconds'] as int? ?? 0,
        json['_nanoseconds'] as int? ?? 0,
      );
    }

    return Timestamp.now();
  }

  static Map<String, dynamic> _timestampToJson(Timestamp timestamp) {
    return {
      '_seconds': timestamp.seconds,
      '_nanoseconds': timestamp.nanoseconds,
    };
  }
}

int _safeInt(dynamic value, {int defaultValue = 0}) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}
