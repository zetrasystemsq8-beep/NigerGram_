import 'package:fpdart/fpdart.dart';
import 'package:nigergram/features/profile/domain/entities/profile_entity.dart';
import 'package:nigergram/features/profile/domain/entities/user_video_entity.dart';

abstract class ProfileRepository {
  /// Fetch current user's profile
  Future<Either<String, ProfileEntity>> fetchCurrentProfile();

  /// Fetch another user's profile by userId
  Future<Either<String, ProfileEntity>> fetchUserProfile(String userId);

  /// Update current user's profile
  Future<Either<String, void>> updateProfile({
    required String displayName,
    required String username,
    required String bio,
    required String profilePictureUrl,
    required String bannerUrl,
    required bool isPrivate,
    required bool allowMessages,
    required bool allowCollaborations,
    Map<String, String>? socialLinks,
  });

  /// Fetch user's videos with pagination
  Future<Either<String, List<UserVideoEntity>>> fetchUserVideos({
    required String userId,
    required int limit,
    String? startAfterVideoId,
  });

  /// Fetch user's liked videos
  Future<Either<String, List<UserVideoEntity>>> fetchLikedVideos({
    required String userId,
    required int limit,
    String? startAfterVideoId,
  });

  /// Fetch user's saved videos (bookmarks)
  Future<Either<String, List<UserVideoEntity>>> fetchSavedVideos({
    required String userId,
    required int limit,
    String? startAfterVideoId,
  });

  /// Follow a user
  Future<Either<String, void>> followUser(String targetUserId);

  /// Unfollow a user
  Future<Either<String, void>> unfollowUser(String targetUserId);

  /// Check if following a user
  Future<Either<String, bool>> isFollowing(String targetUserId);

  /// Get followers list
  Future<Either<String, List<String>>> getFollowersList(String userId);

  /// Get following list
  Future<Either<String, List<String>>> getFollowingList(String userId);

  /// Block a user
  Future<Either<String, void>> blockUser(String targetUserId);

  /// Unblock a user
  Future<Either<String, void>> unblockUser(String targetUserId);

  /// Get user analytics
  Future<Either<String, Map<String, dynamic>>> getUserAnalytics(String userId);

  /// Report a profile
  Future<Either<String, void>> reportProfile(String targetUserId, String reason);
}
