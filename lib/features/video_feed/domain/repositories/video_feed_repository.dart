import 'package:flutter_video_feed/features/video_feed/domain/entities/video_entity.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class VideoFeedRepository {
  /// Fetch the initial batch of video items.
  /// Returns Either<String, List<VideoEntity>> where:
  /// - Left: Error message
  /// - Right: List of videos
  Future<Either<String, List<VideoEntity>>> fetchVideos();

  /// Fetch additional videos for pagination.
  /// Returns Either<String, List<VideoEntity>> where:
  /// - Left: Error message
  /// - Right: List of videos
  Future<Either<String, List<VideoEntity>>> fetchMoreVideos();
}
