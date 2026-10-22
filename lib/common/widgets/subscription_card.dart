import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/subscription_provider.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/design/design.dart';
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

    final bt = context.bt;
    return BtCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            BtTile(icon: sub.isPaid ? Icons.workspace_premium_rounded : Icons.auto_awesome_rounded, bg: bt.accentSoft, fg: bt.accentInk),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${plan.label} Plan', style: BtText.d3(context)),
                const SizedBox(height: 2),
                _StatusBadge(status: sub.status, isPaid: sub.isPaid),
              ]),
            ),
            BtBadge(label: plan.badge, tone: BtTone.neutral),
          ]),
          const SizedBox(height: 18),
          _UsageMeter(
            icon: Icons.folder_outlined,
            label: 'Projects',
            usageText: isUnlimitedProjects ? '$activeProjects Active (Unlimited)' : '$activeProjects / $maxProjects Used',
            progress: isUnlimitedProjects ? 0.35 : projectUsageRatio,
            isUnlimited: isUnlimitedProjects,
          ),
          const SizedBox(height: 14),
          _UsageMeter(
            icon: Icons.people_outline,
            label: 'Team Seats',
            usageText: isUnlimitedUsers ? '$activeUsers Active (Unlimited)' : '$activeUsers / $maxUsers Active',
            progress: isUnlimitedUsers ? 0.25 : userUsageRatio,
            isUnlimited: isUnlimitedUsers,
          ),
          if (sub.renewalDate != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.event_repeat_rounded, color: Bt.ink3, size: 15),
              const SizedBox(width: 6),
              Text('RENEWS ON ${_fmtDate(sub.renewalDate!).toUpperCase()}', style: BtText.mono(context)),
            ]),
          ],
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _isBenefitsExpanded = !_isBenefitsExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Expanded(child: Text(_isBenefitsExpanded ? 'Hide Plan Benefits' : 'View Plan Benefits & Perks', style: BtText.subhead(context, weight: FontWeight.w600, color: bt.accentInk))),
                AnimatedRotation(
                  turns: _isBenefitsExpanded ? .5 : 0,
                  duration: Bt.fast,
                  curve: Bt.ease,
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: bt.accentInk, size: 20),
                ),
              ]),
            ),
          ),
          AnimatedSize(
            duration: Bt.medium,
            curve: Bt.ease,
            alignment: Alignment.topCenter,
            child: !_isBenefitsExpanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final feat in _getFeaturesForPlan(plan))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: bt.accent, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(feat, style: BtText.subhead(context, color: Bt.ink))),
                          ]),
                        ),
                    ]),
                  ),
          ),
          if (widget.showUpgradeButton) ...[
            const SizedBox(height: 4),
            BtButton(
              label: sub.isPaid ? 'Upgrade / Change Tier' : 'Upgrade Plan',
              icon: Icons.rocket_launch_rounded,
              onPressed: () => Navigator.pushNamed(context, '/subscription'),
            ),
            const SizedBox(height: 2),
            BtButton(label: 'Cancel Plan…', variant: BtButtonVariant.quiet, onPressed: () => _showCancelDialog(context, sub)),
          ] else ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.shield_outlined, color: Bt.ink3, size: 16),
              const SizedBox(width: 6),
              Text('Plan managed by your admin', style: BtText.caption(context)),
            ]),
            const SizedBox(height: 4),
          ],
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
                  ? 'Your ${sub.currentPlan.label} subscription will remain active until the end of the current billing cycle${sub.renewalDate != null ? ' (${_fmtDate(sub.renewalDate!)})' : ''}.\n\nAfter that, your account will revert to the Free plan with 1 project limit.'
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
                  child: Semantics(
                    button: true,
                    child: BtPressable(
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
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Bt.redBright, borderRadius: BorderRadius.circular(14)),
                        child: isCancelling
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Confirm Cancel', maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.button(ctx, size: 15, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ]),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(icon, color: Bt.ink3, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: BtText.subhead(context))),
        Text(usageText, style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: isNearLimit ? Bt.amber : Bt.ink))),
      ]),
      const SizedBox(height: 8),
      BtBricks(value: progress, height: 8, color: isNearLimit ? Bt.amberBright : null),
    ]);
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
      SubscriptionStatus.active => isPaid ? Bt.green : Bt.ink3,
      SubscriptionStatus.expired => Bt.red,
      SubscriptionStatus.unknown => isPaid ? Bt.green : Bt.ink3,
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
          style: BtText.caption(context, color: color, weight: FontWeight.w600),
        ),
      ],
    );
  }
}
