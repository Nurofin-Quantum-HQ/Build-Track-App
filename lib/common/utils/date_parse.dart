/// Lenient date parsing for values coming from the backend.
///
/// Transactions store `date` / `paymentDate` in more than one shape (older
/// rows were written by different clients and a migration that never ran):
///  * `2026-10-22` (YYYY-MM-DD, the current format)
///  * ISO 8601 (`2026-10-22T06:00:00.000Z`)
///  * JavaScript `Date.toString()` (`Thu Oct 22 2026 11:30:00 GMT+0530 (India Standard Time)`)
///  * JavaScript `Date.toUTCString()` (`Thu, 22 Oct 2026 06:00:00 GMT`)
///  * `22/10/2026`, `22-10-2026` (day first) and `2026/10/22`
///  * epoch milliseconds, `{ "$date": … }`
///
/// Returns the moment in local time, or `null` when the value can't be read —
/// callers decide the fallback (don't silently show "today").
DateTime? parseFlexibleDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true).toLocal();
  }
  if (value is Map) return parseFlexibleDate(value[r'$date']);
  final s = value.toString().trim();
  if (s.isEmpty || s == 'null') return null;

  final iso = DateTime.tryParse(s);
  if (iso != null) return iso.toLocal();

  if (RegExp(r'^\d{10,13}$').hasMatch(s)) {
    final n = int.parse(s);
    return DateTime.fromMillisecondsSinceEpoch(s.length == 10 ? n * 1000 : n, isUtc: true).toLocal();
  }

  // 22/10/2026, 22-10-2026, 22.10.2026 (day first, as written in India).
  var m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$').firstMatch(s);
  if (m != null) {
    return _safeDate(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }
  // 2026/10/22, 2026.10.22
  m = RegExp(r'^(\d{4})[/.](\d{1,2})[/.](\d{1,2})$').firstMatch(s);
  if (m != null) {
    return _safeDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  // JS Date.toString(): "Thu Oct 22 2026 11:30:00 GMT+0530 (India Standard Time)"
  m = RegExp(
    r'^(?:[A-Za-z]{3},?\s+)?([A-Za-z]{3})[a-z]*\s+(\d{1,2}),?\s+(\d{4})'
    r'(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?'
    r'(?:\s+(?:GMT|UTC|Z)\s*(?:([+-])(\d{2}):?(\d{2}))?)?',
  ).firstMatch(s);
  if (m != null) {
    final month = _month(m[1]!);
    if (month != null) {
      return _fromParts(int.parse(m[3]!), month, int.parse(m[2]!), m[4], m[5], m[6], s.contains(RegExp(r'GMT|UTC')), m[7], m[8], m[9]);
    }
  }
  // JS Date.toUTCString(): "Thu, 22 Oct 2026 06:00:00 GMT"
  m = RegExp(
    r'^(?:[A-Za-z]{3},?\s+)?(\d{1,2})\s+([A-Za-z]{3})[a-z]*,?\s+(\d{4})'
    r'(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?'
    r'(?:\s+(?:GMT|UTC|Z)\s*(?:([+-])(\d{2}):?(\d{2}))?)?',
  ).firstMatch(s);
  if (m != null) {
    final month = _month(m[2]!);
    if (month != null) {
      return _fromParts(int.parse(m[3]!), month, int.parse(m[1]!), m[4], m[5], m[6], s.contains(RegExp(r'GMT|UTC')), m[7], m[8], m[9]);
    }
  }
  return null;
}

const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

int? _month(String name) {
  final i = _months.indexOf(name.substring(0, 3).toLowerCase());
  return i < 0 ? null : i + 1;
}

DateTime? _safeDate(int y, int mo, int d) {
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime(y, mo, d);
}

DateTime? _fromParts(int y, int mo, int d, String? hh, String? mm, String? ss, bool hasZone, String? sign, String? oh, String? om) {
  if (d < 1 || d > 31) return null;
  final h = int.tryParse(hh ?? '') ?? 0;
  final mi = int.tryParse(mm ?? '') ?? 0;
  final se = int.tryParse(ss ?? '') ?? 0;
  if (!hasZone) return DateTime(y, mo, d, h, mi, se);
  var utc = DateTime.utc(y, mo, d, h, mi, se);
  if (sign != null && oh != null && om != null) {
    final offset = Duration(hours: int.parse(oh), minutes: int.parse(om));
    utc = sign == '+' ? utc.subtract(offset) : utc.add(offset);
  }
  return utc.toLocal();
}
