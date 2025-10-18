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
  final String profileImageUrl;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final Timestamp timestamp;

  /// Factory constructor from JSON
  factory VideoResponseModel.fromJson(Map<String, dynamic> json) =>
      _$VideoResponseModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$VideoResponseModelToJson(this);

  /// Factory constructor to create a VideoResponseModel from a Firestore DocumentSnapshot
  factory VideoResponseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return VideoResponseModel(
      id: doc.id,
      username: data['username'] is String ? data['username'] as String : '',
      description: data['description'] is String ? data['description'] as String : '',
      videoUrl: data['videoUrl'] is String ? data['videoUrl'] as String : '',
      profileImageUrl: data['profileImageUrl'] is String ? data['profileImageUrl'] as String : '',
      likeCount: _safeInt(data['likeCount']),
      commentCount: _safeInt(data['commentCount']),
      shareCount: _safeInt(data['shareCount']),
      timestamp: data['timestamp'] is Timestamp ? data['timestamp'] as Timestamp : Timestamp.now(),
    );
  }

  /// Convert to domain entity
  VideoEntity toEntity() {
    return VideoEntity(
      id: id,
      username: username,
      description: description,
      videoUrl: videoUrl,
      profileImageUrl: profileImageUrl,
      likeCount: likeCount,
      commentCount: commentCount,
      shareCount: shareCount,
      timestamp: timestamp.toDate(),
    );
  }

  /// Helper for JSON serialization of Timestamp
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

  /// Helper for JSON deserialization of Timestamp
  static Map<String, dynamic> _timestampToJson(Timestamp timestamp) {
    return {
      '_seconds': timestamp.seconds,
      '_nanoseconds': timestamp.nanoseconds,
    };
  }
}

/// Helper function to safely convert a dynamic value to an int
int _safeInt(dynamic value, {int defaultValue = 0}) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}
