import 'package:flutter/material.dart';

bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

String fmtDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  const m = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez'
  ];
  String two(int v) => v.toString().padLeft(2, '0');
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return '${two(d.hour)}:${two(d.minute)}';
  }
  if (d.year == now.year) return '${d.day} ${m[d.month - 1]}';
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

void snack(BuildContext context, String msg,
    {String? action, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    behavior: SnackBarBehavior.floating,
    action: (action != null && onAction != null)
        ? SnackBarAction(label: action, onPressed: onAction)
        : null,
  ));
}
