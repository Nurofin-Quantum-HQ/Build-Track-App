import 'package:buildtrack_mobile/common/tour_targets.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/models/task_model.dart';
import 'package:buildtrack_mobile/services/task_service.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/screen/dashboard/notifications_bell.dart';
import 'package:buildtrack_mobile/config/api_config.dart';

String relativeTimeLabel(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.isNegative) {
    return 'Just now';
  }
  if (diff.inMinutes < 1) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  } else if (diff.inDays == 1) {
    return 'Yesterday';
  } else if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  } else {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});
  final GlobalKey<ShowCaseWidgetState> _showcaseKey = GlobalKey<ShowCaseWidgetState>();

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      key: _showcaseKey,
      globalTooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          backgroundColor: Colors.transparent,
          textStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          onTap: () {
            UserSession.skipTour();
            _showcaseKey.currentState?.dismiss();
          }
        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          backgroundColor: AppColors.primary,
          textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        )
      ],
      enableAutoScroll: true,
      onFinish: () {
        UserSession.markModuleVisited('HomeScreen');
        if (UserSession.globalTourActive) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) {
              // Next tab this user can open (skips disabled ones), or ends the tour.
              context.read<NavController>().continueTour(context, from: '/home');
            }
          });
        }
      },
      builder: (context) => const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();
  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}
class _HomeScreenContentState extends State<_HomeScreenContent> {
  /// Home tour steps in the order they appear on screen (top → bottom, then
  /// the bottom dock left → right). Only keys whose widgets are mounted right
  /// now are used — the admin cards don't exist on the supervisor / mason
  /// homes, and the dock hides tabs the user can't open; passing an unmounted
  /// key makes the tour jump or stall. (Before: a fixed list in arbitrary
  /// order incl. `inventoryTab`, which is no longer on screen anywhere.)
  List<GlobalKey> _getShowcaseKeys({bool isReplay = false}) {
    final ordered = <GlobalKey>[
      _notificationsTourKey,
      ShowcaseKeys.helpButton,
      ShowcaseKeys.profileIcon,
      // Admin hero + cards
      ShowcaseKeys.dashboardTotalCost,
      ShowcaseKeys.dashboardTotalBudget,
      ShowcaseKeys.quickAddEntry,
      ShowcaseKeys.progress,
      ShowcaseKeys.dashboardTotalRevenue,
      ShowcaseKeys.dashboardNetCashFlow,
      ShowcaseKeys.recentEntries,
      // Bottom dock
      if (isReplay || !UserSession.hasCreatedProject) ShowcaseKeys.projects,
      if (isReplay || !UserSession.hasAddedEntry) ShowcaseKeys.addEntry,
      if (isReplay || !UserSession.hasViewedReports) ShowcaseKeys.reports,
    ];
    return renderedTourKeys(context, ordered);
  }

  bool _tourChecked = false;

  @override
  void initState() {
    super.initState();
  }

  void _checkTour(ProjectProvider provider) {
    if (_tourChecked) return;
    if (!provider.projectsLoaded) return;
    _tourChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Existing users skip the first-run prompt — unless they restarted the
      // tour themselves (Account › App Guidelines).
      if (!UserSession.globalTourActive &&
          (provider.projects.isNotEmpty || UserSession.hasAddedEntry)) {
        UserSession.markAllModulesVisited();
      } else {
        if (!UserSession.appTourPrompted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Bt.scrim,
            builder: (context) => _WelcomeTourDialog(
              onNo: () {
                UserSession.markAppTourPrompted();
                Navigator.pop(context);
              },
              onYes: () {
                UserSession.markAppTourPrompted();
                UserSession.resetTour();
                UserSession.setGlobalTourActive(true);
                Navigator.pop(context);
                _startHomeScreenTour();
              },
            ),
          );
        } else if (UserSession.globalTourActive && !UserSession.visitedModules.contains('HomeScreen')) {
          _startHomeScreenTour();
        }
      }
    });
  }

  void _startHomeScreenTour() {
    if (!UserSession.hasSkippedTour && !UserSession.visitedModules.contains('HomeScreen')) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          final keysToShow = _getShowcaseKeys();
          if (keysToShow.isNotEmpty) {
            ShowCaseWidget.of(context).startShowCase(keysToShow);
          }
        }
      });
    }
  }

  /// A specific type (Mason's "Add Material Entry") opens the same flow as
  /// the + sheet's choice (`/execution-context` with that type); anything
  /// else opens the Add Entry page.
  Future<void> _showEntryOptions(BuildContext context, String type) async {
    if (type == 'material' || type == 'labour' || type == 'equipment') {
      await Navigator.pushNamed(context, '/execution-context', arguments: {'type': type});
      return;
    }
    await Navigator.pushNamed(context, '/add-entry');
  }

  /// Top row of every role's hero: company caption + greeting, then
  /// Inbox bell · help/tour · account (same targets as before).
  Widget _buildHeroTop(BuildContext context) {
    final company = UserSession.companyName.isNotEmpty ? UserSession.companyName : 'BuildTrack';
    return BtReveal(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CompanyLogoTile(company: company),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // The company's chosen name style (Create workspace / Edit profile).
                  style: UserSession.getCompanyTextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Bt.onNoir2),
                ),
                const SizedBox(height: 3),
                Text(
                  _homeGreeting(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BtText.headline(context).copyWith(color: Bt.bone),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Showcase(
            key: _notificationsTourKey,
            description: 'Notifications — approvals, rejections and updates about your entries. The dot shows how many are unread.',
            tooltipBackgroundColor: Bt.ink,
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: const NotificationsBell(),
          ),
          const SizedBox(width: 6),
          Showcase(
            key: ShowcaseKeys.helpButton,
            description: 'App guidelines — tap here anytime to replay this tour.',
            tooltipBackgroundColor: Bt.ink,
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: BtIconButton(
              icon: Icons.help_outline_rounded,
              semantic: 'App guidelines',
              size: 21,
              color: Bt.bone,
              background: Colors.white.withValues(alpha: .09),
              onTap: () {
                final keysToShow = _getShowcaseKeys(isReplay: true);
                if (keysToShow.isNotEmpty) {
                  ShowcaseView.get().startShowCase(keysToShow);
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          Showcase(
            key: ShowcaseKeys.profileIcon,
            description: 'Your account — profile, team, plan, logs and settings.',
            tooltipBackgroundColor: Bt.ink,
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: Semantics(
              button: true,
              label: 'Account',
              child: BtPressable(
                scale: .92,
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .18), width: 1.5)),
                  child: const ProfileAvatar(radius: 19),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _checkTour(context.watch<ProjectProvider>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NavController>().markCurrent('/home');
    });
    final top = _buildHeroTop(context);
    return Scaffold(
      backgroundColor: Bt.ground,
      body: UserSession.isAdmin
          ? _AdminDashboard(onEntryTap: _showEntryOptions, top: top)
          : UserSession.isSupervisor
              ? _SupervisorDashboard(top: top)
              : _MasonDashboard(onEntryTap: _showEntryOptions, top: top),
      bottomNavigationBar: AppBottomNav(),
    );
  }
}

// ───────────────────────────────────────────────────────── shared home pieces

/// Tour step for the Home bell (the bell has no key in [ShowcaseKeys]).
final GlobalKey _notificationsTourKey = GlobalKey();

/// Company logo in the Home hero: a 40 px rounded white tile next to the
/// company name. No logo (or one that fails to load) → the company's initial
/// on a glass tile, so the header never shows an empty box.
class _CompanyLogoTile extends StatelessWidget {
  const _CompanyLogoTile({required this.company});
  final String company;
  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final provider = getProfileImageProvider(UserSession.companyLogo);
    final initial = company.trim().isNotEmpty ? company.trim()[0].toUpperCase() : 'B';
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Text(initial, style: BtText.headline(context).copyWith(color: Bt.bone)),
    );
    if (provider == null) return ExcludeSemantics(child: fallback);
    return Semantics(
      image: true,
      label: '$company logo',
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image(
            image: provider,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Center(child: Text(initial, style: BtText.headline(context).copyWith(color: Bt.ink))),
          ),
        ),
      ),
    );
  }
}

/// Quiet "Powered by Nurofin" line at the bottom of every role's Home
/// (same asset and treatment as the login screen footer).
class _PoweredByFooter extends StatelessWidget {
  const _PoweredByFooter();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 4),
      child: Semantics(
        label: 'Powered by Nurofin',
        child: ExcludeSemantics(
          child: Opacity(
            opacity: .75,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('POWERED BY', style: BtText.mono(context)),
                const SizedBox(width: 6),
                Image.asset(
                  'assets/images/nurofin-logo.png',
                  height: 16,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text('Nurofin', style: BtText.caption(context, weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where a revenue entry's proof image lives: the uploaded photo
/// (`attachments`) or, for a cash e-signature, `paymentReceipt`.
String? _revenueProofUrl(Map<String, dynamic> tx) {
  final att = tx['attachments'];
  if (att is List) {
    for (final a in att) {
      final s = a?.toString() ?? '';
      if (s.isNotEmpty) return s;
    }
  }
  final r = tx['paymentReceipt']?.toString() ?? '';
  return r.isNotEmpty ? r : null;
}

/// Image provider for a stored proof (https URL, server-relative path or data URI).
ImageProvider? _proofImageProvider(String? src) {
  if (src == null || src.isEmpty) return null;
  if (src.startsWith('/')) return NetworkImage('${ApiConfig.baseUrl.replaceAll('/api', '')}$src');
  return getProfileImageProvider(src);
}

String _homeGreeting() {
  final h = DateTime.now().hour;
  final part = h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  return part; // the session has no user name; role shows on Account
}

/// Noir hero used by all three role dashboards (top row + role content).
class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.top, required this.children});
  final Widget top;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return BtHero(
      padding: EdgeInsets.fromLTRB(Bt.gutter, MediaQuery.paddingOf(context).top + 12, Bt.gutter, 26 + 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [top, ...children]),
    );
  }
}

/// Same API call + feedback the supervisor dashboard always used.
Future<bool> _approveTx(BuildContext context, String id) async {
  final ok = await ApiService.approveTransaction(id);
  if (!context.mounted) return ok;
  if (ok) {
    btToast(context, 'Transaction approved');
  } else {
    btToast(context, "Couldn't approve — check your connection and try again.", error: true);
  }
  return ok;
}

/// Same API call + feedback the supervisor dashboard always used.
Future<bool> _rejectTx(BuildContext context, String id) async {
  final ok = await ApiService.rejectTransaction(id, 'Rejected by supervisor');
  if (!context.mounted) return ok;
  if (ok) {
    btToast(context, 'Transaction rejected');
  } else {
    btToast(context, "Couldn't reject — check your connection and try again.", error: true);
  }
  return ok;
}

Future<bool> _confirmRejectTx(BuildContext context) {
  return btConfirm(context, title: 'Reject this entry?', message: 'The person who logged it will see it as rejected.', confirmLabel: 'Reject');
}

double _sumAmounts(Iterable<dynamic> txs) => txs.fold<double>(0.0, (s, t) {
      final a = t is Map ? t['amount'] : null;
      return s + ((a is num) ? a.toDouble() : (double.tryParse(a?.toString() ?? '') ?? 0.0));
    });

/// "4 entries need your approval · ₹99,963 waiting" — opens Approvals.
class _ApprovalsSummaryCard extends StatelessWidget {
  const _ApprovalsSummaryCard({required this.count, required this.amount, required this.onTap, this.updates = 0});
  final int count;
  final double amount;
  final int updates;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final sub = <String>[
      if (amount > 0) '${formatInr(amount)} waiting',
      if (updates > 0) '$updates project update${updates == 1 ? '' : 's'}',
    ];
    return BtCard(
      variant: BtCardVariant.attention,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: onTap,
      child: Row(children: [
        BtTile(icon: Icons.inbox_outlined, bg: bt.accentSoft, fg: bt.accentInk, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              updates > 0 ? '$count ${count == 1 ? 'item needs' : 'items need'} your approval' : '$count ${count == 1 ? 'entry needs' : 'entries need'} your approval',
              style: BtText.headline(context),
            ),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sub.join(' · '), style: BtText.num(BtText.subhead(context))),
            ],
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Bt.placeholder),
      ]),
    );
  }
}

/// Pending approvals on Home for anyone who can approve: count + amount,
/// the top two entries with Approve / Reject…, and "See all" → Approvals.
class _HomeApprovals extends StatefulWidget {
  const _HomeApprovals({super.key});
  @override
  State<_HomeApprovals> createState() => _HomeApprovalsState();
}

class _HomeApprovalsState extends State<_HomeApprovals> {
  List<dynamic> _txs = [];
  int _updates = 0;
  bool _loaded = false;

  /// The last load failed (network / server error) — show Retry instead of
  /// hiding the card as if nothing were waiting.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? data;
    try {
      data = await ApiService.fetchPendingApprovals();
    } catch (_) {
      data = null;
    }
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _failed = data == null;
      // Keep what was shown before when a refresh fails.
      if (data != null) {
        _txs = (data['transactions'] as List?) ?? [];
        _updates = (data['projectUpdates'] as List?)?.length ?? 0;
      }
    });
  }

  void _seeAll() {
    Navigator.pushNamed(context, '/approvals').then((_) {
      if (mounted) _load();
    });
  }

  Future<void> _approve(String id) async {
    final ok = await _approveTx(context, id);
    if (ok && mounted) _load();
  }

  Future<void> _reject(String id) async {
    final confirmed = await _confirmRejectTx(context);
    if (!confirmed || !mounted) return;
    final ok = await _rejectTx(context, id);
    if (ok && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(padding: EdgeInsets.only(bottom: 16), child: BtSkeleton(height: 76, radius: Bt.rCard));
    }
    final total = _txs.length + _updates;
    if (_failed && total == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: BtErrorCard(message: "Couldn't load pending approvals", onRetry: _load),
      );
    }
    if (total == 0) return const SizedBox.shrink();
    final top = _txs.take(2).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BtSectionHeader(title: 'Pending approvals', action: 'See all', onAction: _seeAll),
        _ApprovalsSummaryCard(count: total, amount: _sumAmounts(_txs), updates: _updates, onTap: _seeAll),
        for (var i = 0; i < top.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: BtReveal(
              index: i + 1,
              child: _PendingTxCard(
                tx: top[i] as Map<String, dynamic>,
                onApprove: () => _approve(top[i]['_id']?.toString() ?? ''),
                onReject: () => _reject(top[i]['_id']?.toString() ?? ''),
              ),
            ),
          ),
        if (_txs.length > top.length)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: BtButton(label: 'See all ${_txs.length} approvals', variant: BtButtonVariant.quiet, icon: Icons.arrow_forward_rounded, onPressed: _seeAll),
          ),
      ]),
    );
  }
}

/// Welcome / app-tour prompt (First-Run board): elevation drawing, title,
/// No / Yes. Same callbacks as the old AlertDialog.
class _WelcomeTourDialog extends StatelessWidget {
  const _WelcomeTourDialog({required this.onNo, required this.onYes});
  final VoidCallback onNo;
  final VoidCallback onYes;
  @override
  Widget build(BuildContext context) {
    final reduce = Bt.reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 600),
      curve: Bt.spring,
      builder: (context, t, child) => Transform.scale(scale: .9 + .1 * t, child: Opacity(opacity: t.clamp(0.0, 1.0), child: child)),
      child: Dialog(
        backgroundColor: Bt.card,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rSheet)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Center(child: _WelcomeElevation()),
            const SizedBox(height: 10),
            Text('Welcome to BuildTrack!', textAlign: TextAlign.center, style: BtText.d3(context)),
            const SizedBox(height: 6),
            Text('Do you want an app tour to help you get started?', textAlign: TextAlign.center, style: BtText.body(context, color: Bt.ink2)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: BtButton(label: 'No', variant: BtButtonVariant.secondary, onPressed: onNo)),
              const SizedBox(width: 10),
              Expanded(child: BtButton(label: 'Yes, show me', onPressed: onYes)),
            ]),
            const SizedBox(height: 12),
            Text('You can replay the tour anytime from the ? button.', textAlign: TextAlign.center, style: BtText.caption(context)),
          ]),
        ),
      ),
    );
  }
}

/// Blueprint elevation of a small building with a crane that draws in once.
class _WelcomeElevation extends StatelessWidget {
  const _WelcomeElevation();
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final reduce = Bt.reduceMotion(context);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? 1 : 0, end: 1),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 1200),
        curve: Bt.ease,
        builder: (_, t, _) => CustomPaint(
          size: const Size(180, 150),
          painter: _ElevationPainter(t: t, line: Bt.ink3, accent: bt.accentInk, fill: bt.accentSoft),
        ),
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter({required this.t, required this.line, required this.accent, required this.fill});
  final double t;
  final Color line, accent, fill;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(6, 144), const Offset(174, 144), stroke);
    const body = Rect.fromLTWH(36, 62, 88, 82);
    canvas.drawRect(body, Paint()..color = fill);
    canvas.drawRect(body, stroke);
    canvas.drawPath(Path()..moveTo(28, 66)..lineTo(80, 26)..lineTo(132, 66), stroke);
    canvas.drawRect(const Rect.fromLTWH(68, 106, 24, 38), stroke);
    canvas.drawRect(const Rect.fromLTWH(46, 78, 16, 16), stroke);
    canvas.drawRect(const Rect.fromLTWH(98, 78, 16, 16), stroke);
    final crane = Path()
      ..moveTo(148, 144)
      ..lineTo(148, 24)
      ..lineTo(102, 24)
      ..moveTo(148, 24)
      ..lineTo(170, 24)
      ..moveTo(162, 24)
      ..lineTo(162, 52);
    final accentPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metrics = crane.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    var remaining = total * t;
    for (final m in metrics) {
      if (remaining <= 0) break;
      final len = remaining.clamp(0.0, m.length);
      canvas.drawPath(m.extractPath(0, len), accentPaint);
      remaining -= m.length;
    }
  }

  @override
  bool shouldRepaint(_ElevationPainter old) => old.t != t || old.accent != accent;
}

/// Small static waveform for the "Speak update" card (no loop on Home).
class _StaticWave extends StatelessWidget {
  const _StaticWave({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    const heights = [10.0, 18.0, 24.0, 14.0, 8.0];
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
      for (final h in heights)
        Container(width: 4, height: h, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    ]);
  }
}

/// Money in / Money out switch (Record-Money board).
class _MoneyDirectionToggle extends StatelessWidget {
  const _MoneyDirectionToggle({required this.isInflow, required this.onChanged});
  final bool isInflow;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    Widget seg(bool inflow) {
      final on = inflow == isInflow;
      final bg = on ? (inflow ? Bt.green : Bt.red) : Colors.transparent;
      final fg = on ? Colors.white : Bt.ink2;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: BtPressable(
            onTap: () => onChanged(inflow),
            child: AnimatedContainer(
              duration: Bt.fast,
              curve: Bt.ease,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(inflow ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(inflow ? 'Money In' : 'Money Out', style: BtText.button(context, size: 15, color: fg)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [seg(true), const SizedBox(width: 4), seg(false)]),
    );
  }
}

/// Small "×" used to clear a receipt / signature / image in the money sheet.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Remove',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.cancel, color: Bt.red, size: 20)),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onEdit;
  const _TaskCard({required this.task, this.onEdit});
  @override
  Widget build(BuildContext context) {
    final displayStatus = task.status;
    final done = displayStatus == 'Completed';
    final meta = <String>[
      'Assigned to: ${task.assignee ?? "Unassigned"}',
      task.floorName ?? 'On Site',
    ].join(' · ');
    return Opacity(
      opacity: done ? .62 : 1,
      child: BtRow(
        leading: BtAvatar(name: task.assignee ?? '?', size: 36),
        title: task.title,
        titleColor: done ? Bt.ink2 : Bt.ink,
        subtitle: task.description.isNotEmpty ? '${task.description}\n$meta' : meta,
        subtitleMaxLines: 3,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          BtBadge(label: displayStatus, tone: done ? BtTone.green : (displayStatus == 'Work in Progress' ? BtTone.amber : BtTone.neutral)),
          if (!done && onEdit != null) ...[const SizedBox(width: 4), const Icon(Icons.edit_outlined, size: 18, color: Bt.ink2)],
        ]),
        onTap: !done ? onEdit : null,
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── admin

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard({required this.onEntryTap, required this.top});
  final Future<void> Function(BuildContext, String) onEntryTap;
  final Widget top;
  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}
class _AdminDashboardState extends State<_AdminDashboard> {
  List<dynamic> _revenueEntries = [];
  bool _isGlobalView = true;
  bool _loadingRevenue = false;
  String? _lastProjectId;

  /// Revenue for the selected project failed to load — the card says so
  /// (with Retry) instead of showing ₹0.
  bool _revenueError = false;
  final _approvalsKey = GlobalKey<_HomeApprovalsState>();

  /// Pull-to-refresh: projects + entries (totals), this project's revenue and
  /// the pending-approvals card.
  Future<void> _refresh() async {
    final provider = context.read<ProjectProvider>();
    final projectId = _isGlobalView ? null : provider.selectedProject?.id;
    await Future.wait<void>([
      provider.load().catchError((_) {}),
      if (projectId != null) _loadRevenue(projectId),
      if (_approvalsKey.currentState != null) _approvalsKey.currentState!._load(),
    ]);
  }

  /// Bumped when proof images arrive, so an open Revenue History sheet redraws.
  final ValueNotifier<int> _revenueProofs = ValueNotifier<int>(0);

  @override
  void dispose() {
    _revenueProofs.dispose();
    super.dispose();
  }

  /// The revenue list (`GET /transactions?type=Income`) is served WITHOUT
  /// `attachments` (the backend list query does `.select("-attachments")`),
  /// so rows, the detail sheet and the edit sheet never had the uploaded
  /// image. `GET /transactions/:id` returns it; copy `attachments` (and the
  /// e-sign `paymentReceipt`) onto the row. Rows that already carry the
  /// field are left alone.
  Future<void> _withProof(Map<String, dynamic> tx) async {
    if (tx['attachments'] is List) return;
    final id = (tx['_id'] ?? tx['id'] ?? '').toString();
    if (id.isEmpty) return;
    final full = await ApiService.fetchTransactionById(id);
    if (full == null) return;
    tx['attachments'] = full['attachments'] is List ? full['attachments'] : <dynamic>[];
    tx['paymentReceipt'] ??= full['paymentReceipt'];
  }

  Future<void> _hydrateRevenueProofs(List<dynamic> entries, String projectId) async {
    final rows = entries.whereType<Map<String, dynamic>>().toList();
    for (var i = 0; i < rows.length; i += 6) {
      await Future.wait(rows.skip(i).take(6).map(_withProof));
      if (!mounted || projectId != _lastProjectId) return;
      setState(() {});
      _revenueProofs.value++;
    }
  }

  double get _totalRevenueSum {
    return _revenueEntries.fold<double>(0.0, (sum, tx) {
      final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
      return sum + amount;
    });
  }
  Future<void> _loadRevenue(String projectId) async {
    if (!mounted) return;
    setState(() {
      _loadingRevenue = true;
      _revenueError = false;
    });
    try {
      final response = await ApiService.get(
        '/transactions?project=$projectId&type=Income',
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> entries = [];
        if (decoded is List) {
          entries = decoded;
        } else if (decoded is Map) {
          entries =
              (decoded['transactions'] ?? decoded['data'] ?? [])
                  as List<dynamic>;
        }
        entries.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['date']?.toString() ?? '')?.toLocal() ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['date']?.toString() ?? '')?.toLocal() ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
        if (mounted && projectId == _lastProjectId) {
          setState(() {
            _revenueEntries = entries;
            _loadingRevenue = false;
          });
          _hydrateRevenueProofs(entries, projectId);
        }
      } else {
        if (mounted && projectId == _lastProjectId) {
          setState(() {
            _loadingRevenue = false;
            _revenueError = true;
          });
        }
      }
    } catch (e) {
      if (mounted && projectId == _lastProjectId) {
        setState(() {
          _loadingRevenue = false;
          _revenueError = true;
        });
      }
    }
  }
  void _showAddRevenueDialog(
    BuildContext context,
    String projectId, {
    Map<String, dynamic>? editingTx,
    VoidCallback? onSave,
  }) {
    final titleCtrl = TextEditingController(
      text: editingTx?['title']?.toString() ?? '',
    );
    final double initialAmt =
        double.tryParse(editingTx?['amount']?.toString() ?? '') ?? 0.0;
    final amountCtrl = TextEditingController(
      text: initialAmt != 0.0 ? initialAmt.abs().toString() : '',
    );
    final notesCtrl = TextEditingController(
      text: editingTx?['notes']?.toString() ?? '',
    );
    String selectedMode =
        editingTx?['paymentMode']?.toString() ?? 'Bank Transfer';
    DateTime selectedDate = DateTime.now();
    if (editingTx?['date'] != null) {
      try {
        selectedDate = DateTime.parse(editingTx!['date'].toString()).toLocal();
      } catch (_) {}
    }
    PickedImage? pickedImage;
    // The entry's uploaded image (kept unless replaced / removed). Only known
    // when the row carries `attachments` (see _withProof).
    final bool knowsAttachments = editingTx?['attachments'] is List;
    final List<dynamic> attachments = knowsAttachments ? editingTx!['attachments'] as List : const [];
    String? existingImageUrl = attachments.map((a) => a?.toString() ?? '').firstWhere((a) => a.isNotEmpty, orElse: () => '');
    if (existingImageUrl.isEmpty) existingImageUrl = null;
    // Cash e-signature already on the entry (shown, not editable here).
    final String? existingSignatureUrl = (editingTx?['paymentReceipt']?.toString().isNotEmpty ?? false) ? editingTx!['paymentReceipt'].toString() : null;
    bool isInflow = editingTx != null ? initialAmt >= 0 : true;
    // Sheet state lives OUT here, not inside the sheet builder: the modal
    // route re-runs its builder whenever MediaQuery changes (e.g. the keyboard
    // opening), which used to reset `requestEsign` to false and recreate the
    // email controller — so tapping the client email box made it vanish.
    bool isSaving = false;
    bool isEsignPolling = false;
    bool isEsignCompleted = false;
    String esignStatusText = '';
    bool requestEsign = false;
    final clientEmailCtrl = TextEditingController();
    String? newReceiptDataUri;
    bool sheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Bt.ground,
      barrierColor: Bt.scrim,
      sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 520), curve: Bt.ease, reverseDuration: Duration(milliseconds: 260)),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
      ),
      builder: (ctx) {
        Future<void> startEsignFlow(StateSetter setSheet) async {
          // No setState on a closed sheet (polling can outlive it).
          void ss(VoidCallback f) => sheetOpen ? setSheet(f) : f();
          final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          if (amt <= 0) {
            btToast(context, 'Please enter a valid amount before requesting an E-Signature', error: true);
            return;
          }
          if (clientEmailCtrl.text.isEmpty) {
            btToast(context, 'Please enter client email', error: true);
            return;
          }
          ss(() {
            isEsignPolling = true;
            esignStatusText = 'Sending request...';
          });
          final meta = {
            'projectName': 'BuildTrack Revenue',
            'type': titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Revenue',
            'amount': amt,
            'paymentMethod': selectedMode,
            'notes': notesCtrl.text.trim(),
            'date': selectedDate.toIso8601String(),
          };
          final res = await ApiService.requestEsignature(clientEmailCtrl.text.trim(), meta);
          if (res == null || res['requestId'] == null) {
            ss(() {
              isEsignPolling = false;
              esignStatusText = 'Failed to send request';
            });
            return;
          }
          ss(() {
            esignStatusText = 'Waiting for client to sign...';
          });
          final reqId = res['requestId'];
          while (isEsignPolling && sheetOpen) {
            await Future.delayed(const Duration(seconds: 3));
            if (!isEsignPolling || !sheetOpen) break;
            final statusRes = await ApiService.checkEsignatureStatus(reqId);
            if (statusRes != null && statusRes['status'] == 'signed') {
              ss(() {
                isEsignPolling = false;
                isEsignCompleted = true;
                newReceiptDataUri = statusRes['signatureData'];
                esignStatusText = 'Signature captured!';
              });
              break;
            }
          }
        }
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Widget preview(Widget child) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 80,
                      width: 120,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Bt.fill),
                      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
                    ),
                  ),
                );
            const brokenImage = Center(child: Icon(Icons.broken_image_outlined, color: Bt.ink3));
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BtSheetHeader(
                    title: editingTx != null
                        ? (isInflow ? 'Edit Revenue Inflow' : 'Edit Revenue Outflow')
                        : (isInflow ? 'Record Revenue Inflow' : 'Record Revenue Outflow'),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MoneyDirectionToggle(
                            isInflow: isInflow,
                            onChanged: (v) => setModalState(() {
                              isInflow = v;
                            }),
                          ),
                          const SizedBox(height: 16),
                          BtField(
                            label: 'Payment title / milestone',
                            child: TextField(
                              controller: titleCtrl,
                              textCapitalization: TextCapitalization.sentences,
                              style: BtText.body(context),
                              decoration: btInput(context, hint: 'e.g. Milestone 1 Payment, Advance Payment'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          BtField(
                            label: isInflow ? 'Amount received (₹)' : 'Amount sent (₹)',
                            child: TextField(
                              controller: amountCtrl,
                              keyboardType: TextInputType.number,
                              style: BtText.amount(context, size: 24),
                              decoration: btInput(context, hint: 'e.g. 500000', prefixText: '₹  '),
                            ),
                          ),
                          const SizedBox(height: 14),
                          BtField(
                            label: 'Payment mode',
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final mode in const ['UPI', 'Bank Transfer', 'Cash', 'Cheque'])
                                  BtChip(
                                    label: mode,
                                    selected: selectedMode == mode,
                                    onTap: () => setModalState(() {
                                      selectedMode = mode;
                                    }),
                                  ),
                              ],
                            ),
                          ),
                          if (selectedMode == 'Cash') ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                              decoration: BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(Bt.rInput), border: Border.all(color: Bt.inputBorder)),
                              child: Row(children: [
                                const Icon(Icons.draw_outlined, size: 20, color: Bt.ink2),
                                const SizedBox(width: 10),
                                Expanded(child: Text('Request E-Signature for Cash Receipt', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
                                BtSwitch(value: requestEsign, onChanged: (val) => setModalState(() => requestEsign = val)),
                              ]),
                            ),
                            if (requestEsign) ...[
                              const SizedBox(height: 10),
                              BtField(
                                label: 'Client email address',
                                child: TextField(
                                  controller: clientEmailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  textInputAction: TextInputAction.done,
                                  scrollPadding: const EdgeInsets.only(bottom: 120),
                                  style: BtText.body(context),
                                  decoration: btInput(context, hint: 'client@email.com', prefix: const Icon(Icons.email_outlined, color: Bt.ink3)),
                                ),
                              ),
                            ],
                            if (requestEsign && !isEsignCompleted) ...[
                              const SizedBox(height: 10),
                              BtButton(
                                label: isEsignPolling ? 'Cancel Polling' : 'Send for E-Signature',
                                icon: isEsignPolling ? Icons.close_rounded : Icons.send_rounded,
                                small: true,
                                variant: isEsignPolling ? BtButtonVariant.destructive : BtButtonVariant.secondary,
                                onPressed: isEsignPolling
                                    ? () {
                                        setModalState(() => isEsignPolling = false);
                                      }
                                    : () => startEsignFlow(setModalState),
                              ),
                              if (esignStatusText.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(children: [
                                    if (isEsignPolling) ...[
                                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Bt.amber)),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        esignStatusText,
                                        style: BtText.subhead(context, weight: FontWeight.w600, color: isEsignPolling ? Bt.amber : (isEsignCompleted ? Bt.green : Bt.red)),
                                      ),
                                    ),
                                  ]),
                                ),
                            ],
                            if (isEsignCompleted) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Bt.greenSoft, borderRadius: BorderRadius.circular(Bt.rTile)),
                                child: Row(children: [
                                  const Icon(Icons.check_circle, color: Bt.green),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Signature successfully captured!', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.green))),
                                ]),
                              ),
                            ],
                          ],
                          const SizedBox(height: 14),
                          BtField(
                            label: 'Date received',
                            child: BtPickerField(
                              leading: Icons.calendar_today_outlined,
                              icon: Icons.chevron_right_rounded,
                              text: '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  final now = DateTime.now();
                                  setModalState(() {
                                    selectedDate = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      now.hour,
                                      now.minute,
                                      now.second,
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          BtField(
                            label: 'Notes / remarks',
                            optional: true,
                            child: TextField(
                              controller: notesCtrl,
                              textCapitalization: TextCapitalization.sentences,
                              style: BtText.body(context),
                              decoration: btInput(
                                context,
                                hint: isInflow
                                    ? 'e.g. Initial payment received for start of work'
                                    : 'e.g. Refund sent for milestone delay',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Semantics(
                            button: true,
                            label: 'Upload receipt proof',
                            child: BtPressable(
                              onTap: () async {
                                final img = await pickImageFromGallery(context);
                                if (img != null) {
                                  setModalState(() {
                                    pickedImage = img;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                                decoration: BoxDecoration(
                                  color: Bt.card,
                                  borderRadius: BorderRadius.circular(Bt.rInput),
                                  border: Border.all(color: Bt.inputBorder, width: 1.2),
                                ),
                                child: Row(children: [
                                  const BtTile(icon: Icons.image_outlined, size: 36),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('Upload receipt proof', style: BtText.body(context, weight: FontWeight.w600)),
                                      Text('Optional', style: BtText.caption(context)),
                                    ]),
                                  ),
                                  if (pickedImage != null) ...[
                                    Text('Selected', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.green)),
                                    _ClearButton(onTap: () => setModalState(() {
                                          pickedImage = null;
                                        })),
                                  ] else if (newReceiptDataUri != null) ...[
                                    Text('E-Signature', style: BtText.subhead(context, weight: FontWeight.w600, color: context.bt.accentInk)),
                                    _ClearButton(onTap: () => setModalState(() {
                                          newReceiptDataUri = null;
                                        })),
                                  ] else if (existingImageUrl != null) ...[
                                    Text('Current image', style: BtText.subhead(context, weight: FontWeight.w600, color: context.bt.accentInk)),
                                    _ClearButton(onTap: () => setModalState(() {
                                          existingImageUrl = null;
                                        })),
                                  ] else if (existingSignatureUrl != null) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text('E-Signature', style: BtText.subhead(context, weight: FontWeight.w600, color: context.bt.accentInk)),
                                    ),
                                  ] else
                                    const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.chevron_right_rounded, color: Bt.placeholder)),
                                ]),
                              ),
                            ),
                          ),
                          if (pickedImage != null)
                            preview(
                              FutureBuilder<Uint8List>(
                                future: pickedImage!.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                  }
                                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                },
                              ),
                            )
                          else if (newReceiptDataUri != null)
                            preview(
                              Image.memory(
                                base64Decode(newReceiptDataUri!.split(',').last),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => brokenImage,
                              ),
                            )
                          else if ((existingImageUrl ?? existingSignatureUrl) != null && _proofImageProvider(existingImageUrl ?? existingSignatureUrl) != null)
                            preview(
                              Image(
                                image: _proofImageProvider(existingImageUrl ?? existingSignatureUrl)!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                                },
                                errorBuilder: (context, error, stackTrace) => brokenImage,
                              ),
                            ),
                          const SizedBox(height: 22),
                          BtButton(
                            label: editingTx != null ? 'Save Changes' : 'Save',
                            loading: isSaving,
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final title = titleCtrl.text.trim();
                                    var amount =
                                        double.tryParse(amountCtrl.text.trim()) ??
                                        0.0;
                                    amount = amount.abs();
                                    if (title.isEmpty) {
                                      btToast(context, 'Please enter a payment title', error: true);
                                      return;
                                    }
                                    if (amount <= 0) {
                                      btToast(context, 'Please enter a valid amount', error: true);
                                      return;
                                    }
                                    setModalState(() {
                                      isSaving = true;
                                    });
                                    if (!isInflow) {
                                      amount = -amount;
                                    }
                                    try {
                                      String? base64Image;
                                      if (pickedImage != null) {
                                        final bytes = await pickedImage!
                                            .readAsBytes();
                                        base64Image =
                                            'data:image/jpeg;base64,${base64Encode(bytes)}';
                                      }
                                      final payload = {
                                        'title': title,
                                        'type': 'Income',
                                        'project': projectId,
                                        'amount': amount,
                                        'date': selectedDate.toIso8601String(),
                                        'paymentStatus': 'Paid',
                                        'paymentMode': selectedMode,
                                        'paidAmount': amount,
                                        'notes': notesCtrl.text.trim(),
                                        if (newReceiptDataUri != null) 'paymentReceipt': newReceiptDataUri,
                                        if (newReceiptDataUri != null) 'receiptImage': newReceiptDataUri,
                                        if (base64Image != null) 'receiptImage': base64Image,
                                        // Only send `attachments` when we know the real list —
                                        // otherwise the server keeps what it has (never wipe it).
                                        if (base64Image == null && newReceiptDataUri == null && editingTx != null && knowsAttachments)
                                          'attachments': existingImageUrl != null
                                              ? [existingImageUrl]
                                              : [],
                                      };
                                      final bool isEdit = editingTx != null;
                                      final bool success;
                                      if (isEdit) {
                                        final txId =
                                            editingTx['_id']?.toString() ??
                                            editingTx['id']?.toString() ??
                                            '';
                                        success = await ApiService.updateTransaction(
                                          txId,
                                          payload,
                                        );
                                      } else {
                                        final result =
                                            await ApiService.addTransaction(payload);
                                        success = result != null;
                                      }
                                      if (success) {
                                        if (context.mounted) {
                                          Navigator.pop(ctx);
                                          await showBtSuccess(
                                            context,
                                            kind: BtSuccessKind.money,
                                            title: isEdit ? 'Revenue updated' : 'Revenue recorded',
                                            message: isEdit
                                                ? 'Revenue updated successfully'
                                                : 'Revenue recorded successfully',
                                            label: '${amount < 0 ? 'Money out' : 'Money in'} · ${formatInr(amount.abs())}',
                                          );
                                          if (!context.mounted) return;
                                          context.read<ProjectProvider>().load();
                                          if (onSave != null) {
                                            onSave();
                                          } else {
                                            _loadRevenue(projectId);
                                          }
                                        }
                                      } else {
                                        if (context.mounted) {
                                          btToast(
                                            context,
                                            isEdit
                                                ? 'Failed to update revenue'
                                                : 'Failed to record revenue',
                                            error: true,
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        btToast(context, 'Error: $e', error: true);
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setModalState(() {
                                          isSaving = false;
                                        });
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      sheetOpen = false;
      isEsignPolling = false;
    });
  }

  /// Footer line of the Client money card → opens the revenue timeline.
  Widget _buildRevenueHistory(BuildContext context) {
    if (_loadingRevenue) {
      return const BtSkeleton(height: 16, width: 110, radius: 6);
    }
    if (_revenueError) {
      final id = _lastProjectId;
      return Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: id == null ? null : () => _loadRevenue(id),
          child: Text(
            "Couldn't load · Retry",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BtText.caption(context, color: Bt.red, weight: FontWeight.w600),
          ),
        ),
      );
    }
    final project = Provider.of<ProjectProvider>(
      context,
      listen: false,
    ).selectedProject;
    if (project == null) return const SizedBox.shrink();
    return Text(
      _revenueEntries.isEmpty ? 'View revenue timeline ›' : '${_revenueEntries.length} payments · History ›',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: BtText.caption(context, color: context.bt.accentInk, weight: FontWeight.w600),
    );
  }
  void _showAllRevenueHistory(
    BuildContext context,
    String projectName,
    String projectId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Bt.ground,
      barrierColor: Bt.scrim,
      sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 520), curve: Bt.ease, reverseDuration: Duration(milliseconds: 260)),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => ValueListenableBuilder<int>(
            // Redraw when proof images (thumbnails) arrive.
            valueListenable: _revenueProofs,
            builder: (_, _, _) => DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                final balance = _totalRevenueSum;
                final balanceText = balance == 0
                    ? '₹0'
                    : (balance < 0
                        ? '-${formatCurrency(balance.abs())}'
                        : '+${formatCurrency(balance)}');
                // Month groups (entries are already newest-first).
                final groups = <String, List<dynamic>>{};
                for (final tx in _revenueEntries) {
                  DateTime d = DateTime.now();
                  if (tx['date'] != null) {
                    try {
                      d = DateTime.parse(tx['date'].toString()).toLocal();
                    } catch (_) {}
                  }
                  groups.putIfAbsent('${_getMonthName(d.month)} ${d.year}'.toUpperCase(), () => []).add(tx);
                }
                Future<void> refresh() async {
                  await _loadRevenue(projectId);
                  setSheetState(() {});
                }
                return SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Bt.inputBorder, borderRadius: BorderRadius.circular(3))),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Revenue History', style: BtText.d3(context)),
                                const SizedBox(height: 2),
                                Text(projectName, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
                              ]),
                            ),
                            BtIconButton(icon: Icons.close_rounded, size: 18, semantic: 'Close', background: Bt.fill, onTap: () => Navigator.pop(ctx)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: BtCard(
                          variant: BtCardVariant.ink,
                          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('TOTAL BALANCE', style: BtText.mono(context, color: Bt.onNoir2)),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    balanceText,
                                    style: BtText.d2(context, color: balance > 0 ? Bt.greenBright : (balance < 0 ? Bt.redBright : Bt.bone)),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(width: 12),
                            BtButton(
                              label: 'Record Payment',
                              icon: Icons.add_rounded,
                              small: true,
                              expand: false,
                              variant: BtButtonVariant.accent,
                              onPressed: () {
                                _showAddRevenueDialog(
                                  context,
                                  projectId,
                                  onSave: () async {
                                    await _loadRevenue(projectId);
                                    setSheetState(() {});
                                  },
                                );
                              },
                            ),
                          ]),
                        ),
                      ),
                      Expanded(
                        child: _revenueEntries.isEmpty
                            ? ListView(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                children: const [
                                  BtEmpty(icon: Icons.receipt_long_outlined, title: 'No payments recorded yet', message: 'Money received from or sent to the client shows here.'),
                                ],
                              )
                            : ListView(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                children: [
                                  for (final entry in groups.entries) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                                      child: Text(entry.key, style: BtText.mono(context)),
                                    ),
                                    BtGroup(children: [
                                      for (final tx in entry.value)
                                        _revenueTile(
                                          context,
                                          tx as Map<String, dynamic>,
                                          onRefresh: refresh,
                                        ),
                                    ]),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
  /// Detail sheet needs the entry's image (missing from the list rows until
  /// hydrated) — fetch it first if needed, then open.
  Future<void> _openRevenueDetail(
    BuildContext context,
    Map<String, dynamic> tx, {
    VoidCallback? onRefresh,
  }) async {
    await _withProof(tx);
    if (!context.mounted) return;
    _showRevenueDetailDialog(context, tx, onRefresh: onRefresh);
  }

  void _showRevenueDetailDialog(
    BuildContext context,
    Map<String, dynamic> tx, {
    VoidCallback? onRefresh,
  }) {
    final title = tx['title']?.toString() ?? 'Revenue Inflow';
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
    final bool isOutflow = amount < 0;
    final absAmount = amount.abs();
    final formattedAmt = formatCurrency(absAmount);
    final textColor = isOutflow ? Bt.red : Bt.green;
    final paymentMode = tx['paymentMode']?.toString() ?? 'Cash';
    final paymentStatus = tx['paymentStatus']?.toString() ?? 'Paid';
    final rawId = tx['_id']?.toString() ?? tx['id']?.toString() ?? '';
    final refId = rawId.isNotEmpty ? rawId.toUpperCase() : 'N/A';
    final proofUrl = _revenueProofUrl(tx);
    final proofImage = _proofImageProvider(proofUrl);
    final List<dynamic> attachments = proofUrl != null ? [proofUrl] : [];

    DateTime date = DateTime.now();
    if (tx['date'] != null) {
      try {
        date = DateTime.parse(tx['date'].toString()).toLocal();
      } catch (_) {}
    }
    final dateStr =
        '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)} ${date.year}';
    final timeStr = _formatTime12Hour(date);
    final project = Provider.of<ProjectProvider>(
      context,
      listen: false,
    ).selectedProject;
    final projectName = project?.name ?? 'Project';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Bt.card,
      barrierColor: Bt.scrim,
      sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 520), curve: Bt.ease, reverseDuration: Duration(milliseconds: 260)),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 44),
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Bt.inputBorder, borderRadius: BorderRadius.circular(3))),
                    BtIconButton(icon: Icons.close_rounded, size: 18, semantic: 'Close', background: Bt.fill, onTap: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: isOutflow ? Bt.redSoft : Bt.greenSoft, shape: BoxShape.circle),
                    child: Icon(Icons.check_circle_rounded, color: textColor, size: 40),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isOutflow ? 'Payment Sent' : 'Revenue Received',
                  textAlign: TextAlign.center,
                  style: BtText.d3(context),
                ),
                const SizedBox(height: 4),
                Text(title, textAlign: TextAlign.center, style: BtText.subhead(context)),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isOutflow ? '-$formattedAmt' : '+$formattedAmt',
                    style: BtText.d1(context, color: textColor).copyWith(fontFeatures: BtText.tnum),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: List.generate(
                    30,
                    (index) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 1.2,
                        color: index % 2 == 0 ? Bt.inputBorder : Colors.transparent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _receiptRow('PROJECT', projectName),
                _receiptRow('PAYMENT METHOD', paymentMode),
                _receiptRow(
                  isOutflow ? 'DATE SENT' : 'DATE RECEIVED',
                  dateStr,
                ),
                _receiptRow('TIME RECEIVED', timeStr),
                _receiptRow('REFERENCE ID', refId),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('STATUS', style: BtText.mono(context)),
                      BtBadge(
                        label: paymentStatus.toUpperCase(),
                        tone: paymentStatus.toLowerCase() == 'paid' ? BtTone.green : BtTone.amber,
                      ),
                    ],
                  ),
                ),
                if (tx['notes'] != null &&
                    tx['notes'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(Bt.rInput)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NOTES / REMARKS', style: BtText.mono(context)),
                        const SizedBox(height: 6),
                        Text(tx['notes'].toString().trim(), style: BtText.subhead(context, color: Bt.ink)),
                      ],
                    ),
                  ),
                ],
                if (proofUrl != null && proofImage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(Bt.rInput)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(proofUrl == tx['paymentReceipt']?.toString() ? 'CLIENT E-SIGNATURE' : 'PROOF OF PAYMENT', style: BtText.mono(context)),
                        const SizedBox(height: 8),
                        BtPressable(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/receipt-viewer',
                              arguments: {
                                'receipt': proofUrl,
                              },
                            );
                          },
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image(
                                  image: proofImage,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 150,
                                      color: Bt.card,
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.broken_image_outlined, color: Bt.ink3, size: 32),
                                          const SizedBox(height: 8),
                                          Text('Error loading proof image', style: BtText.caption(context)),
                                        ],
                                      ),
                                    );
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          height: 150,
                                          color: Bt.card,
                                          alignment: Alignment.center,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                        );
                                      },
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(color: Bt.noir.withValues(alpha: .72), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fullscreen, color: Bt.bone, size: 14),
                                    const SizedBox(width: 4),
                                    Text('Tap to zoom', style: BtText.caption(context, color: Bt.bone, weight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                BtButton(
                  label: 'Share Receipt Summary',
                  icon: Icons.share_outlined,
                  variant: BtButtonVariant.secondary,
                  onPressed: () {
                    _shareTransactionReceipt(
                      context,
                      tx,
                      projectName,
                      title,
                      formattedAmt,
                      isOutflow,
                      dateStr,
                      timeStr,
                      refId,
                      attachments,
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: BtButton(
                        label: isOutflow ? 'Delete Outflow…' : 'Delete Inflow…',
                        icon: Icons.delete_outline,
                        variant: BtButtonVariant.destructive,
                        onPressed: () {
                          _confirmDeleteTransaction(context, tx, onRefresh);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BtButton(
                        label: isOutflow ? 'Edit Outflow' : 'Edit Inflow',
                        icon: Icons.edit_outlined,
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddRevenueDialog(
                            context,
                            project?.id ?? tx['project']?.toString() ?? '',
                            editingTx: tx,
                            onSave: onRefresh,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  void _shareTransactionReceipt(
    BuildContext context,
    Map<String, dynamic> tx,
    String projectName,
    String title,
    String formattedAmt,
    bool isOutflow,
    String dateStr,
    String timeStr,
    String refId,
    List<dynamic> attachments,
  ) async {
    try {
      final typeLabel = isOutflow
          ? 'Money Out (Expense)'
          : 'Revenue Received (Inflow)';
      final amountPrefix = isOutflow ? '-₹' : '+₹';
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('📊 BuildTrack Transaction Receipt');
      buffer.writeln('================================');
      buffer.writeln('Type: $typeLabel');
      buffer.writeln('Title: $title');
      buffer.writeln('Amount: $amountPrefix$formattedAmt');
      buffer.writeln('Project: $projectName');
      buffer.writeln(
        'Payment Method: ${tx['paymentMode']?.toString() ?? 'Cash'}',
      );
      buffer.writeln('Date: $dateStr');
      buffer.writeln('Time: $timeStr');
      buffer.writeln('Reference ID: $refId');
      buffer.writeln(
        'Status: ${tx['paymentStatus']?.toString().toUpperCase() ?? 'PAID'}',
      );
      if (tx['notes'] != null && tx['notes'].toString().trim().isNotEmpty) {
        buffer.writeln('Notes: ${tx['notes'].toString().trim()}');
      }
      buffer.writeln('================================');
      buffer.writeln('Generated via BuildTrack App');
      if (attachments.isNotEmpty) {
        final attachmentUrl = attachments.first.toString();
        if (attachmentUrl.startsWith('http')) {
          buffer.writeln('\nProof of Payment: $attachmentUrl');
        }
      }
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          subject: 'Receipt Summary - $projectName',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        btToast(context, 'Error sharing receipt: $e', error: true);
      }
    }
  }
  Future<void> _confirmDeleteTransaction(
    BuildContext context,
    Map<String, dynamic> tx,
    VoidCallback? onRefresh,
  ) async {
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
    final bool isOutflow = amount < 0;
    final String label = isOutflow ? 'outflow' : 'revenue inflow';
    final confirmed = await btConfirm(
      context,
      title: isOutflow ? 'Delete Outflow' : 'Delete Inflow',
      message: 'Are you sure you want to delete this $label record? This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    final txId = tx['_id']?.toString() ?? tx['id']?.toString() ?? '';
    final success = await ApiService.deleteTransaction(txId);
    if (success) {
      if (context.mounted) {
        Navigator.pop(context);
        btToast(context, '${isOutflow ? 'Outflow' : 'Revenue inflow'} record deleted successfully');
        context.read<ProjectProvider>().load();
        if (onRefresh != null) {
          onRefresh();
        }
      }
    } else {
      if (context.mounted) {
        btToast(context, 'Failed to delete ${isOutflow ? 'outflow' : 'revenue inflow'} record', error: true);
      }
    }
  }
  Widget _receiptRow(String label, String value) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: BtText.mono(context)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _revenueTile(
    BuildContext context,
    Map<String, dynamic> tx, {
    VoidCallback? onRefresh,
  }) {
    final title = tx['title']?.toString() ?? 'Revenue Inflow';
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
    final bool isOutflow = amount < 0;
    final absAmount = amount.abs();
    final formattedAmt = formatCurrency(absAmount);
    final textColor = isOutflow ? Bt.ink : Bt.green;
    final paymentMode = tx['paymentMode']?.toString() ?? 'Cash';
    final proofUrl = _revenueProofUrl(tx);
    final proofImage = _proofImageProvider(proofUrl);

    DateTime date = DateTime.now();
    if (tx['date'] != null) {
      try {
        date = DateTime.parse(tx['date'].toString()).toLocal();
      } catch (_) {}
    }
    final dateStr =
        '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)}';
    final timeStr = _formatTime12Hour(date);
    Widget? thumbnail;
    if (proofUrl != null && proofImage != null) {
      thumbnail = Semantics(
        button: true,
        label: 'View proof image',
        child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/receipt-viewer', arguments: {'receipt': proofUrl}),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(10)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(
              image: proofImage,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.broken_image_outlined, color: Bt.ink3, size: 20),
                );
              },
            ),
          ),
        ),
        ),
      );
    }
    return InkWell(
      onTap: () {
        _openRevenueDetail(context, tx, onRefresh: onRefresh);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            BtTile(
              icon: isOutflow ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              bg: isOutflow ? Bt.fill : Bt.greenSoft,
              fg: isOutflow ? Bt.ink2 : Bt.green,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('$dateStr · via $paymentMode · $timeStr', maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
                ],
              ),
            ),
            if (thumbnail != null) ...[const SizedBox(width: 8), thumbnail],
            const SizedBox(width: 10),
            Text(
              isOutflow ? '-$formattedAmt' : '+$formattedAmt',
              style: BtText.num(BtText.body(context, weight: FontWeight.w700, color: textColor)),
            ),
          ],
        ),
      ),
    );
  }
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return 'Jan';
    return months[month - 1];
  }
  String _formatTime12Hour(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $amPm';
  }
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = _isGlobalView ? null : provider.selectedProject;
    final bt = context.bt;

    double gBudget = 0;
    double gSpent = 0;
    double gRev = 0;
    double gProg = 0;
    if (_isGlobalView) {
      for (var p in provider.projects) {
        gBudget += p.totalBudget;
        gSpent += provider.totalSpentForProject(p.id);
        gRev += p.totalIncome;
        gProg += p.progress;
      }
      if (provider.projects.isNotEmpty) gProg /= provider.projects.length;
    }

    if (project != null && project.id != _lastProjectId) {
      _lastProjectId = project.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRevenue(project.id);
      });
    }

    final spent = _isGlobalView ? gSpent : (project != null ? provider.totalSpentForProject(project.id) : 0.0);
    final budget = _isGlobalView ? gBudget : (project?.totalBudget ?? 0.0);
    final remaining = _isGlobalView ? (gBudget - gSpent) : (project?.remainingBudget ?? 0.0);
    final revenue = _isGlobalView ? gRev : (project != null ? _totalRevenueSum : 0.0);
    // Project revenue failed to load and nothing was loaded before: don't
    // show ₹0 / a fake loss.
    final revenueUnknown = !_isGlobalView && project != null && _revenueError && _revenueEntries.isEmpty;
    final netCash = revenue - spent;
    final isLoss = netCash < 0;
    final progress = _isGlobalView ? gProg : (project?.progress ?? 0.0);
    final usedPct = budget > 0 ? (spent / budget) : 0.0;
    final over = budget > 0 && spent > budget * 0.9;
    final hasData = _isGlobalView || project != null;

    final hero = _HomeHero(
      top: widget.top,
      children: [
        const SizedBox(height: 18),
        BtReveal(
          index: 1,
          child: Align(alignment: Alignment.centerLeft, child: _buildProjectSelector(context, provider)),
        ),
        const SizedBox(height: 20),
        Showcase(
          key: ShowcaseKeys.dashboardTotalCost,
          description: 'Total cost so far — everything spent on materials, labour and equipment. Tap the project chip above to switch project or see all projects.',
          tooltipBackgroundColor: Bt.ink,
          textColor: Colors.white,
          tooltipBorderRadius: BorderRadius.circular(16),
          tooltipPadding: const EdgeInsets.all(16),
          child: BtReveal(
            index: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total cost so far', style: BtText.subhead(context, color: Bt.onNoir2)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: hasData
                    ? BtCountUp(value: spent, format: (v) => formatInr(v, compact: true), style: BtText.d0(context, color: Bt.bone))
                    : Text('—', style: BtText.d0(context, color: Bt.bone)),
              ),
              const SizedBox(height: 6),
              if (budget > 0)
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'of ${formatInr(budget, compact: true)} budget · '),
                    TextSpan(
                      text: '${(usedPct * 100).toStringAsFixed(0)}% used',
                      style: TextStyle(color: over ? Bt.redBright : bt.accent, fontWeight: FontWeight.w600),
                    ),
                  ]),
                  style: BtText.num(BtText.subhead(context, color: Bt.onNoir2)),
                )
              else
                Text('No budget set', style: BtText.subhead(context, color: Bt.onNoir2)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        BtReveal(
          index: 3,
          child: BtBricks(value: usedPct.clamp(0.0, 1.0).toDouble(), onDark: true, color: over ? Bt.redBright : null),
        ),
        const SizedBox(height: 16),
        BtReveal(
          index: 4,
          child: Row(children: [
            Expanded(
              child: Showcase(
                key: ShowcaseKeys.dashboardTotalBudget,
                description: 'Budget left — how much of the planned budget is still available.',
                tooltipBackgroundColor: Bt.ink,
                textColor: Colors.white,
                tooltipBorderRadius: BorderRadius.circular(16),
                tooltipPadding: const EdgeInsets.all(16),
                child: BtGlassTile(
                  label: 'Budget left',
                  value: Text(budget > 0 ? formatInr(remaining, compact: true) : '—', maxLines: 1, overflow: TextOverflow.ellipsis),
                  valueColor: remaining < 0 ? Bt.redBright : null,
                ),
              ),
            ),
          ]),
        ),
      ],
    );

    final workDone = Showcase(
      key: ShowcaseKeys.progress,
      description: 'Work done — overall completion of the project.',
      tooltipBackgroundColor: Bt.ink,
      textColor: Colors.white,
      tooltipBorderRadius: BorderRadius.circular(16),
      tooltipPadding: const EdgeInsets.all(16),
      child: BtCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BtRing(
            value: hasData ? progress.clamp(0.0, 1.0).toDouble() : 0,
            size: 68,
            stroke: 7,
            child: Text(
              hasData ? '${(progress * 100).toStringAsFixed(1)}%' : '--',
              style: BtText.num(BtText.caption(context, color: Bt.ink, weight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          Text('Work done', style: BtText.body(context, weight: FontWeight.w600)),
          Text(
            _isGlobalView ? 'All projects' : (project?.name ?? 'No project'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BtText.caption(context),
          ),
          if (project != null && project.city.isNotEmpty)
            Text('${project.city[0].toUpperCase()}${project.city.substring(1)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
        ]),
      ),
    );

    final clientMoney = BtCard(
      padding: const EdgeInsets.all(16),
      onTap: project != null ? () => _showAllRevenueHistory(context, project.name, project.id) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CLIENT MONEY', style: BtText.mono(context)),
        const SizedBox(height: 10),
        Showcase(
          key: ShowcaseKeys.dashboardTotalRevenue,
          description: 'Total revenue — money received from the client. Tap this card to see every payment and record a new one.',
          tooltipBackgroundColor: Bt.ink,
          textColor: Colors.white,
          tooltipBorderRadius: BorderRadius.circular(16),
          tooltipPadding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total revenue', style: BtText.caption(context)),
            Text(revenueUnknown ? '—' : formatInr(revenue, compact: true), maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.num(BtText.headline(context).copyWith(color: Bt.green))),
          ]),
        ),
        const SizedBox(height: 8),
        Showcase(
          key: ShowcaseKeys.dashboardNetCashFlow,
          description: 'Net cash flow — revenue minus cost, so you see profit or loss at a glance.',
          tooltipBackgroundColor: Bt.ink,
          textColor: Colors.white,
          tooltipBorderRadius: BorderRadius.circular(16),
          tooltipPadding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isLoss ? 'Net cash flow · loss' : 'Net cash flow · profit', maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
            Text(revenueUnknown ? '—' : formatInr(netCash, compact: true), maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.num(BtText.headline(context).copyWith(color: revenueUnknown ? Bt.ink2 : (isLoss ? Bt.red : Bt.green)))),
          ]),
        ),
        if (project != null) ...[
          const SizedBox(height: 10),
          _buildRevenueHistory(context),
        ],
      ]),
    );

    return BtHeroScroll(
      hero: hero,
      onRefresh: _refresh,
      children: [
        if (RoleManager.canApproveUpdates) _HomeApprovals(key: _approvalsKey),
        BtReveal(index: 1, child: _buildSpeakUpdate(context)),
        const SizedBox(height: 12),
        BtReveal(
          index: 2,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: workDone),
              const SizedBox(width: 12),
              Expanded(child: clientMoney),
            ]),
          ),
        ),
        const SizedBox(height: 28),
        BtReveal(
          index: 3,
          child: Showcase(
            key: ShowcaseKeys.recentEntries,
            description: 'Recent activity — your team\'s approved / rejected entries and the latest entries. "View all" opens the full log.',
            tooltipBackgroundColor: Bt.ink,
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: _buildRecentActivity(context),
          ),
        ),
        const _PoweredByFooter(),
      ],
    );
  }

  Widget _buildProjectSelector(BuildContext context, ProjectProvider provider) {
    final selectedName = _isGlobalView ? 'Global Financial Overview' : (provider.selectedProject?.name ?? 'Select Project');
    return BtChip(
      onDark: true,
      icon: _isGlobalView ? Icons.public : Icons.apartment_outlined,
      label: selectedName.length > 34 ? '${selectedName.substring(0, 32)}…' : selectedName,
      trailingIcon: Icons.expand_more_rounded,
      onTap: () => _showProjectPicker(context, provider),
    );
  }
  void _showProjectPicker(BuildContext context, ProjectProvider provider) {
    final projects = provider.projects;
    Widget option({required bool selected, required IconData icon, required String label, required VoidCallback onTap}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Semantics(
          button: true,
          selected: selected,
          child: BtPressable(
            onTap: onTap,
            child: AnimatedContainer(
              duration: Bt.fast,
              curve: Bt.ease,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: selected ? Bt.ink : Bt.ground,
                borderRadius: BorderRadius.circular(Bt.rInput),
              ),
              child: Row(
                children: [
                  Icon(icon, color: selected ? Bt.bone : Bt.ink2, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: BtText.body(context, weight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? Bt.bone : Bt.ink),
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle_rounded, color: context.bt.accent, size: 20),
                ],
              ),
            ),
          ),
        ),
      );
    }

    showBtSheet<void>(
      context,
      title: 'Select Project',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          option(
            selected: _isGlobalView,
            icon: Icons.public,
            label: 'Global Financial Overview (All Projects)',
            onTap: () {
              setState(() { _isGlobalView = true; });
              Navigator.pop(context);
            },
          ),
          ...projects.map((p) {
            final selected = !_isGlobalView && p.id == provider.selectedProject?.id;
            return option(
              selected: selected,
              icon: Icons.apartment_outlined,
              label: p.name,
              onTap: () {
                setState(() { _isGlobalView = false; }); provider.selectProject(p);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }
  Widget _buildSpeakUpdate(BuildContext context) {
    final bt = context.bt;
    return Showcase(
      key: ShowcaseKeys.quickAddEntry,
      description: 'Speak Update — say what happened and we fill in the entry form for you.',
      tooltipBackgroundColor: Bt.ink,
      textColor: Colors.white,
      tooltipBorderRadius: BorderRadius.circular(16),
      tooltipPadding: const EdgeInsets.all(16),
      child: Semantics(
        button: true,
        label: 'Speak Update',
        child: BtCard(
          variant: BtCardVariant.ink,
          padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
          onTap: () => Navigator.pushNamed(context, '/add-entry'),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: bt.accent, shape: BoxShape.circle),
              child: Icon(Icons.mic_rounded, color: bt.onAccent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Speak Update', style: BtText.headline(context).copyWith(color: Bt.bone)),
                Text('Say what happened — we fill the form', maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, color: Bt.onNoir2)),
              ]),
            ),
            const SizedBox(width: 8),
            _StaticWave(color: bt.accent),
          ]),
        ),
      ),
    );
  }
  Widget _buildRecentActivity(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final selectedProjectId = provider.selectedProject?.id;
    final List<EntryModel> allEntries = selectedProjectId == null
        ? <EntryModel>[]
        : provider
              .entriesForProject(selectedProjectId)
              .where((e) => e.approvalStatus.toLowerCase().trim() != 'rejected')
              .toList();
    allEntries.sort((a, b) => b.date.compareTo(a.date));
    final recent = allEntries.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtSectionHeader(
          title: 'Recent activity',
          action: 'View all',
          onAction: () => Navigator.pushNamed(
            context,
            '/logs',
            arguments: {'projectId': selectedProjectId},
          ),
        ),
        _TeamApprovalHistoryWidget(projectId: selectedProjectId),
        const SizedBox(height: 24),
        const BtSectionHeader(title: 'Recent entries'),
        if (recent.isEmpty)
          const BtCard(
            child: BtEmpty(icon: Icons.history_toggle_off_rounded, title: 'No recent entries', message: 'Updates you speak or enter will appear here.'),
          )
        else
          BtGroup(children: [for (final entry in recent) _activityTile(context, entry)]),
      ],
    );
  }
  Widget _activityTile(BuildContext context, EntryModel entry) {
    final String badgeLabel;
    final BtTone tone;
    switch (entry.type) {
      case EntryType.labour:
        badgeLabel = 'Labour';
        tone = BtTone.green;
        break;
      case EntryType.equipment:
        badgeLabel = 'Equipment';
        tone = BtTone.amber;
        break;
      case EntryType.material:
        badgeLabel = 'Material';
        tone = BtTone.brand;
        break;
    }
    final timeLabel = relativeTimeLabel(entry.createdAt.toLocal());
    final title = entry.description.isNotEmpty ? entry.description : badgeLabel;
    return BtRow(
      leading: BtTypeTile(type: badgeLabel),
      title: title,
      subtitle: '${formatInr(entry.amount)} · $timeLabel',
      trailing: BtBadge(label: badgeLabel, tone: tone),
      onTap: () => Navigator.pushNamed(context, '/logs'),
    );
  }
}

// ───────────────────────────────────────────────────────── supervisor

class _SupervisorDashboard extends StatefulWidget {
  const _SupervisorDashboard({required this.top});
  final Widget top;
  @override
  State<_SupervisorDashboard> createState() => _SupervisorDashboardState();
}
class _SupervisorDashboardState extends State<_SupervisorDashboard> {
  List<dynamic> _pendingTransactions = [];
  List<dynamic> _historyTransactions = [];
  int _pendingUpdates = 0;
  List<TaskModel> _tasks = [];
  bool _isLoading = true;
  String? _error;
  bool _tasksError = false;
  String _activeTab = 'pending';
  @override
  void initState() {
    super.initState();
    _loadAll();
  }
  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    // Each call fails on its own (getDailyTasks throws on errors; before, one
    // failure left the whole Home stuck on skeletons).
    final results = await Future.wait<Object?>([
      ApiService.fetchPendingApprovals().catchError((_) => null),
      ApiService.fetchApprovalsHistory().catchError((_) => null),
      TaskService.getDailyTasks().then<List<TaskModel>?>((t) => t).catchError((_) => null),
    ]);
    if (!mounted) return;
    final pendingData = results[0] as Map<String, dynamic>?;
    final historyData = results[1] as Map<String, dynamic>?;
    final tasksData = results[2] as List<TaskModel>?;
    setState(() {
      if (pendingData != null) {
        _pendingTransactions = (pendingData['transactions'] as List?) ?? [];
        _pendingUpdates = (pendingData['projectUpdates'] as List?)?.length ?? 0;
      }
      if (historyData != null) _historyTransactions = (historyData['transactions'] as List?) ?? [];
      if (tasksData != null) _tasks = tasksData;
      _tasksError = tasksData == null;
      _isLoading = false;
      // Pending approvals are the point of this Home — a failed load is an
      // error (with Retry), not "No pending approvals".
      if (pendingData == null) {
        _error = "Couldn't load approvals. Check your connection.";
      }
    });
  }
  Future<void> _handleApprove(String id) async {
    final ok = await _approveTx(context, id);
    if (!mounted) return;
    if (ok) {
      _loadAll();
    }
  }
  Future<void> _handleReject(String id) async {
    final ok = await _rejectTx(context, id);
    if (!mounted) return;
    if (ok) {
      _loadAll();
    }
  }
  Future<void> _confirmReject(String id) async {
    final ok = await _confirmRejectTx(context);
    if (ok) _handleReject(id);
  }
  void _openInbox() {
    Navigator.pushNamed(context, '/approvals').then((_) {
      if (mounted) _loadAll();
    });
  }
  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingTransactions.length;
    final approvedCount = _historyTransactions
        .where((t) => t['approvalStatus'] == 'Approved')
        .length;
    final rejectedCount = _historyTransactions
        .where((t) => t['approvalStatus'] == 'Rejected')
        .length;
    final pendingSum = _sumAmounts(_pendingTransactions);

    Widget counter(String key, String label, int count) => Expanded(
          child: Semantics(
            selected: _activeTab == key,
            child: BtGlassTile(
              label: label,
              selected: _activeTab == key,
              value: BtCountUp(value: count.toDouble(), format: (v) => '${v.round()}', duration: const Duration(milliseconds: 800)),
              onTap: () => setState(() => _activeTab = key),
            ),
          ),
        );

    final hero = _HomeHero(
      top: widget.top,
      children: [
        const SizedBox(height: 24),
        BtReveal(
          index: 1,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            BtCountUp(
              value: pendingCount.toDouble(),
              format: (v) => '${v.round()}',
              style: BtText.d0(context, color: Bt.bone).copyWith(fontSize: 72, letterSpacing: -3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('waiting for you', style: BtText.headline(context).copyWith(color: Bt.bone)),
                  Text(
                    _isLoading
                        ? 'Checking approvals…'
                        : '${formatInr(pendingSum)} across $pendingCount ${pendingCount == 1 ? 'entry' : 'entries'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BtText.num(BtText.subhead(context, color: Bt.onNoir2)),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        BtReveal(
          index: 2,
          child: Row(children: [
            counter('pending', 'Pending', pendingCount),
            const SizedBox(width: 8),
            counter('approved', 'Approved', approvedCount),
            const SizedBox(width: 8),
            counter('rejected', 'Rejected', rejectedCount),
          ]),
        ),
      ],
    );

    return BtHeroScroll(
      hero: hero,
      onRefresh: _loadAll,
      children: [
        BtReveal(
          index: 1,
          child: Row(children: [
            if (RoleManager.canAssignTasks) ...[
              Expanded(
                child: BtButton(
                  label: 'Assign Task',
                  icon: Icons.assignment_turned_in_outlined,
                  // Back from Assign Task → refresh "Tasks assigned".
                  onPressed: () => Navigator.pushNamed(context, '/assign-task').then((_) {
                    if (mounted) _loadAll();
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'Refresh',
                child: BtPressable(
                  onTap: _loadAll,
                  child: Container(
                    width: Bt.buttonH,
                    height: Bt.buttonH,
                    decoration: BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(Bt.rButton), boxShadow: Bt.shadow),
                    child: const Icon(Icons.refresh_rounded, color: Bt.ink),
                  ),
                ),
              ),
            ] else
              Expanded(child: BtButton(label: 'Refresh', icon: Icons.refresh_rounded, variant: BtButtonVariant.secondary, onPressed: _loadAll)),
          ]),
        ),
        const SizedBox(height: 24),
        if (_isLoading)
          const BtSkeletonList(count: 3)
        else if (_error != null)
          BtErrorCard(message: _error!, onRetry: _loadAll)
        else
          _buildActiveTabContent(
            pendingCount: pendingCount,
            approvedCount: approvedCount,
            rejectedCount: rejectedCount,
            pendingSum: pendingSum,
          ),
        const SizedBox(height: 28),
        BtSectionHeader(
          title: 'Tasks assigned',
          action: _tasks.isEmpty ? null : '${_tasks.where((t) => t.status != 'Completed').length} open',
        ),
        if (!_isLoading && _tasksError && _tasks.isEmpty)
          BtErrorCard(message: "Couldn't load tasks", onRetry: _loadAll)
        else if (_tasks.isEmpty)
          const BtCard(child: BtEmpty(icon: Icons.task_alt, title: 'No tasks currently active.'))
        else
          BtGroup(children: [
            for (final task in _tasks)
              _TaskCard(
                task: task,
                onEdit: () => Navigator.pushNamed(context, '/update-progress', arguments: {'task': task}).then((_) {
                  if (context.mounted) _loadAll();
                }),
              ),
          ]),
        if (!_isLoading && _error == null && _activeTab == 'pending') ...[
          const SizedBox(height: 28),
          _buildRecentHistorySection(),
        ],
        const _PoweredByFooter(),
      ],
    );
  }
  Widget _buildActiveTabContent({
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
    required double pendingSum,
  }) {
    switch (_activeTab) {
      case 'approved':
        final approved = _historyTransactions
            .where((t) => t['approvalStatus'] == 'Approved')
            .toList();
        return _buildHistoryList(
          items: approved,
          emptyMessage: 'No approved entries yet',
          emptyIcon: Icons.check_circle_outline,
          emptyColor: Bt.green,
        );
      case 'rejected':
        final rejected = _historyTransactions
            .where((t) => t['approvalStatus'] == 'Rejected')
            .toList();
        return _buildHistoryList(
          items: rejected,
          emptyMessage: 'No rejected entries',
          emptyIcon: Icons.cancel_outlined,
          emptyColor: Bt.red,
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BtSectionHeader(title: 'Pending approvals', action: 'See all', onAction: _openInbox),
            if (pendingCount == 0 && _pendingUpdates == 0)
              const BtCard(child: BtEmpty(icon: Icons.check_circle_outline, title: 'No pending approvals', message: 'Pull down to refresh'))
            else ...[
              // Project updates are approved on the Approvals screen (See all).
              _ApprovalsSummaryCard(count: pendingCount + _pendingUpdates, amount: pendingSum, updates: _pendingUpdates, onTap: _openInbox),
              for (var i = 0; i < _pendingTransactions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: BtReveal(
                    index: i < 8 ? i + 1 : 0,
                    child: _PendingTxCard(
                      tx: _pendingTransactions[i] as Map<String, dynamic>,
                      // PUT /transactions/:id/approve|reject need approve_payments /
                      // approve_updates (or add_entries); others only see the queue.
                      onApprove: RoleManager.canApproveUpdates ? () => _handleApprove(_pendingTransactions[i]['_id']?.toString() ?? '') : null,
                      onReject: RoleManager.canApproveUpdates ? () => _confirmReject(_pendingTransactions[i]['_id']?.toString() ?? '') : null,
                    ),
                  ),
                ),
            ],
          ],
        );
    }
  }
  Widget _buildRecentHistorySection() {
    final combined =
        _historyTransactions
            .where(
              (t) =>
                  t['approvalStatus'] == 'Approved' ||
                  t['approvalStatus'] == 'Rejected',
            )
            .toList()
          ..sort((a, b) {
            DateTime parse(dynamic tx) {
              final raw = tx['approvedAt'] ?? tx['date'] ?? tx['createdAt'];
              try {
                return DateTime.parse(raw.toString()).toLocal();
              } catch (_) {
                return DateTime.fromMillisecondsSinceEpoch(0);
              }
            }
            return parse(b).compareTo(parse(a));
          });
    final recent = combined.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BtSectionHeader(title: 'Recent history'),
        if (recent.isEmpty)
          const BtCard(child: BtEmpty(icon: Icons.history, title: 'No history yet'))
        else
          BtGroup(children: [for (final tx in recent) _HistoryTxCard(tx: tx as Map<String, dynamic>)]),
      ],
    );
  }
  Widget _buildHistoryList({
    required List<dynamic> items,
    required String emptyMessage,
    required IconData emptyIcon,
    required Color emptyColor,
  }) {
    if (items.isEmpty) {
      return BtCard(
        child: BtEmpty(icon: emptyIcon, title: emptyMessage, message: 'Total history loaded: ${_historyTransactions.length}'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtSectionHeader(title: _activeTab == 'approved' ? 'Recently approved' : 'Recently rejected'),
        BtGroup(children: [for (final tx in items) _HistoryTxCard(tx: tx as Map<String, dynamic>)]),
      ],
    );
  }
}
class _PendingTxCard extends StatelessWidget {
  const _PendingTxCard({
    required this.tx,
    required this.onApprove,
    required this.onReject,
  });
  final Map<String, dynamic> tx;
  /// Null when the viewer may not approve/reject: the buttons are left out.
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  @override
  Widget build(BuildContext context) {
    final title = tx['title']?.toString() ?? 'Entry';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final type = tx['type']?.toString() ?? '';
    final role = _txRole(tx);
    final dateStr = _txDate(tx['date'] ?? tx['createdAt']);
    return BtCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BtTypeTile(type: _txTypeWord(type, title)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w600)),
              Text('${_txWho(tx)}${role.isNotEmpty ? ' · $role' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
              Text([_txProject(tx), dateStr].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(formatInr(amount), style: BtText.num(BtText.headline(context))),
        ]),
        if (onApprove != null && onReject != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: BtButton(label: 'Reject…', variant: BtButtonVariant.destructive, small: true, onPressed: onReject)),
            const SizedBox(width: 10),
            Expanded(child: BtButton(label: 'Approve', icon: Icons.check_rounded, small: true, onPressed: onApprove)),
          ]),
        ],
      ]),
    );
  }
}
class _HistoryTxCard extends StatelessWidget {
  const _HistoryTxCard({required this.tx});
  final Map<String, dynamic> tx;
  @override
  Widget build(BuildContext context) {
    final title = tx['title']?.toString() ?? 'Entry';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final type = tx['type']?.toString() ?? '';
    final approvalStatus = tx['approvalStatus']?.toString() ?? '';
    final approvedByName =
        (tx['approvedBy'] is Map ? tx['approvedBy']['name'] : null)?.toString();
    final rejectionReason = tx['rejectionReason']?.toString() ?? '';
    final dateStr = _txDate(tx['approvedAt'] ?? tx['date'] ?? tx['createdAt']);
    final bool isApproved = approvalStatus == 'Approved';
    final lines = <String>[
      _txWho(tx),
      [_txProject(tx), dateStr].where((x) => x.isNotEmpty).join(' · '),
      if (approvedByName != null) isApproved ? 'Approved by $approvedByName' : 'Rejected by $approvedByName',
      if (!isApproved && rejectionReason.isNotEmpty) 'Reason: $rejectionReason',
    ];
    return BtRow(
      leading: BtTypeTile(type: _txTypeWord(type, title)),
      title: title,
      subtitle: lines.join('\n'),
      subtitleMaxLines: 4,
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(formatInr(amount), style: BtText.num(BtText.body(context, weight: FontWeight.w600))),
        const SizedBox(height: 4),
        BtBadge(label: approvalStatus, tone: isApproved ? BtTone.green : BtTone.red),
      ]),
    );
  }
}

// ───────────────────────────────────────────────────────── mason

/// Big square action on the Mason home (Home-Mason board).
class _BigAction extends StatelessWidget {
  const _BigAction({required this.icon, required this.title, required this.subtitle, required this.onTap, this.ink = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool ink;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      button: true,
      label: title,
      child: BtCard(
        variant: ink ? BtCardVariant.ink : BtCardVariant.plain,
        padding: const EdgeInsets.all(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 132),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            BtTile(icon: icon, bg: ink ? bt.accent : bt.accentSoft, fg: ink ? bt.onAccent : bt.accentInk),
            const SizedBox(height: 24),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: BtText.headline(context).copyWith(color: ink ? Bt.bone : Bt.ink)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, color: ink ? Bt.onNoir2 : Bt.ink2)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _MasonDashboard extends StatefulWidget {
  const _MasonDashboard({required this.onEntryTap, required this.top});
  final Future<void> Function(BuildContext, String) onEntryTap;
  final Widget top;
  @override
  State<_MasonDashboard> createState() => _MasonDashboardState();
}
class _MasonDashboardState extends State<_MasonDashboard> {
  late Future<List<dynamic>> _recentEntriesFuture;
  List<TaskModel> _tasks = [];
  bool _isLoadingTasks = true;
  bool _tasksError = false;
  final _approvalsKey = GlobalKey<_HomeApprovalsState>();
  @override
  void initState() {
    super.initState();
    final projectId = context.read<ProjectProvider>().selectedProject?.id;
    _recentEntriesFuture = _fetchOwnRecentEntries(projectId);
    _loadTasks();
  }

  /// Pull-to-refresh (and after adding an entry): tasks, own recent entries
  /// and the approvals card — same idea as the Supervisor Home's reload.
  Future<void> _refresh() async {
    if (!mounted) return;
    final projectId = context.read<ProjectProvider>().selectedProject?.id;
    final entries = _fetchOwnRecentEntries(projectId);
    setState(() => _recentEntriesFuture = entries);
    await Future.wait<void>([
      _loadTasks(),
      entries.then<void>((_) {}, onError: (_) {}),
      if (_approvalsKey.currentState != null) _approvalsKey.currentState!._load(),
    ]);
  }

  /// The mason's OWN recent entries. `fetchMyRecentEntries` reads
  /// `/transactions?filterByViewAccess=true`, which returns every entry on the
  /// mason's projects — incl. admin / supervisor entries. `/transactions/my`
  /// is scoped to `createdBy = me` server-side; the creator check below is a
  /// second guard. Same filters as before otherwise (no revenue, approved
  /// only, current project when one is selected, newest first).
  static Future<List<dynamic>> _fetchOwnRecentEntries(String? projectId) async {
    final me = UserSession.userId;
    String idOf(dynamic v) => v is Map ? (v['_id'] ?? v['id'] ?? '').toString() : (v ?? '').toString();
    try {
      final response = await ApiService.get('/transactions/my?limit=50');
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final decoded = json.decode(response.body);
      final List<dynamic> raw = decoded is List ? decoded : ((decoded['transactions'] ?? decoded['data'] ?? []) as List<dynamic>);
      final own = raw.where((e) {
        if (e is! Map<String, dynamic>) return false;
        if (me.isNotEmpty && idOf(e['createdBy']) != me) return false;
        final type = (e['type'] ?? '').toString().toLowerCase().trim();
        if (type == 'income' || type == 'revenue') return false;
        if ((e['approvalStatus'] ?? '').toString().toLowerCase().trim() != 'approved') return false;
        if (projectId != null && projectId.isNotEmpty && e['project'] != null && idOf(e['project']) != projectId) return false;
        return true;
      }).toList()
        ..sort((a, b) => (b['date'] ?? b['createdAt'] ?? '').toString().compareTo((a['date'] ?? a['createdAt'] ?? '').toString()));
      return own;
    } catch (e) {
      // Surface as an error (FutureBuilder shows Retry), not "No entries yet".
      debugPrint('Mason recent entries error: $e');
      rethrow;
    }
  }
  Future<void> _loadTasks() async {
    try {
      final tasks = await TaskService.getDailyTasks();
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoadingTasks = false;
          _tasksError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
          _tasksError = true;
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final projectName = context.watch<ProjectProvider>().selectedProject?.name;
    final openTasks = _tasks.where((t) => t.status != 'Completed').length;
    // Only offer what the backend accepts: daily update = PUT /projects/:id
    // (role/permission, or a task assigned to me on the project); material
    // entry = POST /transactions (manage_expenses / add_entries).
    final me = UserSession.userId;
    final canDailyUpdate = RoleManager.canSubmitProjectUpdate ||
        _tasks.any((t) => me.isNotEmpty && (t.assignedTo?['_id'] ?? t.assignedTo?['id'])?.toString() == me);
    final canMaterialEntry = RoleManager.canAddTransactions;
    final hero = _HomeHero(
      top: widget.top,
      children: [
        const SizedBox(height: 26),
        BtReveal(
          index: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text('What did you do today?', style: BtText.d1(context, color: Bt.bone)),
          ),
        ),
        const SizedBox(height: 8),
        BtReveal(
          index: 2,
          child: Text(
            (projectName != null && projectName.isNotEmpty) ? projectName : 'Ready for today\'s work',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BtText.body(context, color: Bt.onNoir2),
          ),
        ),
      ],
    );
    return BtHeroScroll(
      hero: hero,
      onRefresh: _refresh,
      children: [
        if (canDailyUpdate || canMaterialEntry) ...[
        BtReveal(
          index: 1,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (canDailyUpdate)
              Expanded(
                child: _BigAction(
                  ink: true,
                  icon: Icons.add_task_rounded,
                  title: 'Add Daily Update',
                  subtitle: 'Work, photos, notes',
                  onTap: () => Navigator.pushNamed(context, '/update-progress').then((_) {
                    if (mounted) _refresh();
                  }),
                ),
              ),
              if (canDailyUpdate && canMaterialEntry) const SizedBox(width: 12),
              if (canMaterialEntry)
              Expanded(
                child: _BigAction(
                  icon: Icons.inventory_2_outlined,
                  title: 'Add Material Entry',
                  subtitle: 'Cement, steel, bricks…',
                  // Same flow as the + sheet's "Material" choice.
                  onTap: () => widget.onEntryTap(context, 'material').then((_) {
                    if (mounted) _refresh();
                  }),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        ],
        if (RoleManager.canApproveUpdates) _HomeApprovals(key: _approvalsKey),
        BtSectionHeader(title: 'Tasks assigned', action: _isLoadingTasks || _tasks.isEmpty ? null : '$openTasks open'),
        if (_isLoadingTasks)
          const BtSkeletonList(count: 2)
        else if (_tasksError && _tasks.isEmpty)
          BtErrorCard(message: "Couldn't load tasks", onRetry: _loadTasks)
        else if (_tasks.isEmpty)
          const BtCard(child: BtEmpty(icon: Icons.task_alt, title: 'No tasks currently active.'))
        else
          BtReveal(
            index: 2,
            child: BtGroup(children: [
              for (final task in _tasks)
                _TaskCard(
                  task: task,
                  onEdit: task.status != 'Completed'
                      ? () => Navigator.pushNamed(context, '/update-progress', arguments: {'task': task}).then((_) {
                          if (context.mounted) _loadTasks();
                        })
                      : null,
                ),
            ]),
          ),
        const SizedBox(height: 28),
        BtSectionHeader(
          title: 'Recent entries',
          action: 'View all',
          onAction: () => Navigator.pushNamed(context, '/logs'),
        ),
        FutureBuilder<List<dynamic>>(
          future: _recentEntriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const BtSkeletonList(count: 3);
            }
            if (snapshot.hasError) {
              return BtErrorCard(message: "Couldn't load recent entries.", onRetry: _refresh);
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const BtCard(child: BtEmpty(icon: Icons.inbox_outlined, title: 'No entries yet'));
            }
            return BtReveal(
              index: 3,
              child: BtGroup(children: [
                for (final e in entries.take(5)) _recentEntryTile(e as Map<String, dynamic>),
              ]),
            );
          },
        ),
        const _PoweredByFooter(),
      ],
    );
  }
  Widget _recentEntryTile(Map<String, dynamic> entry) {
    final title =
        entry['title']?.toString() ??
        entry['description']?.toString() ??
        'Entry';
    final type = entry['type']?.toString() ?? '';
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0.0;
    final approvalStatus = entry['approvalStatus']?.toString() ?? 'Pending';
    final rawDate = entry['date'] ?? entry['createdAt'];
    String timeLabel = '';
    if (rawDate != null) {
      try {
        final d = DateTime.parse(rawDate.toString()).toLocal();
        timeLabel = relativeTimeLabel(d);
      } catch (_) {}
    }
    return BtRow(
      leading: BtTypeTile(type: _txTypeWord(type, title)),
      title: title,
      subtitle: [formatInr(amount), timeLabel].where((x) => x.isNotEmpty).join(' · '),
      trailing: BtBadge(label: approvalStatus, tone: BtBadge.toneFor(approvalStatus)),
      onTap: () => Navigator.pushNamed(context, '/logs'),
    );
  }
}

/// Kept for compatibility (public). Home now shows [_HomeApprovals] instead.
class ApprovalsAlertWidget extends StatefulWidget {
  const ApprovalsAlertWidget({super.key});
  @override
  State<ApprovalsAlertWidget> createState() => _ApprovalsAlertWidgetState();
}
class _ApprovalsAlertWidgetState extends State<ApprovalsAlertWidget> {
  int _pendingCount = 0;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    _loadCount();
  }
  Future<void> _loadCount() async {
    final data = await ApiService.fetchPendingApprovals();
    if (mounted) {
      setState(() {
        final txs = (data?['transactions'] as List?)?.length ?? 0;
        final updates = (data?['projectUpdates'] as List?)?.length ?? 0;
        _pendingCount = txs + updates;
        _loaded = true;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_loaded && _pendingCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BtCard(
        variant: BtCardVariant.attention,
        onTap: () => Navigator.pushNamed(context, '/approvals'),
        child: Row(children: [
          BtTile(icon: Icons.inbox_outlined, bg: context.bt.accentSoft, fg: context.bt.accentInk, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _loaded ? '$_pendingCount Approval${_pendingCount == 1 ? "" : "s"} Pending' : 'Checking Approvals…',
                style: BtText.headline(context),
              ),
              const SizedBox(height: 2),
              Text('Review pending project updates and expenses.', style: BtText.subhead(context)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Bt.placeholder),
        ]),
      ),
    );
  }
}
class _TeamApprovalHistoryWidget extends StatefulWidget {
  final String? projectId;
  const _TeamApprovalHistoryWidget({this.projectId});
  @override
  State<_TeamApprovalHistoryWidget> createState() =>
      _TeamApprovalHistoryWidgetState();
}
class _TeamApprovalHistoryWidgetState
    extends State<_TeamApprovalHistoryWidget> {
  List<dynamic> _history = [];
  bool _loading = true;
  bool _expanded = false;
  @override
  void initState() {
    super.initState();
    _load();
  }
  @override
  void didUpdateWidget(_TeamApprovalHistoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      setState(() {
        _loading = true;
        _history = [];
        _expanded = false;
      });
      _load();
    }
  }
  Future<void> _load() async {
    try {
      final data = await ApiService.fetchApprovalsHistory();
      final List<dynamic> all = (data?['transactions'] as List?) ?? [];
      final filtered =
          all.where((t) {
            final status = (t['approvalStatus']?.toString() ?? '')
                .trim()
                .toLowerCase();
            final isActioned = status == 'approved' || status == 'rejected';
            if (!isActioned) return false;
            final createdByRole =
                (t['createdBy'] is Map ? t['createdBy']['role'] : null)
                    ?.toString()
                    .toLowerCase()
                    .trim();
            if (createdByRole == 'admin') return false;
            if (widget.projectId != null &&
                widget.projectId!.trim().isNotEmpty) {
              String txProjectId = '';
              final rawProj = t['project'];
              if (rawProj is Map) {
                txProjectId = rawProj['_id']?.toString() ?? '';
              } else if (rawProj != null) {
                txProjectId = rawProj.toString();
              }
              final wantedId = widget.projectId!.trim();
              if (txProjectId.trim().isNotEmpty &&
                  txProjectId.trim() != wantedId) {
                return false;
              }
            }
            return true;
          }).toList()..sort((a, b) {
            DateTime parse(dynamic tx) {
              final raw =
                  tx['approvedAt'] ??
                  tx['rejectedAt'] ??
                  tx['date'] ??
                  tx['createdAt'];
              try {
                return DateTime.parse(raw.toString()).toLocal();
              } catch (_) {
                return DateTime.fromMillisecondsSinceEpoch(0);
              }
            }
            return parse(b).compareTo(parse(a));
          });
      final approvedCount = filtered
          .where(
            (t) =>
                (t['approvalStatus']?.toString().toLowerCase().trim() ?? '') ==
                'approved',
          )
          .length;
      final rejectedCount = filtered
          .where(
            (t) =>
                (t['approvalStatus']?.toString().toLowerCase().trim() ?? '') ==
                'rejected',
          )
          .length;
      debugPrint(
        'TeamApprovalHistory[project=${widget.projectId}]: '
        'rawUnscoped=${all.length} filtered=${filtered.length} '
        'approved=$approvedCount rejected=$rejectedCount',
      );
      if (mounted) {
        setState(() {
          _history = filtered.take(15).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BtSkeleton(height: 120, radius: Bt.rCard);
    }
    final shown = _expanded ? _history : _history.take(3).toList();
    return BtGroup(
      insetDividers: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(children: [
            const BtTile(icon: Icons.groups_outlined, size: 32),
            const SizedBox(width: 10),
            Expanded(child: Text('Team approval history', style: BtText.body(context, weight: FontWeight.w600))),
            if (_history.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(minimumSize: const Size(44, 40), foregroundColor: Bt.ink2),
                child: Text(_expanded ? 'Show less' : 'Show all', style: BtText.subhead(context, weight: FontWeight.w600, color: context.bt.accentInk)),
              ),
          ]),
        ),
        if (_history.isEmpty)
          const BtEmpty(icon: Icons.fact_check_outlined, title: 'No approval requests yet')
        else
          AnimatedSize(
            duration: Bt.medium,
            curve: Bt.ease,
            alignment: Alignment.topCenter,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final tx in shown) _historyTile(tx as Map<String, dynamic>),
            ]),
          ),
      ],
    );
  }
  Widget _historyTile(Map<String, dynamic> tx) {
    final title = tx['title']?.toString() ?? 'Entry';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final approvalStatus = tx['approvalStatus']?.toString() ?? '';
    final createdByRole = _txRole(tx);
    final approvedByName =
        (tx['approvedBy'] is Map ? tx['approvedBy']['name'] : null)?.toString();
    final type = tx['type']?.toString() ?? '';
    String dateStr = '';
    final rawDate = tx['approvedAt'] ?? tx['date'] ?? tx['createdAt'];
    if (rawDate != null) {
      try {
        final d = DateTime.parse(rawDate.toString()).toLocal();
        dateStr = relativeTimeLabel(d);
      } catch (_) {}
    }
    final isApproved = approvalStatus == 'Approved';
    final lines = <String>[
      'By ${_txWho(tx)}${createdByRole.isNotEmpty ? ' · $createdByRole' : ''}${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
      if (approvedByName != null) isApproved ? 'Approved by $approvedByName' : 'Rejected by $approvedByName',
    ];
    return BtRow(
      leading: BtTypeTile(type: _txTypeWord(type, title)),
      title: title,
      subtitle: lines.join('\n'),
      subtitleMaxLines: 3,
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(formatInr(amount), style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
        const SizedBox(height: 4),
        BtBadge(label: approvalStatus, tone: isApproved ? BtTone.green : BtTone.red),
      ]),
    );
  }
}

// ───────── Redesign helpers for home cards ─────────
String _txWho(Map<String, dynamic> tx) =>
    (tx['createdBy'] is Map ? tx['createdBy']['name'] : null)?.toString() ?? 'Unknown';
String _txRole(Map<String, dynamic> tx) =>
    (tx['createdBy'] is Map ? tx['createdBy']['role'] : null)?.toString() ?? '';
String _txProject(Map<String, dynamic> tx) =>
    (tx['project'] is Map ? tx['project']['projectName'] : null)?.toString() ?? 'Unknown Project';
String _txDate(dynamic raw) {
  if (raw == null) return '';
  try {
    return formatDate(DateTime.parse(raw.toString()).toLocal());
  } catch (_) {
    return '';
  }
}
String _txTypeWord(String type, String title) {
  switch (type.toLowerCase()) {
    case 'wages':
      return 'labour';
    case 'expense':
      return 'equipment';
    default:
      return '$type $title';
  }
}
