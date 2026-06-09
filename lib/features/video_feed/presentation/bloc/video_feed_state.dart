import 'package:equatable/equatable.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';

class VideoFeedState extends Equatable {
  const VideoFeedState({
    this.isLoading = false,
    this.isSuccess = false,
    this.isPaginating = false,
    this.hasMoreVideos = true,
    this.errorMessage = '',
    this.videos = const [],
    this.currentIndex = 0,
    this.preloadedVideoUrls = const {},
  });

  final bool isLoading;
  final bool isSuccess;
  final bool isPaginating;
  final bool hasMoreVideos;
  final String errorMessage;
  final List<VideoEntity> videos;
  final int currentIndex;
  final Set<String> preloadedVideoUrls;

  @override
  List<Object?> get props => [
        isLoading,
        isSuccess,
        isPaginating,
        hasMoreVideos,
        errorMessage,
        videos,
        currentIndex,
        preloadedVideoUrls,
      ];

  VideoFeedState copyWith({
    bool? isLoading,
    bool? isSuccess,
    bool? isPaginating,
    bool? hasMoreVideos,
    String? errorMessage,
    List<VideoEntity>? videos,
    int? currentIndex,
    Set<String>? preloadedVideoUrls,
  }) {
    return VideoFeedState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      isPaginating: isPaginating ?? this.isPaginating,
      hasMoreVideos: hasMoreVideos ?? this.hasMoreVideos,
      errorMessage: errorMessage ?? this.errorMessage,
      videos: videos ?? this.videos,
      currentIndex: currentIndex ?? this.currentIndex,
      preloadedVideoUrls: preloadedVideoUrls ?? this.preloadedVideoUrls,
    );
  }

  factory VideoFeedState.initial() => const VideoFeedState();
}
