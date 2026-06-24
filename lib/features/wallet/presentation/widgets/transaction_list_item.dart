import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransactionEntity {
  final String id;
  final String type;
  final double amount;
  final String? description;
  final String? status;
  final Timestamp? timestamp;

  WalletTransactionEntity({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    this.status,
    this.timestamp,
  });

  factory WalletTransactionEntity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletTransactionEntity(
      id: doc.id,
      type: data['type'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      status: data['status'] ?? 'success',
      timestamp: data['timestamp'] as Timestamp?,
    );
  }

  factory WalletTransactionEntity.fromMap(Map<String, dynamic> map, String id) {
    return WalletTransactionEntity(
      id: id,
      type: map['type'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      status: map['status'] ?? 'success',
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
