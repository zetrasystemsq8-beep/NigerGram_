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
  final Map<String, int> reactions;
  final int commentCount;
  final Timestamp? createdAt; // 👈 FIX: Made nullable
  final bool isAnonymous;

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
    this.reactions = const {},
    this.commentCount = 0,
    this.createdAt, // 👈 FIX: Removed 'required'
    this.isAnonymous = false,
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
      reactions: Map<String, int>.from(map['reactions'] ?? {}),
      commentCount: map['commentCount'] ?? 0,
      createdAt: map['createdAt'] as Timestamp?,
      isAnonymous: map['isAnonymous'] ?? false,
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
      'reactions': reactions,
      'commentCount': commentCount,
      'createdAt': createdAt,
      'isAnonymous': isAnonymous,
    };
  }
}
