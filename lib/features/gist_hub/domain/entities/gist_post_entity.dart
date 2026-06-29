// lib/features/gist_hub/domain/entities/gist_post_entity.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum GistType {
  text,
  image,
  poll,
  announcement,
}

enum GistPollStatus {
  none,
  eligible,
  votingActive,
  expired,
}

enum GistAnnouncementType {
  none,
  pollWinner,
  moderator,
  system,
}

class GistPostEntity {
  final String id;
  final String userId;
  final String displayName;
  final String username;
  final String profilePic;
  final GistType gistType; 
  final String content;
  final String? imageUrl;
  final List<String> pollOptions;
  final Map<String, int> pollVotes;
  
  /// Explicitly maps: userId -> selectedOptionIndex
  final Map<String, int> pollVoters; 
  
  /// Explicitly maps: reactionType -> count
  final Map<String, int> reactions; 
  final int commentCount;
  final Timestamp? createdAt;
  final Timestamp? expiresAt;
  final bool isAnonymous;

  // Trackers for Engine Processing
  final int shareCount;
  final int bookmarkCount;
  final int uniqueEngagedUsers;
  final int pollRequestsCount;
  final GistPollStatus pollStatus;
  final GistAnnouncementType announcementType;
  final Map<String, int>? finalPollResults;
  
  /// Explicit relational link pointing back to the original source debate thread
  final String? sourcePostId;

  GistPostEntity({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.username,
    required this.profilePic,
    required this.gistType,
    required this.content,
    this.imageUrl,
    this.pollOptions = const [],
    this.pollVotes = const {},
    this.pollVoters = const {},
    this.reactions = const {},
    this.commentCount = 0,
    this.createdAt,
    this.expiresAt,
    this.isAnonymous = false,
    this.shareCount = 0,
    this.bookmarkCount = 0,
    this.uniqueEngagedUsers = 0,
    this.pollRequestsCount = 0,
    this.pollStatus = GistPollStatus.none,
    this.announcementType = GistAnnouncementType.none,
    this.finalPollResults,
    this.sourcePostId,
  });

  /// Dynamically computes total reactions on-demand to prevent data desynchronization
  int get totalReactionCount => reactions.values.fold(0, (sum, value) => sum + value);

  GistPostEntity copyWith({
    String? id,
    String? userId,
    String? displayName,
    String? username,
    String? profilePic,
    GistType? gistType,
    String? content,
    String? imageUrl,
    List<String>? pollOptions,
    Map<String, int>? pollVotes,
    Map<String, int>? pollVoters,
    Map<String, int>? reactions,
    int? commentCount,
    Timestamp? createdAt,
    Timestamp? expiresAt,
    bool? isAnonymous,
    int? shareCount,
    int? bookmarkCount,
    int? uniqueEngagedUsers,
    int? pollRequestsCount,
    GistPollStatus? pollStatus,
    GistAnnouncementType? announcementType,
    Map<String, int>? finalPollResults,
    String? sourcePostId,
  }) {
    return GistPostEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      profilePic: profilePic ?? this.profilePic,
      gistType: gistType ?? this.gistType,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      pollOptions: pollOptions ?? this.pollOptions,
      pollVotes: pollVotes ?? this.pollVotes,
      pollVoters: pollVoters ?? this.pollVoters,
      reactions: reactions ?? this.reactions,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      shareCount: shareCount ?? this.shareCount,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      uniqueEngagedUsers: uniqueEngagedUsers ?? this.uniqueEngagedUsers,
      pollRequestsCount: pollRequestsCount ?? this.pollRequestsCount,
      pollStatus: pollStatus ?? this.pollStatus,
      announcementType: announcementType ?? this.announcementType,
      finalPollResults: finalPollResults ?? this.finalPollResults,
      sourcePostId: sourcePostId ?? this.sourcePostId,
    );
  }

  factory GistPostEntity.fromMap(Map<String, dynamic> map, String id) {
    final typeString = map['gistType'] ?? map['type'] ?? 'text'; // Handle fallback during migration window
    final GistType parsedType = GistType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => GistType.text,
    );

    final statusString = map['pollStatus'] ?? 'none';
    final GistPollStatus parsedStatus = GistPollStatus.values.firstWhere(
      (e) => e.name == statusString,
      orElse: () => GistPollStatus.none,
    );

    final announcementString = map['announcementType'] ?? 'none';
    final GistAnnouncementType parsedAnnouncement = GistAnnouncementType.values.firstWhere(
      (e) => e.name == announcementString,
      orElse: () => GistAnnouncementType.none,
    );

    return GistPostEntity(
      id: id,
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? 'Anonymous',
      username: map['username'] ?? 'user',
      profilePic: map['profilePic'] ?? '',
      gistType: parsedType,
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      pollOptions: List<String>.from(map['pollOptions'] ?? []),
      pollVotes: Map<String, int>.from(map['pollVotes'] ?? {}),
      pollVoters: Map<String, int>.from(map['pollVoters'] ?? {}),
      reactions: Map<String, int>.from(map['reactions'] ?? {}),
      commentCount: map['commentCount'] ?? 0,
      createdAt: map['createdAt'] as Timestamp?,
      expiresAt: map['expiresAt'] as Timestamp?,
      isAnonymous: map['isAnonymous'] ?? false,
      shareCount: map['shareCount'] ?? 0,
      bookmarkCount: map['bookmarkCount'] ?? 0,
      uniqueEngagedUsers: map['uniqueEngagedUsers'] ?? 0,
      pollRequestsCount: map['pollRequestsCount'] ?? 0,
      pollStatus: parsedStatus,
      announcementType: parsedAnnouncement,
      finalPollResults: map['finalPollResults'] != null 
          ? Map<String, int>.from(map['finalPollResults']) 
          : null,
      sourcePostId: map['sourcePostId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'username': username,
      'profilePic': profilePic,
      'gistType': gistType.name,
      'content': content,
      'imageUrl': imageUrl,
      'pollOptions': pollOptions,
      'pollVotes': pollVotes,
      'pollVoters': pollVoters,
      'reactions': reactions,
      'commentCount': commentCount,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'isAnonymous': isAnonymous,
      'shareCount': shareCount,
      'bookmarkCount': bookmarkCount,
      'uniqueEngagedUsers': uniqueEngagedUsers,
      'pollRequestsCount': pollRequestsCount,
      'pollStatus': pollStatus.name,
      'announcementType': announcementType.name,
      'finalPollResults': finalPollResults,
      'sourcePostId': sourcePostId,
    };
  }
}
