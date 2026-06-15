import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import 'package:nigergram/features/video_feed/data/models/response/video_response_model.dart' as model;
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:nigergram/features/video_feed/domain/repositories/video_feed_repository.dart';

/// Institutional-grade Repository implementation for NigerGram.
/// Optimized for low-data environments with precise pagination control.
class VideoFeedRepositoryImpl implements VideoFeedRepository {
  VideoFeedRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;
  
  /// Tracking reference for cursor-based pagination to prevent duplicate data.
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  @override
  Future<Either<String, List<VideoEntity>>> fetchVideos() async {
    try {
      // Reset pagination cursor for fresh initialization
      _lastDocument = null;
      return await _fetchVideosHelper();
    } on FirebaseException catch (e) {
      return Left('NigerGram Engine Error (Firebase): ${e.message ?? 'Access Denied'}');
    } catch (e) {
      return const Left('An unexpected error occurred during initial feed sync');
    }
  }

  @override
  Future<Either<String, List<VideoEntity>>> fetchMoreVideos() async {
    // Prevent redundant calls if we've reached the end of the collection
    if (_lastDocument == null) {
      return const Right([]);
    }
    try {
      return await _fetchVideosHelper(startAfterDocument: _lastDocument);
    } on FirebaseException catch (e) {
      return Left('Failed to scale feed: ${e.message ?? 'Unknown network error'}');
    } catch (e) {
      return const Left('Unexpected failure during pagination');
    }
  }

  /// Refined helper using high-fidelity mapping and error boundaries.
  /// Enforces ordering by 'timestamp' while allowing for 'null' safety on new documents.
  Future<Either<String, List<VideoEntity>>> _fetchVideosHelper({
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    try {
      // Define query with institutional constraints (Limit 10 for data optimization)
      Query<Map<String, dynamic>> query = _firestore
          .collection('videos')
          .orderBy('timestamp', descending: true);

      // Apply pagination cursor
      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      // Apply limit after ordering
      query = query.limit(10);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        return const Right([]);
      }

      // Update the cursor to the last document in the current batch
      _lastDocument = snapshot.docs.last;

      // Transform raw Firestore data into Domain Entities via the Response Model
      final List<VideoEntity> videos = snapshot.docs.map<VideoEntity>((doc) {
        try {
          return model.VideoResponseModel.fromFirestore(doc).toEntity();
        } catch (e) {
          // Log and skip malformed documents to prevent entire feed crashes
          print('NigerGram Data Warning: Malformed video document ${doc.id}');
          return null;
        }
      }).whereType<VideoEntity>().toList();

      return Right(videos);
    } on FirebaseException catch (e) {
      // Catching missing index or permission errors specifically
      if (e.code == 'failed-precondition') {
        return const Left('Firestore Index required. Check Firebase console.');
      }
      return Left('Sync Error: ${e.message}');
    } catch (e) {
      return const Left('Data processing failed. Check VideoEntity mapping.');
    }
  }
}
