import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import 'package:nigergram/features/video_feed/data/models/response/video_response_model.dart' hide VideoEntity;
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:nigergram/features/video_feed/domain/repositories/video_feed_repository.dart';

class VideoFeedRepositoryImpl implements VideoFeedRepository {
  VideoFeedRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;
  DocumentSnapshot? _lastDocument;

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

  Future<Either<String, List<VideoEntity>>> _fetchVideosHelper({
    DocumentSnapshot? startAfterDocument,
  }) async {
    try {
      Query query = _firestore
          .collection('videos')
          .orderBy('timestamp', descending: true)
          .limit(10);

      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      final snapshot = await query.get();

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
