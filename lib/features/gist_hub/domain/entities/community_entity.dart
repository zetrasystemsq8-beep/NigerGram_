import 'package:cloud_firestore/cloud_firestore.dart';

enum CommunityType { group, channel }

class CommunityEntity {
  final String id;
  final String name;
  final String description;
  final CommunityType type;
  final String creatorId;
  final List<String> moderatorIds;
  final int memberCount;
  final List<String> rules;
  final String? iconUrl;
  final bool isPrivate;
  final Timestamp? createdAt;

  const CommunityEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.creatorId,
    this.moderatorIds = const [],
    this.memberCount = 1,
    this.rules = const [],
    this.iconUrl,
    this.isPrivate = false,
    this.createdAt,
  });

  factory CommunityEntity.fromMap(Map<String, dynamic> map, String id) {
    return CommunityEntity(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: (map['type'] == 'channel') ? CommunityType.channel : CommunityType.group,
      creatorId: map['creatorId'] ?? '',
      moderatorIds: List<String>.from(map['moderatorIds'] ?? []),
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 1,
      rules: List<String>.from(map['rules'] ?? []),
      iconUrl: map['iconUrl'],
      isPrivate: map['isPrivate'] ?? false,
      createdAt: map['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type == CommunityType.channel ? 'channel' : 'group',
      'creatorId': creatorId,
      'moderatorIds': moderatorIds,
      'memberCount': memberCount,
      'rules': rules,
      'iconUrl': iconUrl,
      'isPrivate': isPrivate,
      'createdAt': createdAt,
    };
  }
}

/// A handful of ready-made rule sets a creator can pick from instead of
/// writing rules from scratch. They can still add/edit before creating.
class RuleTemplates {
  static const Map<String, List<String>> templates = {
    'Standard': [
      'Be respectful — no harassment or hate speech.',
      'Stay on topic for this community.',
      'No spam or excessive self-promotion.',
    ],
    'Builder Community': [
      'Share real progress — no vague hype posts.',
      'Give constructive feedback, not just criticism.',
      'Credit tools/collaborators you used.',
    ],
    'Strict / Moderated': [
      'All posts reviewed before appearing.',
      'Zero tolerance for spam or off-topic content.',
      'Repeated violations result in removal.',
    ],
  };
}
