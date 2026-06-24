import 'package:cloud_firestore/cloud_firestore.dart';

class WalletEntity {
  final String userId;
  final double balance;
  final String currency;
  final double totalEarned;
  final DateTime? updatedAt;

  WalletEntity({
    required this.userId,
    required this.balance,
    required this.currency,
    this.totalEarned = 0.0,
    this.updatedAt,
  });

  // 👈 THIS METHOD MUST EXIST
  factory WalletEntity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletEntity(
      userId: data['userId'] ?? '',
      balance: (data['balance'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'NGN',
      totalEarned: (data['totalEarned'] ?? 0.0).toDouble(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory WalletEntity.fromMap(Map<String, dynamic> map) {
    return WalletEntity(
      userId: map['userId'] ?? '',
      balance: (map['balance'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'NGN',
      totalEarned: (map['totalEarned'] ?? 0.0).toDouble(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'balance': balance,
      'currency': currency,
      'totalEarned': totalEarned,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
