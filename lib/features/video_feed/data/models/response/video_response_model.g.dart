// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideoResponseModel _$VideoResponseModelFromJson(Map<String, dynamic> json) =>
    VideoResponseModel(
      id: json['id'] as String,
      username: json['username'] as String,
      description: json['description'] as String,
      videoUrl: json['videoUrl'] as String,
      profileImageUrl: json['profileImageUrl'] as String,
      likeCount: (json['likeCount'] as num).toInt(),
      commentCount: (json['commentCount'] as num).toInt(),
      shareCount: (json['shareCount'] as num).toInt(),
      timestamp: VideoResponseModel._timestampFromJson(json['timestamp']),
    );

Map<String, dynamic> _$VideoResponseModelToJson(VideoResponseModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'description': instance.description,
      'videoUrl': instance.videoUrl,
      'profileImageUrl': instance.profileImageUrl,
      'likeCount': instance.likeCount,
      'commentCount': instance.commentCount,
      'shareCount': instance.shareCount,
      'timestamp': VideoResponseModel._timestampToJson(instance.timestamp),
    };
