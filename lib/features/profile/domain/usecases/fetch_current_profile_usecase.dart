import 'package:fpdart/fpdart.dart';
import 'package:nigergram/features/profile/domain/entities/profile_entity.dart';
import 'package:nigergram/features/profile/domain/repositories/profile_repository.dart';

class FetchCurrentProfileUseCase {
  FetchCurrentProfileUseCase({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  Future<Either<String, ProfileEntity>> call() async {
    return _repository.fetchCurrentProfile();
  }
}
