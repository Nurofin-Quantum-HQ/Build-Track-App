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
      globalTooltipActions: const [
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

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                child: Column(
                  children: [
                    _buildHero(),
                    const SizedBox(height: 32),
                    if (sub.error.isNotEmpty) ...[
                      _ErrorBanner(message: sub.error),
                      const SizedBox(height: 20),
                    ],
                    Showcase(
                      key: _plansKey,
                      description:
                          'Choose the plan that fits your business needs.',
                      child: Column(
                        children: List.generate(_plans.length, (i) {
                          final plan = _plans[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _PlanCard(
                              info: plan,
                              isCurrentPlan: sub.currentPlan == plan.plan,
                              isPurchasing: sub.isPurchasing,
                              onUpgrade: () => _onUpgrade(context, sub, plan),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _onRestore(context, sub),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: Text(
                              'Restore Purchases',
                              style: TextStyle(
                                color: AppColors.primary.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.primary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Text(
                          ' • ',
                          style: TextStyle(color: Color(0xFFD0D5DD)),
                        ),
                        GestureDetector(
                          onTap: () => _showCancelDialog(context, sub),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: Text(
                              'Cancel Plan',
                              style: TextStyle(
                                color: Color(0xFFD92D20),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFFECDCA),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Subscriptions auto-renew monthly.\nCancel anytime from your account settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667085),
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textDark),
            onPressed: () => Navigator.maybePop(context),
          ),
          Showcase(
            key: _ctaKey,
            description: 'Get help and understand how this screen works.',
            child: IconButton(
              icon: const Icon(Icons.help_outline, color: AppColors.textDark),
              onPressed: () {
                ShowCaseWidget.of(context).startShowCase([_plansKey, _ctaKey]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                'Unlock Premium Features',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Supercharge your\nconstruction projects',
          textAlign: TextAlign.center,
          style: AppTheme.heading1.copyWith(
            fontSize: 28,
            letterSpacing: -0.6,
            height: 1.15,
            color: const Color(0xFF101828),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose a plan that scales with your business.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Color(0xFF667085), height: 1.4),
        ),
      ],
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
              borderRadius: BorderRadius.circular(20),
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
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.info,
    required this.isCurrentPlan,
    required this.isPurchasing,
    required this.onUpgrade,
  });
  final _PlanInfo info;
  final bool isCurrentPlan;
  final bool isPurchasing;
  final VoidCallback onUpgrade;
  @override
  Widget build(BuildContext context) {
    final bool isPro = info.isHighlighted;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPro ? AppColors.primary : const Color(0xFFEAECF0),
              width: isPro ? 2 : 1,
            ),
            boxShadow: isPro
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF101828).withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        info.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isPro
                              ? AppColors.primary
                              : const Color(0xFF101828),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _LimitPill(
                          icon: Icons.people_outline,
                          label: info.maxUsers == 999999
                              ? 'Unlimited users'
                              : '${info.maxUsers} users',
                        ),
                        const SizedBox(height: 4),
                        _LimitPill(
                          icon: Icons.folder_outlined,
                          label: info.maxProjectsLabel,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  info.tagline,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF667085),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      info.price,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      info.period,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFEAECF0), height: 1),
                const SizedBox(height: 24),
                ...info.features.map(
                  (f) => _FeatureItem(text: f, isHighlighted: isPro),
                ),
                const SizedBox(height: 8),
                _buildCta(),
              ],
            ),
          ),
        ),
        if (isPro)
          Positioned(
            top: -14,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppGradients.primaryButton,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Most Popular',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        if (isCurrentPlan && !isPro)
          Positioned(
            top: -14,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF101828),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Your Plan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCta() {
    if (isCurrentPlan) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAECF0)),
        ),
        child: const Center(
          child: Text(
            'Current Plan',
            style: TextStyle(
              color: Color(0xFF475467),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    if (info.isHighlighted) {
      return PremiumCtaButton(
        label: info.cta,
        isFullWidth: true,
        isLoading: isPurchasing,
        onTap: onUpgrade,
        variant: CtaVariant.primary,
      );
    }
    return GestureDetector(
      onTap: isPurchasing ? null : onUpgrade,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD0D5DD), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF101828).withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: isPurchasing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF344054),
                  ),
                )
              : Text(
                  info.cta,
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _LimitPill extends StatelessWidget {
  const _LimitPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF667085)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF344054),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.text, required this.isHighlighted});
  final String text;
  final bool isHighlighted;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : const Color(0xFFF2F4F7),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.check_rounded,
              size: 14,
              color: isHighlighted
                  ? AppColors.primary
                  : const Color(0xFF667085),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14.5,
                color: Color(0xFF344054),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
