// lib/features/wallet/presentation/widgets/transaction_list_item.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/features/wallet/domain/entities/transaction_entity.dart';

class TransactionListItem extends StatelessWidget {
  final WalletTransactionEntity transaction;
  final bool showStatus;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.showStatus = true,
  });

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == 'credit';
    final amount = transaction.amount;
    final status = transaction.status ?? 'success';

    Color statusColor = Colors.green;
    String statusText = 'Success';
    if (status == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Pending';
    } else if (status == 'failed') {
      statusColor = Colors.red;
      statusText = 'Failed';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCredit 
                  ? Colors.green.withOpacity(0.15)
                  : Colors.red.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit 
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isCredit ? Colors.green : Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // 👈 FIX: Use 'type' instead of 'description'
                  transaction.type == 'credit' ? 'Credit' : 'Debit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatDate(transaction.timestamp),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    if (showStatus) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}₦${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: isCredit ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
