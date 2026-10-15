import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_gradients.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/premium_cta_button.dart';
import 'package:buildtrack_mobile/controller/subscription_provider.dart';
import 'package:buildtrack_mobile/screen/profile/payment_webview_screen.dart';
import 'package:buildtrack_mobile/services/billing_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';

class _PlanInfo {
  const _PlanInfo({
    required this.plan,
    required this.title,
    required this.price,
    required this.period,
    required this.tagline,
    required this.features,
    required this.productId,
    required this.cta,
    required this.maxUsers,
    required this.maxProjectsLabel,
    this.isHighlighted = false,
  });
  final SubscriptionPlan plan;
  final String title;
  final String price;
  final String period;
  final String tagline;
  final List<String> features;
  final String? productId;
  final String cta;
  final int maxUsers;
  final String maxProjectsLabel;
  final bool isHighlighted;
}

const _plans = [
  _PlanInfo(
    plan: SubscriptionPlan.free,
    title: 'Free',
    price: '₹0',
    period: 'forever',
    tagline: 'Try out BuildTrack with no commitment.',
    features: [
      '1 project / 30 days',
      'Up to 2 users',
      'Basic project tracking',
      'Labour & material entries',
      'Community support',
    ],
    productId: null,
    cta: 'Current Plan',
    maxUsers: 2,
    maxProjectsLabel: '1 project / 30 days',
  ),
  _PlanInfo(
    plan: SubscriptionPlan.starter,
    title: 'Starter',
    price: '₹1',
    period: '/month',
    tagline: 'For small teams just getting started.',
    features: [
      '2 active projects',
      'Up to 5 users',
      'Labour & material tracking',
      'Basic reports',
      'Email support',
    ],
    productId: kStarterMonthlyId,
    cta: 'Get Starter',
    maxUsers: 5,
    maxProjectsLabel: '2 projects',
  ),
  _PlanInfo(
    plan: SubscriptionPlan.growth,
    title: 'Growth',
    price: '₹999',
    period: '/month',
    tagline: 'Scale your operations with more capacity.',
    features: [
      '4 active projects',
      'Up to 8 users',
      'Advanced reports & analytics',
      'Inventory tracking',
      'Priority support',
    ],
    productId: kGrowthMonthlyId,
    cta: 'Get Growth',
    maxUsers: 8,
    maxProjectsLabel: '4 projects',
  ),
  _PlanInfo(
    plan: SubscriptionPlan.pro,
    title: 'Pro',
    price: '₹1,499',
    period: '/month',
    tagline: 'Everything you need for growing teams.',
    features: [
      '6 active projects',
      'Up to 15 users',
      'Full inventory & receipt storage',
      'Advanced cost analytics',
      '24/7 priority support',
    ],
    productId: kProMonthlyId,
    cta: 'Upgrade to Pro',
    maxUsers: 15,
    maxProjectsLabel: '6 projects',
    isHighlighted: true,
  ),
  _PlanInfo(
    plan: SubscriptionPlan.business,
    title: 'Business',
    price: '₹2,499',
    period: '/month',
    tagline: 'For agencies managing multiple sites.',
    features: [
      '12 active projects',
      'Up to 25 users',
      'Role management',
      'API access',
      'Dedicated support',
    ],
    productId: kBusinessMonthlyId,
    cta: 'Get Business',
    maxUsers: 25,
    maxProjectsLabel: '12 projects',
  ),
  _PlanInfo(
    plan: SubscriptionPlan.enterprise,
    title: 'Enterprise',
    price: '₹4,999',
    period: '/month',
    tagline: 'Advanced tools for large, multi-team operations.',
    features: [
      'Unlimited projects',
      'Unlimited users',
      'Multi-user role management',
      'Custom integrations & API',
      'Dedicated account manager',
    ],
    productId: kEnterpriseMonthlyId,
    cta: 'Contact Sales',
    maxUsers: 999999,
    maxProjectsLabel: 'Unlimited',
  ),
];

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      globalTooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          backgroundColor: Colors.transparent,
          textStyle: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          backgroundColor: AppColors.primary,
          textStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
      enableAutoScroll: true,
      onFinish: () => UserSession.markModuleVisited('subscription'),
      builder: (context) => const _SubscriptionScreenContent(),
    );
  }
}

class _SubscriptionScreenContent extends StatefulWidget {
  const _SubscriptionScreenContent();
  @override
  State<_SubscriptionScreenContent> createState() =>
      _SubscriptionScreenContentState();
}

class _SubscriptionScreenContentState
    extends State<_SubscriptionScreenContent> {
  final GlobalKey _plansKey = GlobalKey();
  final GlobalKey _ctaKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!UserSession.hasSkippedTour &&
          !UserSession.visitedModules.contains('subscription')) {
        ShowCaseWidget.of(context).startShowCase([_plansKey, _ctaKey]);
      }
    });
  }

  SubscriptionPlan? _picked;

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final bt = context.bt;
    final current = _plans.firstWhere((p) => p.plan == sub.currentPlan, orElse: () => _plans.first);
    final upgradeable = _plans.where((p) => p.productId != null && p.plan != sub.currentPlan).toList();
    final selected = _plans.firstWhere(
      (p) => p.plan == (_picked ?? (upgradeable.where((u) => u.isHighlighted).firstOrNull ?? upgradeable.firstOrNull ?? current).plan),
      orElse: () => current,
    );
    final canBuy = selected.productId != null && selected.plan != sub.currentPlan;
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: 'Plan & billing',
        trailing: Showcase(
          key: _ctaKey,
          description: 'Get help and understand how this screen works.',
          child: BtIconButton(
            icon: Icons.help_outline_rounded,
            semantic: 'Help',
            color: Bt.ink2,
            onTap: () => ShowCaseWidget.of(context).startShowCase([_plansKey, _ctaKey]),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          BtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text('You\'re on ${current.title}', style: BtText.title(context))),
                  BtBadge(label: '${current.maxUsers} users', tone: BtTone.neutral),
                ]),
                const SizedBox(height: 4),
                Text('${current.maxProjectsLabel} · ${current.tagline}', style: BtText.subhead(context)),
              ],
            ),
          ),
          if (sub.error.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: sub.error),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Choose a plan · monthly', style: BtText.caption(context)),
          ),
          Showcase(
            key: _plansKey,
            description: 'Choose the plan that fits your business needs.',
            child: BtGroup(
              children: [
                for (final p in _plans)
                  Material(
                    color: p.plan == selected.plan ? bt.brandSoft : Colors.transparent,
                    child: BtRow(
                      leading: Icon(
                        p.plan == selected.plan ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: p.plan == selected.plan ? bt.brand : Bt.inputBorder,
                        size: 24,
                      ),
                      title: p.title,
                      subtitle: '${p.maxProjectsLabel} · ${p.maxUsers >= 9999 ? 'unlimited' : p.maxUsers} people',
                      minHeight: 64,
                      onTap: () => setState(() => _picked = p.plan),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (p.plan == sub.currentPlan) ...[
                          const BtBadge(label: 'Current', tone: BtTone.green),
                          const SizedBox(width: 8),
                        ] else if (p.isHighlighted) ...[
                          const BtBadge(label: 'Popular', tone: BtTone.brand),
                          const SizedBox(width: 8),
                        ],
                        Text(p.price, style: BtText.num(BtText.headline(context))),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          BtSectionHeader(title: '${selected.title} includes'),
          BtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selected.tagline, style: BtText.subhead(context)),
                const SizedBox(height: 10),
                for (final f in selected.features)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.check_rounded, color: Bt.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(f, style: BtText.body(context))),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _onRestore(context, sub),
                style: TextButton.styleFrom(foregroundColor: Bt.ink2, minimumSize: const Size(44, 44)),
                child: const Text('Restore Purchases'),
              ),
              const Text('·', style: TextStyle(color: Bt.placeholder)),
              TextButton(
                onPressed: () => _showCancelDialog(context, sub),
                style: TextButton.styleFrom(foregroundColor: Bt.red, minimumSize: const Size(44, 44)),
                child: const Text('Cancel Plan…'),
              ),
            ],
          ),
          Text(
            'Subscriptions auto-renew monthly.\nCancel anytime from your account settings.',
            textAlign: TextAlign.center,
            style: BtText.caption(context),
          ),
        ],
      ),
      bottomNavigationBar: EntryBottomBar(
        child: BtButton(
          label: canBuy ? '${selected.cta} · ${selected.price}${selected.period.startsWith('/') ? selected.period : ' ${selected.period}'}' : 'Current plan',
          loading: sub.isPurchasing,
          onPressed: (!canBuy || sub.isPurchasing) ? null : () => _onUpgrade(context, sub, selected),
        ),
      ),
    );
  }

  Future<void> _onUpgrade(
    BuildContext context,
    SubscriptionProvider sub,
    _PlanInfo plan,
  ) async {
    if (plan.productId == null) return;
    if (sub.currentPlan == plan.plan) return;
    final params = await sub.purchase(plan.productId!);
    if (!context.mounted) return;
    if (params == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(paymentParams: params),
      ),
    );
    if (!context.mounted) return;
    if (result == true) {
      _showSuccessDialog(context, plan);
    } else {}
  }

  Future<void> _onRestore(
    BuildContext context,
    SubscriptionProvider sub,
  ) async {
    await sub.restore();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sub.error.isEmpty
              ? sub.isPaid
                    ? 'Your ${sub.currentPlan.label} plan has been restored!'
                    : 'No active subscriptions found.'
              : sub.error,
        ),
        backgroundColor: sub.error.isEmpty
            ? AppColors.success
            : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, SubscriptionProvider sub) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isCancelling = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Bt.rCard),
            ),
            title: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.warning),
                SizedBox(width: 8),
                Text(
                  'Cancel Plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              sub.isPaid
                  ? 'Your ${sub.currentPlan.label} subscription will remain active until the end of the current billing cycle${sub.renewalDate != null ? ' (${sub.renewalDate!.day}/${sub.renewalDate!.month}/${sub.renewalDate!.year})' : ''}.\n\nAfter that, your account will revert to the Free plan with 1 project limit.'
                  : 'You are currently on the Free Plan.\n\nYour account has no active recurring charges.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF344054),
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: isCancelling ? null : () => Navigator.pop(ctx),
                child: const Text('Keep My Plan'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isCancelling
                    ? null
                    : () async {
                        setDialogState(() => isCancelling = true);
                        final success = await sub.cancelPlan();
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Subscription has been cancelled successfully.'
                                    : sub.error.isNotEmpty
                                    ? sub.error
                                    : 'Cancellation request submitted.',
                              ),
                              backgroundColor: const Color(0xFF101828),
                            ),
                          );
                        }
                      },
                child: isCancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirm Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, _PlanInfo plan) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppGradients.primaryButton,
                borderRadius: BorderRadius.circular(Bt.rCard),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to ${plan.title}!',
              style: AppTheme.heading2.copyWith(
                fontSize: 22,
                color: const Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your subscription is now active.\nEnjoy all ${plan.title} features.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            PremiumCtaButton(
              label: 'Start Building',
              isFullWidth: true,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEE4E2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFD92D20), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
