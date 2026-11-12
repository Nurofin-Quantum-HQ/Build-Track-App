import 'dart:collection';

/// One recent "step" the user took, sent with a problem report so support can
/// see what led up to it. Never holds typed values, amounts or tokens.
class Breadcrumb {
  const Breadcrumb({required this.at, required this.kind, required this.label, this.detail});

  /// `screen` | `tap` | `api_error` | `error`
  final DateTime at;
  final String kind;
  final String label;
  final String? detail;

  Map<String, dynamic> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'kind': kind,
        'label': label,
        if (detail != null && detail!.isNotEmpty) 'detail': detail,
      };

  factory Breadcrumb.fromJson(Map<String, dynamic> j) => Breadcrumb(
        at: DateTime.tryParse(j['at']?.toString() ?? '') ?? DateTime.now(),
        kind: j['kind']?.toString() ?? 'tap',
        label: j['label']?.toString() ?? '',
        detail: j['detail']?.toString(),
      );
}

/// In-memory ring buffer of the last [capacity] steps.
///
/// Everything that goes in is passed through [sanitize]: query strings, email
/// addresses, bearer tokens, token-looking strings and money amounts are
/// removed, and the text is clipped. Callers still must only pass fixed
/// labels ("Save entry"), never what the user typed.
class Breadcrumbs {
  Breadcrumbs._();

  static const int capacity = 30;
  static const int maxLabel = 120;
  static const int maxDetail = 200;

  static final ListQueue<Breadcrumb> _items = ListQueue<Breadcrumb>();

  /// Replaceable clock (tests).
  static DateTime Function() now = DateTime.now;

  static List<Breadcrumb> get items => List.unmodifiable(_items);
  static int get length => _items.length;

  static void clear() => _items.clear();

  static void _add(String kind, String label, [String? detail]) {
    final l = sanitize(label, maxLabel);
    if (l.isEmpty) return;
    final d = detail == null ? null : sanitize(detail, maxDetail);
    _items.addLast(Breadcrumb(at: now(), kind: kind, label: l, detail: (d == null || d.isEmpty) ? null : d));
    while (_items.length > capacity) {
      _items.removeFirst();
    }
  }

  /// A screen came into view. Consecutive duplicates (the nav bar and the
  /// navigator both report the same change) are collapsed.
  static void screen(String name) {
    final label = sanitize(name, maxLabel);
    for (final b in _items.toList().reversed) {
      if (b.kind == 'screen') {
        if (b.label == label) return;
        break;
      }
    }
    _add('screen', label);
  }

  /// An explicit user action, e.g. `Breadcrumbs.tap('Save entry')`.
  static void tap(String what) => _add('tap', what);

  /// A failed call from the central HTTP layer. [status] null = no response.
  static void apiFailure(String method, String path, int? status) {
    _add('api_error', '${method.toUpperCase()} ${sanitizePath(path)}', status == null ? 'network error' : 'status $status');
  }

  /// An uncaught Flutter / zone error.
  static void error(Object error, [String? where]) {
    final type = error.runtimeType.toString();
    _add('error', where == null || where.isEmpty ? type : where, '$type: ${_scrubError(error.toString())}');
  }

  /// Error messages can quote user input (FormatException: … "5000"), so keep
  /// only the first line, drop quoted text and long digit runs.
  static String _scrubError(String message) {
    final first = message.split('\n').first;
    return first.replaceAll(RegExp(r'"[^"]*"'), '"…"').replaceAll(RegExp(r"'[^']*'"), "'…'").replaceAll(RegExp(r'\d{4,}'), '#');
  }

  static List<Map<String, dynamic>> toJsonList() => _items.map((b) => b.toJson()).toList();

  // ── sanitising ────────────────────────────────────────────────────────

  static final RegExp _email = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
  static final RegExp _bearer = RegExp(r'bearer\s+[A-Za-z0-9._\-~+/=]+', caseSensitive: false);
  static final RegExp _jwt = RegExp(r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*');
  static final RegExp _longToken = RegExp(r'[A-Za-z0-9_\-]{28,}');
  static final RegExp _secretKv = RegExp(r'(token|password|passwd|secret|otp|authorization|apikey|api_key)\s*[=:]\s*\S+', caseSensitive: false);
  static final RegExp _money = RegExp(r'(?:₹|Rs\.?|INR|\$)\s?\d[\d,]*(?:\.\d+)?', caseSensitive: false);
  static final RegExp _groupedNumber = RegExp(r'\b\d{1,3}(?:,\d{2,3})+(?:\.\d+)?\b');
  static final RegExp _queryString = RegExp(r'\?\S*');
  static final RegExp _mongoId = RegExp(r'\b[0-9a-fA-F]{24}\b');
  static final RegExp _ws = RegExp(r'\s+');

  /// Removes anything that could be a secret or a personal value, collapses
  /// whitespace and clips to [max] characters.
  static String sanitize(String input, int max) {
    var s = input;
    s = s.replaceAll(_bearer, 'Bearer [removed]');
    s = s.replaceAll(_jwt, '[removed]');
    s = s.replaceAll(_secretKv, r'$1=[removed]');
    s = s.replaceAll(_email, '[email]');
    s = s.replaceAll(_queryString, '');
    s = s.replaceAll(_mongoId, ':id');
    s = s.replaceAll(_longToken, '[removed]');
    s = s.replaceAll(_money, '[amount]');
    s = s.replaceAll(_groupedNumber, '[amount]');
    s = s.replaceAll(_ws, ' ').trim();
    if (s.length > max) s = '${s.substring(0, max - 1)}…';
    return s;
  }

  /// Path only: no scheme/host, no query or fragment, record ids replaced by `:id`.
  static String sanitizePath(String path) {
    var p = path;
    final uri = Uri.tryParse(p);
    if (uri != null && uri.hasScheme) p = uri.path;
    p = p.split('?').first.split('#').first;
    p = p.replaceAll(_mongoId, ':id');
    p = p.split('/').map((seg) => seg.length >= 28 ? ':token' : seg).join('/');
    return p;
  }
}
