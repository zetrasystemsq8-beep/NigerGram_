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

      // --- NIGERGRAM UPGRADE: Institutional-Grade Data Joining ---
      List<VideoEntity> videos = [];

      for (var doc in snapshot.docs) {
        final videoData = VideoResponseModel.fromFirestore(doc);
        final videoEntity = videoData.toEntity();

        // Fetch the creator's real data from the 'users' collection
        final userDoc = await _firestore.collection('users').doc(videoEntity.userId).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          
          // Inject the real user data into the video entity
          // We use copyWith (assuming your VideoEntity has it) to keep it immutable
          videos.add(videoEntity.copyWith(
            username: userData['username'] ?? 'nigergram_user',
            userImageUrl: userData['profilePicUrl'] ?? '',
          ));
        } else {
          // Fallback if user document is missing
          videos.add(videoEntity.copyWith(username: 'naija_creator'));
        }
      }

      return Right(videos);
    } on FirebaseException catch (e) {
      return Left('Firestore error: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      return const Left('Error processing video data and user profiles');
    }
  }
}
