import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:nigergram/features/video_feed/domain/usecases/fetch_more_videos_usecase.dart';
import 'package:nigergram/features/video_feed/domain/usecases/fetch_videos_usecase.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_state.dart';

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
  
  final _preloadedFiles = <String, File>{};
  final Set<String> _activeDownloads = {};
  
  bool _isPreloadingMore = false;

  /// Custom Cache Manager with Strict Data Aging
  /// This ensures we don't clog the user's storage while keeping data local.
  static final CacheManager _lowDataCacheManager = CacheManager(
    Config(
      'nigergram_video_cache',
      stalePeriod: const Duration(days: 2), // Keep for 2 days to save repeat data
      maxNrOfCacheObjects: 20, // Limit total stored videos
      repo: JsonCacheInfoRepository(databaseName: 'nigergram_video_cache'),
      fileService: HttpFileService(),
    ),
  );

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
        // Assume page size is 10 for pagination check
        final hasMoreVideos = videos.length >= 10;
        emit(state.copyWith(
          isLoading: false,
          isSuccess: true,
          videos: videos,
          hasMoreVideos: hasMoreVideos,
          currentIndex: 0,
          errorMessage: '',
        ));

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
        final hasMoreVideos = moreVideos.length >= 10;
        final updatedVideos = [...state.videos, ...moreVideos];

        emit(state.copyWith(
          videos: updatedVideos,
          isPaginating: false,
          hasMoreVideos: hasMoreVideos,
          errorMessage: '',
        ));

        preloadNextVideos();
      },
    );
  }

  Future<void> onPageChanged(int newIndex) async {
    emit(state.copyWith(currentIndex: newIndex));

    // Cancel old distant preloads and focus on the immediate next
    await preloadNextVideos();

    // Trigger pagination when 3 videos are left
    if (!_isPreloadingMore && state.hasMoreVideos && newIndex >= state.videos.length - 3) {
      _isPreloadingMore = true;
      await loadMoreVideos();
      _isPreloadingMore = false;
    }
  }

  /// Low-Data Preload Logic:
  /// Only allows ONE video to download at a time to prevent bandwidth saturation.
  Future<void> preloadNextVideos() async {
    if (state.videos.isEmpty) return;

    final currentIndex = state.currentIndex;
    
    // We only ever preload the NEXT video. Preloading 2 or 3 is a data waste in Nigeria.
    final nextIndex = currentIndex + 1;
    if (nextIndex >= state.videos.length) return;

    final videoUrl = state.videos[nextIndex].videoUrl;

    // Skip if already in memory, already cached on disk, or currently downloading
    if (_preloadedFiles.containsKey(videoUrl) || _activeDownloads.contains(videoUrl)) {
      return;
    }

    await _preloadVideo(videoUrl);
  }

  Future<void> _preloadVideo(String videoUrl) async {
    if (_activeDownloads.length >= 1) return; // Strict lock: 1 download at a time

    try {
      _activeDownloads.add(videoUrl);
      
      // We check cache first without triggering a download
      final fileInfo = await _lowDataCacheManager.getFileFromCache(videoUrl);
      
      if (fileInfo != null) {
        _preloadedFiles[videoUrl] = fileInfo.file;
      } else {
        // Only download if it's NOT in cache
        final file = await _lowDataCacheManager.getSingleFile(videoUrl);
        _preloadedFiles[videoUrl] = file;
      }

      final currentPreloaded = Set<String>.from(state.preloadedVideoUrls)..add(videoUrl);
      emit(state.copyWith(preloadedVideoUrls: currentPreloaded));
    } catch (e) {
      debugPrint('Data-Saving Preload Failed: $e');
    } finally {
      _activeDownloads.remove(videoUrl);
    }
  }

  /// The Gatekeeper for Data Consumption
  Future<File> getCachedVideoFile(String videoUrl) async {
    // 1. Return immediate memory reference if available
    if (_preloadedFiles.containsKey(videoUrl)) {
      return _preloadedFiles[videoUrl]!;
    }

    // 2. Check disk cache
    final fileInfo = await _lowDataCacheManager.getFileFromCache(videoUrl);
    if (fileInfo != null) {
      _preloadedFiles[videoUrl] = fileInfo.file;
      return fileInfo.file;
    }

    // 3. Last resort: Download. 
    // This only happens if the user swipes faster than the preload.
    final file = await _lowDataCacheManager.getSingleFile(videoUrl);
    _preloadedFiles[videoUrl] = file;
    return file;
  }

  @override
  Future<void> close() {
    _preloadedFiles.clear();
    _activeDownloads.clear();
    return super.close();
  }
}
