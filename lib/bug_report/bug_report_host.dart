import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:buildtrack_mobile/controller/nav_controller.dart';

import 'breadcrumbs.dart';
import 'bug_report_service.dart';
import 'route_names.dart';
import 'screen_tracker.dart';
import 'screenshot_capture.dart';
import 'shake_service.dart';

/// Wraps the whole app (MaterialApp `builder`). It
///  • gives screenshots something to capture (a keyed RepaintBoundary),
///  • starts the shake listener,
///  • records tab changes from NavController as breadcrumbs,
///  • retries reports saved offline, at start and whenever the app resumes.
class BugReportHost extends StatefulWidget {
  const BugReportHost({super.key, required this.child});
  final Widget child;

  @override
  State<BugReportHost> createState() => _BugReportHostState();
}

class _BugReportHostState extends State<BugReportHost> with WidgetsBindingObserver {
  NavController? _nav;
  Timer? _startDelay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ShakeService.instance.start());
    // Wait a little so the startup session check finishes first.
    _startDelay = Timer(const Duration(seconds: 6), () => unawaited(BugReportService.instance.flushQueue()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.read<NavController>();
    if (!identical(nav, _nav)) {
      _nav?.removeListener(_onTab);
      _nav = nav..addListener(_onTab);
      ScreenTracker.instance.tabRoute = () => nav.currentRoute;
    }
  }

  void _onTab() {
    final name = RouteNames.forRoute(_nav?.currentRoute);
    if (name != null) Breadcrumbs.screen(name);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(BugReportService.instance.flushQueue());
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    _nav?.removeListener(_onTab);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(key: ScreenshotCapture.boundaryKey, child: widget.child);
}
