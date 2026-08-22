import 'package:flutter/material.dart';

Future<bool> confirmRecordDeletion(
  BuildContext context, {
  required String stockName,
  required String priceLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この記録を削除しますか？'),
        content: Text('$stockName\n$priceLabelで見送り\n\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: const ValueKey('confirm-delete-record'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('削除'),
          ),
        ],
      ),
    ) ??
    false;
