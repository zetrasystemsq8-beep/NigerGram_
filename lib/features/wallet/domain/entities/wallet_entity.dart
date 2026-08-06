import 'package:cloud_firestore/cloud_firestore.dart';

class WalletEntity {
  final String userId;
  final int coinBalance; // CP (whole units)
  final int centBalance; // leftover Cent (0-999)
  final int balanceCents; // total raw balance, source of truth
  final DateTime? updatedAt;

  WalletEntity({
    required this.userId,
    required this.coinBalance,
    required this.centBalance,
    required this.balanceCents,
    this.updatedAt,
  });

  factory WalletEntity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawCents = (data['balanceCents'] as num?)?.toInt() ??
        (((data['coinBalance'] as num?)?.toInt() ?? 0) * 1000); // fallback for old docs
    return WalletEntity(
      userId: data['userId'] ?? '',
      coinBalance: rawCents ~/ 1000,
      centBalance: rawCents % 1000,
      balanceCents: rawCents,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory WalletEntity.fromMap(Map<String, dynamic> map) {
    final rawCents = (map['balanceCents'] as num?)?.toInt() ??
        (((map['coinBalance'] as num?)?.toInt() ?? 0) * 1000);
    return WalletEntity(
      userId: map['userId'] ?? '',
      coinBalance: rawCents ~/ 1000,
      centBalance: rawCents % 1000,
      balanceCents: rawCents,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'coinBalance': coinBalance,
      'balanceCents': balanceCents,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
