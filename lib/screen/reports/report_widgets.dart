import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../common/themes/app_theme.dart';
import '../../common/themes/app_colors.dart';
import '../../common/widgets/app_widgets.dart';
import '../../controller/report_model.dart';
import '../../controller/project_provider.dart';
import '../../models/project_model.dart';
import '../../controller/report_provider.dart';
import 'dart:math' as math;
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.change,
  });
  final IconData icon;
  final String label;
  final String value;
  final double change;
  @override
  Widget build(BuildContext context) {
    final safeChange = (change.isNaN || change.isInfinite) ? 0.0 : change;
    final isNeutral = safeChange == 0.0;
    final isGood = safeChange < 0.0;
    final subColor = isNeutral
        ? AppColors.textLight
        : isGood
        ? AppColors.success
        : AppColors.error;
    final subIcon = isNeutral
        ? Icons.remove
        : isGood
        ? Icons.trending_down
        : Icons.trending_up;
    final subText = isNeutral
        ? 'On Track'
        : isGood
        ? '${safeChange.abs().toStringAsFixed(0)}% Saving'
        : '+${safeChange.toStringAsFixed(0)}% Over';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
        border: Border.all(color: const Color(0xFFF0F1F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.label.copyWith(
              color: AppColors.textLight,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(subIcon, size: 12, color: subColor),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  subText,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    color: subColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.report, required this.period});
  final ReportModel report;
  final String period;
  @override
  Widget build(BuildContext context) {
    final totalTarget =
        report.targetMaterial +
        report.targetLabour +
        report.targetEquipment +
        report.targetMisc;
    double pct(double actual, double target) {
      if (target <= 0) return 0;
      return ((actual / target) - 1) * 100;
    }
    final cards = [
      _M(
        Icons.credit_card_outlined,
        'TOTAL COST',
        report.formattedTotal,
        pct(report.totalCost, totalTarget),
      ),
      _M(
        Icons.architecture,
        'MATERIAL',
        report.formattedMaterial,
        pct(report.materialCost, report.targetMaterial),
      ),
      _M(
        Icons.people_outline,
        'LABOUR',
        report.formattedLabour,
        pct(report.labourCost, report.targetLabour),
      ),
      _M(
        Icons.precision_manufacturing_outlined,
        'EQUIPMENT',
        report.formattedEquipment,
        pct(report.equipmentCost, report.targetEquipment),
      ),
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                icon: cards[0].icon,
                label: cards[0].label,
                value: cards[0].value,
                change: cards[0].change,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                icon: cards[1].icon,
                label: cards[1].label,
                value: cards[1].value,
                change: cards[1].change,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                icon: cards[2].icon,
                label: cards[2].label,
                value: cards[2].value,
                change: cards[2].change,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                icon: cards[3].icon,
                label: cards[3].label,
                value: cards[3].value,
                change: cards[3].change,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
class _M {
  const _M(this.icon, this.label, this.value, this.change);
  final IconData icon;
  final String label;
  final String value;
  final double change;
}
class ChartSection extends StatelessWidget {
  const ChartSection({super.key, required this.report});
  final ReportModel report;
  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        'name': 'Material',
        'actual': report.materialCost.isNaN ? 0.0 : report.materialCost,
        'target': report.targetMaterial.isNaN ? 0.0 : report.targetMaterial,
      },
      {
        'name': 'Labour',
        'actual': report.labourCost.isNaN ? 0.0 : report.labourCost,
        'target': report.targetLabour.isNaN ? 0.0 : report.targetLabour,
      },
      {
        'name': 'Equipment',
        'actual': report.equipmentCost.isNaN ? 0.0 : report.equipmentCost,
        'target': report.targetEquipment.isNaN ? 0.0 : report.targetEquipment,
      },
      {
        'name': 'Misc',
        'actual': report.miscCost.isNaN ? 0.0 : report.miscCost,
        'target': report.targetMisc.isNaN ? 0.0 : report.targetMisc,
      },
    ];
    final actualSpots = List.generate(
      categories.length,
      (i) => FlSpot(i.toDouble(), categories[i]['actual'] as double),
    );
    final targetSpots = List.generate(
      categories.length,
      (i) => FlSpot(i.toDouble(), categories[i]['target'] as double),
    );
    final allValues = [
      ...categories.map((e) => e['actual'] as double),
      ...categories.map((e) => e['target'] as double),
    ];
    final maxRaw = allValues.reduce((a, b) => a > b ? a : b);
    final maxY = maxRaw <= 0 ? 1000.0 : maxRaw * 1.25;
    double niceInterval(double max) {
      if (max <= 0) return 1;
      final raw = max / 4;
      final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
      final residual = raw / magnitude;
      double niceResidual;
      if (residual <= 1) {
        niceResidual = 1;
      } else if (residual <= 2) {
        niceResidual = 2;
      } else if (residual <= 5) {
        niceResidual = 5;
      } else {
        niceResidual = 10;
      }
      return niceResidual * magnitude;
    }
    final leftInterval = niceInterval(maxY);
    final roundedMaxY = (maxY / leftInterval).ceil() * leftInterval;
    String formatY(double value) {
      if (value >= 100000) {
        return '₹${(value / 100000).toStringAsFixed(value % 100000 == 0 ? 0 : 1)}L';
      } else if (value >= 1000) {
        return '₹${(value / 1000).toStringAsFixed(0)}K';
      }
      return '₹${value.toInt()}';
    }
    final widestLabelLength = formatY(roundedMaxY).length;
    final dynamicReservedSize = (widestLabelLength * 7.0 + 14).clamp(
      44.0,
      72.0,
    );
    final isExceeded = categories.any(
      (e) =>
          (e['actual'] as double) > (e['target'] as double) &&
          (e['target'] as double) > 0,
    );
    return AppCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Spend vs Budget by Category',
              style: AppTheme.heading3.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              isExceeded
                  ? '⚠ Budget exceeded in one or more categories'
                  : '✓ All categories within budget',
              style: TextStyle(
                fontSize: 12,
                color: isExceeded ? AppColors.error : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            OrientationBuilder(
              builder: (context, orientation) {
                final isLandscape = orientation == Orientation.landscape;
                final chartHeight = isLandscape ? 150.0 : 200.0;
                return SizedBox(
                  height: chartHeight,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: roundedMaxY,
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= categories.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  categories[i]['name'].toString(),
                                  style: TextStyle(fontSize: isLandscape ? 9 : 10),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: dynamicReservedSize,
                            interval: leftInterval,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 4,
                                child: Text(
                                  formatY(value),
                                  style: TextStyle(
                                    fontSize: isLandscape ? 9 : 10,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: actualSpots,
                          isCurved: true,
                          barWidth: 3,
                          color: AppColors.primary,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withValues(alpha: 0.08),
                          ),
                        ),
                        LineChartBarData(
                          spots: targetSpots,
                          isCurved: false,
                          barWidth: 2,
                          color: Colors.red,
                          dashArray: [6, 4],
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _dot(AppColors.primary),
                const SizedBox(width: 6),
                const Text('Actual Paid', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                _dot(Colors.red),
                const SizedBox(width: 6),
                const Text('Target Budget', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _dot(Color c) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}
class ProjectSelector extends StatelessWidget {
  const ProjectSelector({super.key, required this.provider});
  final ReportProvider provider;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      onTap: () => _showSheet(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              provider.selectedProjectName,
              style: AppTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textLight,
            size: 22,
          ),
        ],
      ),
    );
  }
  void _showSheet(BuildContext context) {
    final projectProvider = context.read<ProjectProvider>();
    final realProjects = projectProvider.projects;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _ProjectPickerSheet(provider: provider, projects: realProjects),
    );
  }
}
class _ProjectPickerSheet extends StatelessWidget {
  const _ProjectPickerSheet({required this.provider, required this.projects});
  final ReportProvider provider;
  final List<ProjectModel> projects;
  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.60;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Project', style: AppTheme.heading3),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('All Active Projects'),
                leading: const Icon(Icons.grid_view),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  provider.selectProject('all');
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: projects.map((p) {
                    final selected = p.id == provider.selectedProjectId;
                    return InkWell(
                      onTap: () {
                        provider.selectProject(p.id);
                        context.read<ProjectProvider>().selectProject(p);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 18,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textLight,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                p.name,
                                style: AppTheme.bodyLarge.copyWith(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textDark,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class CategoryBudgetSection extends StatelessWidget {
  const CategoryBudgetSection({super.key});
  @override
  Widget build(BuildContext context) {
    final report = context.watch<ReportProvider>().report;
    final items = [
      {
        'label': 'Material',
        'actual': report.materialCost,
        'target': report.targetMaterial,
      },
      {
        'label': 'Labour',
        'actual': report.labourCost,
        'target': report.targetLabour,
      },
      {
        'label': 'Equipment',
        'actual': report.equipmentCost,
        'target': report.targetEquipment,
      },
      if (report.targetMisc > 0 || report.miscCost > 0)
        {
          'label': 'Misc',
          'actual': report.miscCost,
          'target': report.targetMisc,
        },
    ];
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Usage by Category',
            style: AppTheme.heading3.copyWith(color: AppColors.textDark),
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            final actual = (item['actual'] as double).isNaN
                ? 0.0
                : (item['actual'] as double);
            final target = (item['target'] as double).isNaN
                ? 0.0
                : (item['target'] as double);
            final hasTarget = target > 0;
            final rawPercent = hasTarget ? actual / target : 0.0;
            final barValue = hasTarget ? rawPercent.clamp(0.0, 1.0) : 0.0;
            final isOver = hasTarget && actual > target;
            final remaining = hasTarget
                ? (target - actual).clamp(0.0, double.infinity)
                : 0.0;
            final color = isOver
                ? AppColors.error
                : barValue >= 0.75
                ? AppColors.warning
                : AppColors.primary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['label'].toString(),
                        style: AppTheme.label.copyWith(
                          color: AppColors.textDark,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${actual.toStringAsFixed(0)} spent',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: color,
                            ),
                          ),
                          if (hasTarget)
                            Text(
                              'of ₹${target.toStringAsFixed(0)} budget',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: LinearProgressIndicator(
                            value: barValue,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFEEF0F8),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                      if (hasTarget) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${(rawPercent * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasTarget)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        isOver
                            ? 'Exceeded by ₹${(actual - target).toStringAsFixed(0)}'
                            : 'Remaining: ₹${remaining.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOver ? AppColors.error : AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
class EfficiencyBanner extends StatelessWidget {
  const EfficiencyBanner({
    super.key,
    required this.note,
    required this.isExceeded,
  });
  final String note;
  final bool isExceeded;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExceeded
              ? [AppColors.error, AppColors.error.withValues(alpha: 0.7)]
              : [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Efficiency Report',
                style: AppTheme.heading3.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            note,
            style: AppTheme.body.copyWith(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              final selectedProjectName = context
                  .read<ReportProvider>()
                  .selectedProjectName;
              Navigator.pushNamed(
                context,
                '/report-insights',
                arguments: {'projectName': selectedProjectName},
              );
            },
            borderRadius: BorderRadius.circular(4),
            splashColor: Colors.white24,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Details',
                    style: AppTheme.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
