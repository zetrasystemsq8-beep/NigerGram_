import 'package:cloud_firestore/cloud_firestore.dart';

enum BountyStatus { open, inProgress, completed, cancelled }

class BountyEntity {
  final String id;
  final String title;
  final String description;
  final String category; // Software, AI, Business, Engineering, etc.
  final double rewardCp;
  final String posterId;
  final String posterUsername;
  final BountyStatus status;
  final String? escrowId;
  final String? claimedByUserId;
  final String? claimedByUsername;
  final Timestamp? createdAt;

  const BountyEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.rewardCp,
    required this.posterId,
    required this.posterUsername,
    this.status = BountyStatus.open,
    this.escrowId,
    this.claimedByUserId,
    this.claimedByUsername,
    this.createdAt,
  });

  static BountyStatus _statusFromString(String? s) {
    switch (s) {
      case 'inProgress':
        return BountyStatus.inProgress;
      case 'completed':
        return BountyStatus.completed;
      case 'cancelled':
        return BountyStatus.cancelled;
      default:
        return BountyStatus.open;
    }
  }

  static String statusToString(BountyStatus s) {
    switch (s) {
      case BountyStatus.inProgress:
        return 'inProgress';
      case BountyStatus.completed:
        return 'completed';
      case BountyStatus.cancelled:
        return 'cancelled';
      case BountyStatus.open:
        return 'open';
    }
  }

  factory BountyEntity.fromMap(Map<String, dynamic> map, String id) {
    return BountyEntity(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'Software',
      rewardCp: (map['rewardCp'] as num?)?.toDouble() ?? 0.0,
      posterId: map['posterId'] ?? '',
      posterUsername: map['posterUsername'] ?? '',
      status: _statusFromString(map['status']),
      escrowId: map['escrowId'],
      claimedByUserId: map['claimedByUserId'],
      claimedByUsername: map['claimedByUsername'],
      createdAt: map['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'rewardCp': rewardCp,
      'posterId': posterId,
      'posterUsername': posterUsername,
      'status': statusToString(status),
      'escrowId': escrowId,
      'claimedByUserId': claimedByUserId,
      'claimedByUsername': claimedByUsername,
      'createdAt': createdAt,
    };
  }
}

const List<String> bountyCategories = [
  'Software', 'AI/ML', 'Business', 'Engineering', 'Design', 'Research', 'Other',
];
