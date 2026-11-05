import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much the app moves. Chosen by the user in Profile → Motion.
///
/// * [full]    – everything animates (default).
/// * [reduced] – fades only: no rises, count-ups, bar/ring fills, press
///               scale or looping effects; the success overlay shows a
///               static tick.
/// * [off]     – nothing moves; changes are instant (fades ≤ 120 ms at most).
enum BtMotionLevel { full, reduced, off }

/// The user's saved motion level (per user, local only) + helpers.
///
/// Read the *effective* level with [BtMotion.of] from a `build` /
/// `didChangeDependencies`; it is capped by the OS "reduce motion" setting
/// (the OS can only lower it, never raise it) and re-runs when the user changes
/// the setting, because [BtMotionScope] sits above the whole app.
class BtMotion extends ChangeNotifier {
  BtMotion._();
  static final BtMotion instance = BtMotion._();

  static const _keyPrefix = 'motionLevel_';

  /// Prefs key for one user (also used by UserSession to keep it across logout).
  static String prefsKey(String userId) => '$_keyPrefix$userId';
  static bool isPrefsKey(String key) => key.startsWith(_keyPrefix);

  BtMotionLevel _level = BtMotionLevel.full;
  String _userId = '';

  /// What the user picked (before the OS cap).
  BtMotionLevel get level => _level;

  /// Reads the saved level for [userId] (default Full). Call after login / on
  /// app start once the user id is known.
  Future<void> loadFor(String userId) async {
    _userId = userId;
    var next = BtMotionLevel.full;
    if (userId.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        next = _parse(prefs.getString(prefsKey(userId)));
      } catch (e) {
        debugPrint('[BtMotion] load failed: $e');
      }
    }
    if (next != _level) {
      _level = next;
      notifyListeners();
    }
  }

  /// Back to Full in memory (logout). The saved value stays on the device.
  void reset() {
    _userId = '';
    if (_level != BtMotionLevel.full) {
      _level = BtMotionLevel.full;
      notifyListeners();
    }
  }

  Future<void> set(BtMotionLevel next) async {
    if (next == _level) return;
    _level = next;
    notifyListeners();
    if (_userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey(_userId), next.name);
    } catch (e) {
      debugPrint('[BtMotion] save failed: $e');
    }
  }

  static BtMotionLevel _parse(String? s) {
    for (final l in BtMotionLevel.values) {
      if (l.name == s) return l;
    }
    return BtMotionLevel.full;
  }

  // ── reading it in widgets ──────────────────────────────────────────────

  /// Effective level: the user's choice, lowered to Reduced when the OS asks
  /// for reduced motion. Registers a dependency, so the widget rebuilds when
  /// either changes.
  static BtMotionLevel of(BuildContext context) {
    final stored =
        (context
                    .dependOnInheritedWidgetOfExactType<BtMotionScope>()
                    ?.notifier ??
                instance)
            .level;
    if (stored == BtMotionLevel.full &&
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      return BtMotionLevel.reduced;
    }
    return stored;
  }

  /// Same as [of] but without registering a rebuild dependency — for use in
  /// event handlers (e.g. choosing a route's duration right before pushing it).
  static BtMotionLevel peek(BuildContext context) {
    final stored =
        (context.getInheritedWidgetOfExactType<BtMotionScope>()?.notifier ??
                instance)
            .level;
    final os =
        context
            .getInheritedWidgetOfExactType<MediaQuery>()
            ?.data
            .disableAnimations ??
        false;
    return (stored == BtMotionLevel.full && os)
        ? BtMotionLevel.reduced
        : stored;
  }

  /// True when the OS reduce-motion setting is what is limiting a "Full" choice.
  static bool osLimited(BuildContext context) =>
      instance.level == BtMotionLevel.full &&
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  static bool isFull(BuildContext context) => of(context) == BtMotionLevel.full;
  static bool isOff(BuildContext context) => of(context) == BtMotionLevel.off;

  /// Fade length for an element that only fades when motion is limited.
  static const fadeReduced = Duration(milliseconds: 200);
  static const fadeOff = Duration(milliseconds: 100);

  /// [full] unchanged; [reduced] a short fade; [off] a ≤120 ms fade.
  static Duration fade(BuildContext context, Duration full) =>
      switch (of(context)) {
        BtMotionLevel.full => full,
        BtMotionLevel.reduced => fadeReduced,
        BtMotionLevel.off => fadeOff,
      };

  /// [full] unchanged; anything lower → no animation at all.
  static Duration moving(BuildContext context, Duration full) =>
      isFull(context) ? full : Duration.zero;
}

/// Put once above the app (MaterialApp.builder) so every [BtMotion.of] call
/// rebuilds when the user changes the setting.
class BtMotionScope extends InheritedNotifier<BtMotion> {
  const BtMotionScope({
    super.key,
    required BtMotion super.notifier,
    required super.child,
  });
}
