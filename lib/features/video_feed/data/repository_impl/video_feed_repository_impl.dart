import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_video_feed/features/video_feed/data/models/response/video_response_model.dart';
import 'package:flutter_video_feed/features/video_feed/domain/entities/video_entity.dart';
import 'package:flutter_video_feed/features/video_feed/domain/repositories/video_feed_repository.dart';
import 'package:fpdart/fpdart.dart';

class VideoFeedRepositoryImpl implements VideoFeedRepository {
  VideoFeedRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;
  DocumentSnapshot? _lastDocument;
  
  // Confined payload envelope to strictly regulate data transmission limits
  static const int _pageSize = 10;

  @override
  Future<Either<String, List<VideoEntity>>> fetchVideos() async {
    try {
      _lastDocument = null;
      return await _fetchVideosHelper();
    } on FirebaseException catch (e) {
      return Left('Failed to fetch videos: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      return const Left('An unexpected error occurred while fetching videos');
    }
  }

  @override
  Future<Either<String, List<VideoEntity>>> fetchMoreVideos() async {
    if (_lastDocument == null) {
      return const Right([]);
    }
    try {
      return await _fetchVideosHelper(startAfterDocument: _lastDocument);
    } on FirebaseException catch (e) {
      return Left(
          'Failed to fetch more videos: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      return const Left(
          'An unexpected error occurred while fetching more videos');
    }
  }

  /// Low-Data Assisted Retrieval Helper Architecture
  Future<Either<String, List<VideoEntity>>> _fetchVideosHelper({
    DocumentSnapshot? startAfterDocument,
  }) async {
    try {
      Query query = _firestore
          .collection('videos')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      QuerySnapshot snapshot;
      try {
        // Enforce a server-first query behavior to secure fresh document lineages
        snapshot = await query.get(const GetOptions(source: Source.server));
      } on FirebaseException catch (e) {
        // Institutional-grade network fallback: If the user has zero signal or a dropped packet,
        // seamlessly parse historical metadata cache records instead of displaying a blank error state.
        if (e.code == 'unavailable') {
          snapshot = await query.get(const GetOptions(source: Source.cache));
        } else {
          rethrow;
        }
      }

      if (snapshot.docs.isEmpty) {
        return const Right([]);
      }

      _lastDocument = snapshot.docs.last;

      final videos = snapshot.docs
          .map((doc) => VideoResponseModel.fromFirestore(doc).toEntity())
          .toList();

      return Right(videos);
    } on FirebaseException catch (e) {
      return Left('Firestore error: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      return const Left('Error processing video data');
    }
  }
}
