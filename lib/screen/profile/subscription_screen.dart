import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
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
    final glass = Colors.white.withValues(alpha: .09);
    return Scaffold(
      backgroundColor: Bt.ground,
      body: BtHeroScroll(
        hero: BtHero(
          padding: EdgeInsets.fromLTRB(Bt.gutter, MediaQuery.paddingOf(context).top + 4, Bt.gutter, 24 + 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Transform.translate(
                offset: const Offset(-6, 0),
                child: BtIconButton(icon: Icons.arrow_back_ios_new_rounded, size: 18, color: Bt.bone, background: glass, semantic: 'Back', onTap: () => Navigator.of(context).maybePop()),
              ),
              Expanded(child: Text('Plan & billing', textAlign: TextAlign.center, style: BtText.navTitle(context).copyWith(color: Bt.bone))),
              Transform.translate(
                offset: const Offset(6, 0),
                child: Showcase(
                  key: _ctaKey,
                  description: 'Get help and understand how this screen works.',
                  child: BtIconButton(
                    icon: Icons.help_outline_rounded,
                    semantic: 'Help',
                    size: 20,
                    color: Bt.bone,
                    background: glass,
                    onTap: () => ShowCaseWidget.of(context).startShowCase([_plansKey, _ctaKey]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            BtReveal(
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('CURRENT PLAN', style: BtText.mono(context, color: bt.accent)),
                    const SizedBox(height: 4),
                    Text(current.title, style: BtText.d1(context, color: Bt.bone)),
                  ]),
                ),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: current.price, style: BtText.num(BtText.headline(context).copyWith(color: Bt.bone))),
                    TextSpan(text: current.period.startsWith('/') ? current.period : ' ${current.period}', style: BtText.caption(context, color: Bt.onNoir2)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            BtReveal(
              index: 1,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: .09)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _heroFact(context, 'Includes', current.maxProjectsLabel),
                  const SizedBox(width: 14),
                  _heroFact(context, 'Team', current.maxUsers >= 9999 ? 'Unlimited users' : 'Up to ${current.maxUsers} users'),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            BtReveal(index: 2, child: Text(current.tagline, style: BtText.caption(context, color: Bt.onNoir2))),
          ]),
        ),
        children: [
          if (sub.error.isNotEmpty) ...[
            _ErrorBanner(message: sub.error),
            const SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text('CHOOSE A PLAN · MONTHLY', style: BtText.mono(context)),
          ),
          Showcase(
            key: _plansKey,
            description: 'Choose the plan that fits your business needs.',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < _plans.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                BtReveal(
                  index: 3 + i,
                  child: _PlanCard(
                    info: _plans[i],
                    selected: _plans[i].plan == selected.plan,
                    isCurrent: _plans[i].plan == sub.currentPlan,
                    onTap: () => setState(() => _picked = _plans[i].plan),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _onRestore(context, sub),
                style: TextButton.styleFrom(foregroundColor: Bt.ink2, minimumSize: const Size(44, 44)),
                child: Text('Restore Purchases', style: BtText.subhead(context, weight: FontWeight.w500)),
              ),
              // Nothing to cancel on Free.
              if (sub.isPaid) ...[
                const Text('·', style: TextStyle(color: Bt.placeholder)),
                TextButton(
                  onPressed: () => _showCancelDialog(context, sub),
                  style: TextButton.styleFrom(foregroundColor: Bt.red, minimumSize: const Size(44, 44)),
                  child: Text('Cancel Plan…', style: BtText.subhead(context, weight: FontWeight.w500, color: Bt.red)),
                ),
              ],
            ],
          ),
          Text(
            'Subscriptions auto-renew monthly.\nCancel anytime from your account settings.',
            textAlign: TextAlign.center,
            style: BtText.caption(context),
          ),
          const SizedBox(height: 40),
        ],
      ),
      bottomNavigationBar: BtCtaBar(children: [
        Expanded(
          child: BtButton(
            variant: canBuy ? BtButtonVariant.accent : BtButtonVariant.primary,
            label: canBuy ? '${selected.cta} · ${selected.price}${selected.period.startsWith('/') ? selected.period : ' ${selected.period}'}' : 'Current plan',
            loading: sub.isPurchasing,
            onPressed: (!canBuy || sub.isPurchasing) ? null : () => _onUpgrade(context, sub, selected),
          ),
        ),
      ]),
    );
  }

  Widget _heroFact(BuildContext context, String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: BtText.caption(context, color: Bt.onNoir2).copyWith(fontSize: 12)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.bone)),
        ]),
      );

  Future<void> _onUpgrade(
    BuildContext context,
    SubscriptionProvider sub,
    _PlanInfo plan,
  ) async {
    if (plan.productId == null) return;
    if (sub.currentPlan == plan.plan) return;
    final params = await sub.purchase(plan.productId!);
    if (!context.mounted) return;
    if (params == null) {
      // Before: nothing happened when the payment couldn't be started.
      btToast(context, sub.error.isNotEmpty ? sub.error : "Couldn't start the payment. Please try again.", error: true);
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(paymentParams: params),
      ),
    );
    if (!context.mounted) return;
    if (result == true) {
      _showSuccessDialog(context, plan);
    } else {
      // Failed, cancelled or Back from the payment page: say so (no charge
      // is assumed; the plan is unchanged).
      btToast(
        context,
        result == false ? "Payment didn't go through. You haven't been upgraded." : 'Payment cancelled. Your plan is unchanged.',
        error: result == false,
      );
    }
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
            backgroundColor: Bt.card,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            title: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Bt.amber),
                const SizedBox(width: 8),
                Text('Cancel Plan', style: BtText.d3(ctx)),
              ],
            ),
            content: Text(
              sub.isPaid
                  ? 'Your ${sub.currentPlan.label} subscription will remain active until the end of the current billing cycle${sub.renewalDate != null ? ' (${sub.renewalDate!.day}/${sub.renewalDate!.month}/${sub.renewalDate!.year})' : ''}.\n\nAfter that, your account will revert to the Free plan with 1 project limit.'
                  : 'You are currently on the Free Plan.\n\nYour account has no active recurring charges.',
              style: BtText.body(ctx, color: Bt.ink2),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(children: [
                Expanded(
                  child: BtButton(
                    label: 'Keep My Plan',
                    small: true,
                    variant: BtButtonVariant.secondary,
                    onPressed: isCancelling ? null : () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DangerButton(
                    label: 'Confirm Cancel',
                    loading: isCancelling,
                    onTap: isCancelling
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
                                  backgroundColor: Bt.noir,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSuccessDialog(BuildContext context, _PlanInfo plan) async {
    await showBtSuccess(
      context,
      kind: BtSuccessKind.check,
      title: 'Welcome to ${plan.title}!',
      message: 'Your subscription is now active.\nEnjoy all ${plan.title} features.',
      doneLabel: 'Start Building',
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }
}

/// One plan option: title, Current / Most popular badge, price, tagline,
/// and the plan's features (expanded on the selected card).
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.info, required this.selected, required this.isCurrent, required this.onTap});
  final _PlanInfo info;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final people = info.maxUsers >= 9999 ? 'unlimited' : '${info.maxUsers}';
    return Semantics(
      selected: selected,
      child: BtPressable(
        onTap: onTap,
        scale: .98,
        child: AnimatedContainer(
          duration: Bt.fast,
          curve: Bt.ease,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Bt.card,
            borderRadius: BorderRadius.circular(Bt.rCard),
            border: Border.all(color: selected ? bt.accent : Bt.line, width: selected ? 2 : 1),
            boxShadow: selected ? Bt.shadow : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AnimatedContainer(
                duration: Bt.fast,
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? bt.accent : Colors.transparent,
                  border: Border.all(color: selected ? bt.accent : Bt.inputBorder, width: 2),
                ),
                child: selected ? Icon(Icons.check_rounded, size: 13, color: bt.onAccent) : null,
              ),
              Flexible(child: Text(info.title, style: BtText.headline(context))),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                const BtBadge(label: 'Current', tone: BtTone.green),
              ] else if (info.isHighlighted) ...[
                const SizedBox(width: 8),
                const BtBadge(label: 'Most popular', tone: BtTone.brand, dot: false),
              ],
              const Spacer(),
              Text.rich(TextSpan(children: [
                TextSpan(text: info.price, style: BtText.num(BtText.headline(context).copyWith(fontWeight: FontWeight.w700))),
                TextSpan(text: info.period.startsWith('/') ? '/mo' : ' ${info.period}', style: BtText.caption(context, color: Bt.ink2).copyWith(fontSize: 12)),
              ])),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text('${info.maxProjectsLabel} · $people people', style: BtText.caption(context, color: Bt.ink2)),
            ),
            AnimatedSize(
              duration: Bt.medium,
              curve: Bt.ease,
              alignment: Alignment.topCenter,
              child: !selected
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(left: 30, top: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(info.tagline, style: BtText.subhead(context)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 14, runSpacing: 6, children: [
                          for (final f in info.features)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 5, height: 5, decoration: BoxDecoration(color: bt.accent, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(f, style: BtText.caption(context, color: Bt.ink2)),
                            ]),
                        ]),
                      ]),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Red filled confirm button for dialogs (with inline spinner).
class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onTap, this.loading = false});
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: BtPressable(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Bt.redBright, borderRadius: BorderRadius.circular(14)),
          child: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.button(context, size: 15, color: Colors.white)),
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
    return BtCard(
      variant: BtCardVariant.danger,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Bt.red, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: BtText.subhead(context, weight: FontWeight.w500, color: Bt.red))),
        ],
      ),
    );
  }
}
