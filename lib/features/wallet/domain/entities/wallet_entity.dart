import 'package:cloud_firestore/cloud_firestore.dart';

class WalletEntity {
  final String uid;
  final double balance;
  final double totalEarned;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankAccountName;
  final Timestamp? updatedAt;

  WalletEntity({
    required this.uid,
    required this.balance,
    required this.totalEarned,
    this.bankAccountNumber,
    this.bankName,
    this.bankAccountName,
    this.updatedAt,
  });

  factory WalletEntity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WalletEntity(
      uid: data['uid'] as String? ?? doc.id,
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      totalEarned: (data['totalEarned'] as num?)?.toDouble() ?? 0.0,
      bankAccountNumber: data['bankAccountNumber'] as String?,
      bankName: data['bankName'] as String?,
      bankAccountName: data['bankAccountName'] as String?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'balance': balance,
      'totalEarned': totalEarned,
      'bankAccountNumber': bankAccountNumber,
      'bankName': bankName,
      'bankAccountName': bankAccountName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
