import 'package:cloud_firestore/cloud_firestore.dart';

class GistPostEntity {
  final String id;
  final String userId;
  final String displayName;
  final String username;
  final String profilePic;
  final String type;
  final String content;
  final String? imageUrl;
  final List<String> pollOptions;
  final Map<String, int> pollVotes;
  final Map<String, int> pollVoters;
  final Map<String, int> reactions;
  final int commentCount;
  final Timestamp? createdAt;
  final Timestamp? expiresAt;
  final bool isAnonymous;
  final int totalReactions;

  GistPostEntity({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.username,
    required this.profilePic,
    required this.type,
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
    this.totalReactions = 0,
  });

  factory GistPostEntity.fromMap(Map<String, dynamic> map, String id) {
    return GistPostEntity(
      id: id,
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? 'Anonymous',
      username: map['username'] ?? 'user',
      profilePic: map['profilePic'] ?? '',
      type: map['type'] ?? 'text',
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
      totalReactions: map['totalReactions'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'username': username,
      'profilePic': profilePic,
      'type': type,
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
      'totalReactions': totalReactions,
    };
  }
}
