import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/widgets/premium_cta_button.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/subscription_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SubscriptionCard extends StatefulWidget {
  const SubscriptionCard({super.key, this.showUpgradeButton = true});

  final bool showUpgradeButton;

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  bool _isBenefitsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final plan = sub.currentPlan;
    final projectProvider = context.watch<ProjectProvider>();
    final activeProjects = projectProvider.projects.length;

    final maxProjects = plan.maxProjects;
    final isUnlimitedProjects = maxProjects == -1;
    final projectUsageRatio = isUnlimitedProjects
        ? 0.0
        : (activeProjects / (maxProjects > 0 ? maxProjects : 1)).clamp(
            0.0,
            1.0,
          );

    final maxUsers = plan.maxUsers;
    final isUnlimitedUsers = maxUsers >= 999999;
    const activeUsers = 1;
    final userUsageRatio = isUnlimitedUsers
        ? 0.0
        : (activeUsers / (maxUsers > 0 ? maxUsers : 1)).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _gradientFor(plan),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _shadowColorFor(plan),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Plan Title + Badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        sub.isPaid
                            ? Icons.workspace_premium_rounded
                            : Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${plan.label} Plan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _StatusBadge(status: sub.status, isPaid: sub.isPaid),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.40),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        plan.badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Usage Progress Bars
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      _UsageMeter(
                        icon: Icons.folder_outlined,
                        label: 'Projects',
                        usageText: isUnlimitedProjects
                            ? '$activeProjects Active (Unlimited)'
                            : '$activeProjects / $maxProjects Used',
                        progress: isUnlimitedProjects
                            ? 0.35
                            : projectUsageRatio,
                        isUnlimited: isUnlimitedProjects,
                      ),
                      const SizedBox(height: 10),
                      _UsageMeter(
                        icon: Icons.people_outline,
                        label: 'Team Seats',
                        usageText: isUnlimitedUsers
                            ? '$activeUsers Active (Unlimited)'
                            : '$activeUsers / $maxUsers Active',
                        progress: isUnlimitedUsers ? 0.25 : userUsageRatio,
                        isUnlimited: isUnlimitedUsers,
                      ),
                    ],
                  ),
                ),

                // Auto-renewal Notice
                if (sub.renewalDate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_repeat_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Renews on ${_fmtDate(sub.renewalDate!)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                // Expandable Plan Benefits Section
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isBenefitsExpanded = !_isBenefitsExpanded;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isBenefitsExpanded
                              ? 'Hide Plan Benefits'
                              : 'View Plan Benefits & Perks',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white54,
                          ),
                        ),
                        Icon(
                          _isBenefitsExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isBenefitsExpanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _getFeaturesForPlan(plan)
                          .map(
                            (feat) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feat,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],

                // Action Buttons: Upgrade Plan + Cancel Plan
                if (widget.showUpgradeButton) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 14),
                  PremiumCtaButton(
                    label: sub.isPaid
                        ? 'Upgrade / Change Tier'
                        : 'Upgrade Plan',
                    icon: Icons.rocket_launch_rounded,
                    onTap: () => Navigator.pushNamed(context, '/subscription'),
                    variant: CtaVariant.primary,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 10),
                  PremiumCtaButton(
                    label: 'Cancel Plan',
                    onTap: () => _showCancelDialog(context, sub),
                    variant: CtaVariant.secondary,
                    isFullWidth: true,
                  ),
                ],
              ],
            ),
          ),
        ],
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
                  ? 'Your ${sub.currentPlan.label} subscription will remain active until the end of the current billing cycle${sub.renewalDate != null ? ' (${_fmtDate(sub.renewalDate!)})' : ''}.\n\nAfter that, your account will revert to the Free plan with 1 project limit.'
                  : 'You are currently on the Free Plan.\n\nYour account has no active recurring charges.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
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
                              backgroundColor: AppColors.textDark,
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

  List<String> _getFeaturesForPlan(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return [
          '1 project / 30 days',
          'Up to 2 users',
          'Basic project tracking',
          'Labour & material entries',
        ];
      case SubscriptionPlan.starter:
        return [
          '2 active projects',
          'Up to 5 users',
          'Labour & material tracking',
          'Basic reports & exports',
        ];
      case SubscriptionPlan.growth:
        return [
          '4 active projects',
          'Up to 8 users',
          'Advanced reports & analytics',
          'Inventory tracking',
        ];
      case SubscriptionPlan.pro:
        return [
          '6 active projects',
          'Up to 15 users',
          'Full inventory & receipt storage',
          'Advanced cost analytics & AI',
        ];
      case SubscriptionPlan.business:
        return [
          '12 active projects',
          'Up to 25 users',
          'Role & team management',
          'API access & priority support',
        ];
      case SubscriptionPlan.enterprise:
        return [
          'Unlimited projects & users',
          'Custom integrations',
          'Dedicated account manager',
          '24/7 Priority support',
        ];
    }
  }

  LinearGradient _gradientFor(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return const LinearGradient(
          colors: [Color(0xFF374151), Color(0xFF4B5563), Color(0xFF6B7280)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SubscriptionPlan.starter:
        return const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF0EA5E9), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SubscriptionPlan.growth:
        return const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SubscriptionPlan.pro:
        return const LinearGradient(
          colors: [
            AppColors.primaryBlue,
            AppColors.primaryPurple,
            Color(0xFF9B59FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SubscriptionPlan.business:
        return const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFBBF24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SubscriptionPlan.enterprise:
        return const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _shadowColorFor(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return const Color(0xFF4B5563).withValues(alpha: 0.3);
      case SubscriptionPlan.starter:
        return const Color(0xFF0EA5E9).withValues(alpha: 0.35);
      case SubscriptionPlan.growth:
        return const Color(0xFF059669).withValues(alpha: 0.35);
      case SubscriptionPlan.pro:
        return AppColors.primaryPurple.withValues(alpha: 0.4);
      case SubscriptionPlan.business:
        return const Color(0xFFD97706).withValues(alpha: 0.35);
      case SubscriptionPlan.enterprise:
        return Colors.black.withValues(alpha: 0.45);
    }
  }

  String _fmtDate(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _UsageMeter extends StatelessWidget {
  const _UsageMeter({
    required this.icon,
    required this.label,
    required this.usageText,
    required this.progress,
    required this.isUnlimited,
  });

  final IconData icon;
  final String label;
  final String usageText;
  final double progress;
  final bool isUnlimited;

  @override
  Widget build(BuildContext context) {
    final bool isNearLimit = progress >= 0.85 && !isUnlimited;
    final Color progressColor = isNearLimit
        ? const Color(0xFFFCA5A5)
        : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              usageText,
              style: TextStyle(
                color: isNearLimit
                    ? const Color(0xFFFECDD3)
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isPaid});

  final SubscriptionStatus status;
  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      SubscriptionStatus.active => isPaid ? 'Active' : 'Free Tier',
      SubscriptionStatus.expired => 'Expired',
      SubscriptionStatus.unknown => isPaid ? 'Active' : 'Free Tier',
    };
    final color = switch (status) {
      SubscriptionStatus.active =>
        isPaid ? const Color(0xFF4ADE80) : const Color(0xFF93C5FD),
      SubscriptionStatus.expired => const Color(0xFFFCA5A5),
      SubscriptionStatus.unknown =>
        isPaid ? const Color(0xFF4ADE80) : const Color(0xFF93C5FD),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
