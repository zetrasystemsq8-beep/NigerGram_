import 'package:fpdart/fpdart.dart';
import 'package:nigergram/features/profile/domain/entities/profile_entity.dart';
import 'package:nigergram/features/profile/domain/repositories/profile_repository.dart';

class FetchUserProfileUseCase {
  FetchUserProfileUseCase({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  Future<Either<String, ProfileEntity>> call(String userId) async {
    return _repository.fetchUserProfile(userId);
  }
}
