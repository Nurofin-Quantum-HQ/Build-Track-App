import 'package:flutter/widgets.dart';
import 'package:showcaseview/showcaseview.dart';

/// Keeps only the tour keys whose [Showcase] widgets are built right now.
///
/// showcaseview 5 never attaches the key to a widget (`key.currentContext` is
/// always null), so ask the showcase registry instead: first the scope of the
/// nearest ShowCaseWidget, then the current scope.
List<GlobalKey> renderedTourKeys(BuildContext context, List<GlobalKey> keys) {
  ShowcaseView? own;
  try {
    // ignore: deprecated_member_use
    own = ShowcaseView.getNamed(ShowCaseWidget.of(context).widget.hashCode.toString());
  } catch (_) {}
  ShowcaseView? current;
  try {
    current = ShowcaseView.get();
  } catch (_) {}
  return keys
      .where((k) =>
          (own?.isTargetRendered(k) ?? false) ||
          (current?.isTargetRendered(k) ?? false))
      .toList();
}
