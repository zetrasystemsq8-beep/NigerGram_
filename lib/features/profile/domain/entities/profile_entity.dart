import 'package:equatable/equatable.dart';

class ProfileEntity extends Equatable {
  const ProfileEntity({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.profilePictureUrl,
    required this.bannerUrl,
    required this.followers,
    required this.following,
    required this.totalLikes,
    required this.totalVideos,
    required this.totalViews,
    required this.isVerified,
    required this.verificationBadge,
    required this.createdAt,
    required this.updatedAt,
    required this.isPrivate,
    required this.allowMessages,
    required this.allowCollaborations,
    this.socialLinks = const {},
    this.achievements = const [],
    this.badges = const [],
  });

  final String userId;
  final String username;
  final String displayName;
  final String bio;
  final String profilePictureUrl;
  final String bannerUrl;
  final int followers;
  final int following;
  final int totalLikes;
  final int totalVideos;
  final int totalViews;
  final bool isVerified;
  final String verificationBadge;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPrivate;
  final bool allowMessages;
  final bool allowCollaborations;
  final Map<String, String> socialLinks;
  final List<String> achievements;
  final List<String> badges;

  @override
  List<Object?> get props => [
    userId,
    username,
    displayName,
    bio,
    profilePictureUrl,
    bannerUrl,
    followers,
    following,
    totalLikes,
    totalVideos,
    totalViews,
    isVerified,
    verificationBadge,
    createdAt,
    updatedAt,
    isPrivate,
    allowMessages,
    allowCollaborations,
    socialLinks,
    achievements,
    badges,
  ];

  ProfileEntity copyWith({
    String? userId,
    String? username,
    String? displayName,
    String? bio,
    String? profilePictureUrl,
    String? bannerUrl,
    int? followers,
    int? following,
    int? totalLikes,
    int? totalVideos,
    int? totalViews,
    bool? isVerified,
    String? verificationBadge,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPrivate,
    bool? allowMessages,
    bool? allowCollaborations,
    Map<String, String>? socialLinks,
    List<String>? achievements,
    List<String>? badges,
  }) {
    return ProfileEntity(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      totalLikes: totalLikes ?? this.totalLikes,
      totalVideos: totalVideos ?? this.totalVideos,
      totalViews: totalViews ?? this.totalViews,
      isVerified: isVerified ?? this.isVerified,
      verificationBadge: verificationBadge ?? this.verificationBadge,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPrivate: isPrivate ?? this.isPrivate,
      allowMessages: allowMessages ?? this.allowMessages,
      allowCollaborations: allowCollaborations ?? this.allowCollaborations,
      socialLinks: socialLinks ?? this.socialLinks,
      achievements: achievements ?? this.achievements,
      badges: badges ?? this.badges,
    );
  }
}
