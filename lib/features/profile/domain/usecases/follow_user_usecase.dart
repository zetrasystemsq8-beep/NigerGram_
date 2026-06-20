import 'package:fpdart/fpdart.dart';
import 'package:nigergram/features/profile/domain/repositories/profile_repository.dart';

class FollowUserUseCase {
  FollowUserUseCase({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  Future<Either<String, void>> call(String targetUserId) async {
    return _repository.followUser(targetUserId);
  }
}
