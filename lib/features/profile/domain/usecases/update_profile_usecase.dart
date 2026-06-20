import 'package:fpdart/fpdart.dart';
import 'package:nigergram/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfileUseCase {
  UpdateProfileUseCase({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  Future<Either<String, void>> call({
    required String displayName,
    required String username,
    required String bio,
    required String profilePictureUrl,
    required String bannerUrl,
    required bool isPrivate,
    required bool allowMessages,
    required bool allowCollaborations,
    Map<String, String>? socialLinks,
  }) async {
    return _repository.updateProfile(
      displayName: displayName,
      username: username,
      bio: bio,
      profilePictureUrl: profilePictureUrl,
      bannerUrl: bannerUrl,
      isPrivate: isPrivate,
      allowMessages: allowMessages,
      allowCollaborations: allowCollaborations,
      socialLinks: socialLinks,
    );
  }
}
