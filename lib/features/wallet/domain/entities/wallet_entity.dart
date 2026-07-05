import 'package:cloud_firestore/cloud_firestore.dart';

class WalletEntity {
  final String userId;
  final int coinBalance;
  final DateTime? updatedAt;

  WalletEntity({
    required this.userId,
    required this.coinBalance,
    this.updatedAt,
  });

  factory WalletEntity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletEntity(
      userId: data['userId'] ?? '',
      coinBalance: (data['coinBalance'] as num?)?.toInt() ?? 0,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory WalletEntity.fromMap(Map<String, dynamic> map) {
    return WalletEntity(
      userId: map['userId'] ?? '',
      coinBalance: (map['coinBalance'] as num?)?.toInt() ?? 0,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'coinBalance': coinBalance,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
