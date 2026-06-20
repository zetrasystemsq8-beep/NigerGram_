import 'package:fpdart/fpdart.dart';
import 'package:nigergram/features/profile/domain/entities/user_video_entity.dart';
import 'package:nigergram/features/profile/domain/repositories/profile_repository.dart';

class FetchSavedVideosUseCase {
  FetchSavedVideosUseCase({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  Future<Either<String, List<UserVideoEntity>>> call({
    required String userId,
    required int limit,
    String? startAfterVideoId,
  }) async {
    return _repository.fetchSavedVideos(
      userId: userId,
      limit: limit,
      startAfterVideoId: startAfterVideoId,
    );
  }
}
