// lib/features/wallet/domain/entities/transaction_entity.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransactionEntity {
  final String id;
  final String type; // 'credit' or 'debit'
  final double amount;
  final String? description;
  final String? status; // 'success', 'pending', 'failed'
  final Timestamp? timestamp;

  WalletTransactionEntity({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    this.status,
    this.timestamp,
  });

  factory WalletTransactionEntity.fromMap(Map<String, dynamic> map, String id) {
    return WalletTransactionEntity(
      id: id,
      type: map['type'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'],
      status: map['status'],
      timestamp: map['timestamp'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'status': status,
      'timestamp': timestamp,
    };
  }
}
