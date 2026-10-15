import 'package:intl/intl.dart';

/// One money format for the whole app (DESIGN.md §5).
/// compact: totals/summaries → ₹1.81 Cr / ₹91.3 L. Default: entries → ₹27,086.
String formatInr(num? v, {bool compact = false}) {
  if (v == null || v.isNaN) return '';
  final neg = v < 0;
  final a = v.abs();
  String s;
  if (compact && a >= 1e7) {
    s = '₹${_trim(a / 1e7)} Cr';
  } else if (compact && a >= 1e5) {
    s = '₹${_trim(a / 1e5)} L';
  } else {
    s = '₹${NumberFormat.decimalPattern('en_IN').format(a.round())}';
  }
  return neg ? '−$s' : s;
}

String _trim(num x) {
  final str = x >= 100 ? x.toStringAsFixed(0) : x >= 10 ? x.toStringAsFixed(1) : x.toStringAsFixed(2);
  return str.contains('.') ? str.replaceFirst(RegExp(r'\.?0+$'), '') : str;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// 9 Oct 2026
String formatDate(DateTime? d) => d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';

/// 9 Oct (current year) or 9 Oct 2025
String formatShortDate(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  return d.year == now.year ? '${d.day} ${_months[d.month - 1]}' : formatDate(d);
}

/// Today / Yesterday / 5 Oct — for list group headers.
String formatDayGroup(DateTime? d) {
  if (d == null) return 'Earlier';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return formatShortDate(d);
}

/// 5:30 pm
String formatTime(DateTime? d) {
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'am' : 'pm'}';
}

/// Backend unit → UI unit word (DESIGN.md §5).
String unitLabel(String? unit, {num? qty}) {
  final u = (unit ?? '').trim();
  switch (u.toLowerCase()) {
    case 'bag':
    case 'bags':
      return 'bags';
    case 'hour':
    case 'hours':
    case 'hr':
    case 'hrs':
      return 'hrs';
    case 'day':
    case 'days':
      return 'days';
    case 'ton':
    case 'tons':
    case 'mt':
      return 't';
    case 'truck':
    case 'trucks':
      return 'loads';
    case 'sqft':
    case 'sq.ft':
    case 'sq ft':
      return 'sq ft';
    case 'sqm':
      return 'sq m';
    case 'ltr':
    case 'ltrs':
      return 'L';
    case 'unit':
    case '':
      return '';
    default:
      return u;
  }
}
