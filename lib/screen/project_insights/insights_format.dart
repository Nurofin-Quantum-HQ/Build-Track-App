import 'package:intl/intl.dart';

// ── Money formatting (Indian lakh / crore) ──────────────────────────────────

String inrCompact(num v, {bool sign = false}) {
  final neg = v < 0;
  final a = v.abs().toDouble();
  String s;
  if (a >= 1e7) {
    s = '${_trim(a / 1e7, a >= 1e9 ? 0 : 2)}\u00A0Cr';
  } else if (a >= 1e5) {
    s = '${_trim(a / 1e5, a >= 1e7 ? 0 : 1)}\u00A0L';
  } else if (a >= 1e3) {
    s = '${_trim(a / 1e3, 1)}\u00A0K';
  } else {
    s = a.toStringAsFixed(0);
  }
  final prefix = neg ? '−' : (sign && v > 0 ? '+' : '');
  return '$prefix₹$s';
}

String _trim(double v, int dp) {
  var s = v.toStringAsFixed(dp);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s;
}

String inrFull(num v) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

String pct(num? v, {int dp = 0}) => v == null ? '—' : '${v.toStringAsFixed(dp)}%';

final dateShort = DateFormat('d MMM yy');
final monthShort = DateFormat('MMM');
