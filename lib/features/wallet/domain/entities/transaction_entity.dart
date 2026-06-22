import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransactionEntity {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String fromUsername;
  final String toUsername;
  final double amount;
  final String type;
  final String? videoId;
  final String? message;
  final String status;
  final Timestamp timestamp;

  WalletTransactionEntity({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.fromUsername,
    required this.toUsername,
    required this.amount,
    required this.type,
    this.videoId,
    this.message,
    required this.status,
    required this.timestamp,
  });

  factory WalletTransactionEntity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WalletTransactionEntity(
      id: doc.id,
      fromUserId: data['fromUserId'] as String? ?? '',
      toUserId: data['toUserId'] as String? ?? '',
      fromUsername: data['fromUsername'] as String? ?? '',
      toUsername: data['toUsername'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: data['type'] as String? ?? '',
      videoId: data['videoId'] as String?,
      message: data['message'] as String?,
      status: data['status'] as String? ?? 'pending',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'fromUsername': fromUsername,
      'toUsername': toUsername,
      'amount': amount,
      'type': type,
      'videoId': videoId,
      'message': message,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
