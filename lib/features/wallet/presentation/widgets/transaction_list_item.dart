import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nigergram/features/wallet/domain/entities/transaction_entity.dart';

class TransactionListItem extends StatelessWidget {
  final WalletTransactionEntity transaction;

  const TransactionListItem({required this.transaction, super.key});

  @override
  Widget build(BuildContext context) {
    final amountText = '₦${transaction.amount.toStringAsFixed(0)}';
    final date = transaction.timestamp;
    final dateText = date != null ? DateFormat.yMMMd().add_jm().format(date.toDate()) : '';
    return ListTile(
      leading: CircleAvatar(
        child: Icon(
          transaction.type == 'tip' ? Icons.card_giftcard : transaction.type == 'fund' ? Icons.account_balance_wallet : Icons.swap_horiz,
        ),
      ),
      title: Text(transaction.type.toUpperCase()),
      subtitle: Text('${transaction.toUsername ?? ''} • $dateText'),
      trailing: Text(amountText, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
