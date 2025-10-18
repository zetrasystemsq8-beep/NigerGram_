import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:flutter_video_feed/features/video_feed/domain/usecases/fetch_more_videos_usecase.dart';
import 'package:flutter_video_feed/features/video_feed/domain/usecases/fetch_videos_usecase.dart';
import 'package:flutter_video_feed/features/video_feed/presentation/bloc/video_feed_state.dart';

class VideoFeedCubit extends Cubit<VideoFeedState> {
  VideoFeedCubit({
    required FetchVideosUseCase fetchVideosUseCase,
    required FetchMoreVideosUseCase fetchMoreVideosUseCase,
  })  : _fetchVideosUseCase = fetchVideosUseCase,
        _fetchMoreVideosUseCase = fetchMoreVideosUseCase,
        super(VideoFeedState.initial()) {
    loadVideos();
  }

  final FetchVideosUseCase _fetchVideosUseCase;
  final FetchMoreVideosUseCase _fetchMoreVideosUseCase;
  final _preloadQueue = Queue<String>();
  final _preloadedFiles = <String, File>{};
  bool _isPreloadingMore = false;

  Future<void> loadVideos() async {
    emit(state.copyWith(isLoading: true, errorMessage: ''));

    final result = await _fetchVideosUseCase();

    result.fold(
      (error) {
        emit(state.copyWith(
          isLoading: false,
          isSuccess: false,
          errorMessage: error,
        ));
      },
      (videos) {
        final hasMoreVideos = videos.length == 2;
        emit(state.copyWith(
          isLoading: false,
          isSuccess: true,
          videos: videos,
          hasMoreVideos: hasMoreVideos,
          currentIndex: 0,
          errorMessage: '',
        ));

        // Start preloading next videos after initial load
        if (videos.isNotEmpty) {
          preloadNextVideos();
        }
      },
    );
  }

  Future<void> loadMoreVideos() async {
    if (state.isPaginating || !state.hasMoreVideos) return;

    emit(state.copyWith(isPaginating: true, errorMessage: ''));

    final result = await _fetchMoreVideosUseCase();

    result.fold(
      (error) {
        emit(state.copyWith(
          isPaginating: false,
          errorMessage: error,
        ));
      },
      (moreVideos) {
        final hasMoreVideos = moreVideos.length == 2;
        final updatedVideos = [...state.videos, ...moreVideos];

        emit(state.copyWith(
          videos: updatedVideos,
          isPaginating: false,
          hasMoreVideos: hasMoreVideos,
          errorMessage: '',
        ));

        // Preload new videos after loading more
        preloadNextVideos();
      },
    );
  }

  Future<void> onPageChanged(int newIndex) async {
    emit(state.copyWith(currentIndex: newIndex));

    // Start preloading next videos
    await preloadNextVideos();

    // Smart pagination trigger
    if (!_isPreloadingMore && state.hasMoreVideos && newIndex >= state.videos.length - 2) {
      _isPreloadingMore = true;
      await loadMoreVideos();
      _isPreloadingMore = false;
    }
  }

  Future<void> preloadNextVideos() async {
    if (state.videos.isEmpty) return;

    final currentIndex = state.currentIndex;
    final videosToPreload = state.videos
        .skip(currentIndex + 1)
        .take(2)
        .map((v) => v.videoUrl)
        .where((url) => !_preloadedFiles.containsKey(url));

    for (final videoUrl in videosToPreload) {
      if (!_preloadQueue.contains(videoUrl)) {
        _preloadQueue.add(videoUrl);
        await _preloadVideo(videoUrl);
      }
    }
  }

  Future<void> _preloadVideo(String videoUrl) async {
    try {
      final file = await getCachedVideoFile(videoUrl);
      _preloadedFiles[videoUrl] = file;

      final currentPreloaded = Set<String>.from(state.preloadedVideoUrls)..add(videoUrl);
      emit(state.copyWith(preloadedVideoUrls: currentPreloaded));
    } catch (e) {
      debugPrint('Error preloading video: $e');
    } finally {
      _preloadQueue.remove(videoUrl);
    }
  }

  Future<File> getCachedVideoFile(String videoUrl) async {
    if (_preloadedFiles.containsKey(videoUrl)) {
      return _preloadedFiles[videoUrl]!;
    }

    final cacheManager = DefaultCacheManager();
    final fileInfo = await cacheManager.getFileFromCache(videoUrl);
    final file = fileInfo?.file ?? await cacheManager.getSingleFile(videoUrl);
    _preloadedFiles[videoUrl] = file;
    return file;
  }

  @override
  Future<void> close() {
    _preloadQueue.clear();
    _preloadedFiles.clear();
    return super.close();
  }
}
