// lib/features/wallet/domain/entities/wallet_entity.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletEntity {
  final String userId;
  final double balance;
  final String currency;
  final DateTime? updatedAt;

  WalletEntity({
    required this.userId,
    required this.balance,
    required this.currency,
    this.updatedAt,
  });

  factory WalletEntity.fromMap(Map<String, dynamic> map) {
    return WalletEntity(
      userId: map['userId'] ?? '',
      balance: (map['balance'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'NGN',
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
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
