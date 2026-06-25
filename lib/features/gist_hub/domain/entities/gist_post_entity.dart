// lib/features/gist_hub/domain/entities/gist_post_entity.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class GistPostEntity {
  final String id;
  final String userId;
  final String displayName;
  final String username;
  final String profilePic;
  final String type; // 'text' | 'image' | 'poll'
  final String content;
  final String? imageUrl;
  final List<String>? pollOptions; // exactly 2 choices when type == 'poll'
  final Map<String, int> pollVotes; // choiceIndex -> votes, stored as {"0": 3, "1": 5}
  final Map<String, int> reactions; // keys: "😂", "😱", "👀", "🥴", "🇳🇬"
  final int commentCount;
  final Timestamp createdAt;
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
    this.pollOptions,
    Map<String, int>? pollVotes,
    Map<String, int>? reactions,
    required this.commentCount,
    required this.createdAt,
    required this.isAnonymous,
  })  : pollVotes = pollVotes ?? {"0": 0, "1": 0},
        reactions = reactions ?? {"😂": 0, "😱": 0, "👀": 0, "🥴": 0, "🇳🇬": 0};

  factory GistPostEntity.fromJson(Map<String, dynamic> json, String id) {
    final created = json['createdAt'];
    Timestamp ts;
    if (created is Timestamp) {
      ts = created;
    } else if (created is int) {
      ts = Timestamp.fromMillisecondsSinceEpoch(created);
    } else if (created is String) {
      ts = Timestamp.fromDate(DateTime.parse(created));
    } else {
      ts = Timestamp.now();
    }

    final rawPollOptions = json['pollOptions'];
    List<String>? pollOptions;
    if (rawPollOptions is List) {
      pollOptions = rawPollOptions.map((e) => e?.toString() ?? '').cast<String>().toList();
    }

    final rawPollVotes = json['pollVotes'] as Map<String, dynamic>?;
    Map<String, int> pollVotes = {"0": 0, "1": 0};
    if (rawPollVotes != null) {
      pollVotes = rawPollVotes.map((k, v) => MapEntry(k, (v is int) ? v : int.tryParse(v.toString()) ?? 0));
    }

    final rawReactions = json['reactions'] as Map<String, dynamic>?;
    final reactions = <String, int>{"😂": 0, "😱": 0, "👀": 0, "🥴": 0, "🇳🇬": 0};
    if (rawReactions != null) {
      rawReactions.forEach((k, v) {
        reactions[k] = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
      });
    }

    return GistPostEntity(
      id: id,
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Anonymous',
      username: json['username']?.toString() ?? 'anonymous',
      profilePic: json['profilePic']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      content: json['content']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      pollOptions: pollOptions,
      pollVotes: pollVotes,
      reactions: reactions,
      commentCount: (json['commentCount'] is int) ? json['commentCount'] as int : int.tryParse(json['commentCount']?.toString() ?? '0') ?? 0,
      createdAt: ts,
      isAnonymous: json['isAnonymous'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'username': username,
      'profilePic': profilePic,
      'type': type,
      'content': content,
      'imageUrl': imageUrl,
      'pollOptions': pollOptions,
      'pollVotes': pollVotes.map((k, v) => MapEntry(k, v)),
      'reactions': reactions.map((k, v) => MapEntry(k, v)),
      'commentCount': commentCount,
      'createdAt': createdAt,
      'isAnonymous': isAnonymous,
    };
  }
}
