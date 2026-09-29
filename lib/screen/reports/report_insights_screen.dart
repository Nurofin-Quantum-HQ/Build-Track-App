import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/report_model.dart';
import 'package:buildtrack_mobile/screen/reports/report_widgets.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
class ReportInsightsScreen extends StatefulWidget {
  const ReportInsightsScreen({super.key});
  @override
  State<ReportInsightsScreen> createState() => _ReportInsightsScreenState();
}
class _ReportInsightsScreenState extends State<ReportInsightsScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  List<dynamic> _inventoryItems = [];
  String? _lastInventoryProjectId;
  Future<void> _loadInventory(String projectId) async {
    if (_lastInventoryProjectId == projectId) return;
    _lastInventoryProjectId = projectId;
    final items = await ApiService.fetchInventory(
      projectId == 'all' ? '' : projectId,
    );
    if (!mounted) return;
    setState(() {
      _inventoryItems = items;
    });
  }
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final passedProjectName = args?['projectName'];
    final isAll = passedProjectName == 'All Active Projects';
    ProjectModel? project;
    if (isAll) {
      final totalBudget = provider.projects.fold(
        0.0,
        (s, p) => s + p.totalBudget,
      );
      final spentAmount = provider.projects.fold(
        0.0,
        (s, p) => s + p.spentAmount,
      );
      final avgProgress = provider.projects.isEmpty
          ? 0.0
          : provider.projects.fold(0.0, (s, p) => s + p.progress) /
                provider.projects.length;
      project = ProjectModel(
        id: 'all',
        name: 'All Active Projects',
        city: 'Multiple',
        sector: 'Locations',
        stage: ProjectStage.preConstruction,
        progress: avgProgress,
        totalBudget: totalBudget,
        spentAmount: spentAmount,
        startDate: DateTime.now(),
        location: 'Multiple Locations',
      );
    } else {
      project = passedProjectName != null
          ? provider.projects.firstWhere(
              (p) => p.name == passedProjectName,
              orElse: () => provider.selectedProject!,
            )
          : provider.selectedProject;
    }
    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.gradientStart,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (project == null) {
      return Scaffold(
        backgroundColor: AppColors.gradientStart,
        body: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: 'Report Insights',
                isSubScreen: true,
                leftIcon: Icons.arrow_back,
                onLeftTap: () => Navigator.maybePop(context),
              ),
              const Expanded(
                child: AppEmptyState(
                  icon: Icons.bar_chart_outlined,
                  message: 'No project selected.',
                ),
              ),
            ],
          ),
        ),
      );
    }
    final report = _buildReportForProject(provider, project.id, isAll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInventory(project!.id);
    });
    final phases = project.selectedPhases ?? [];
    final allEntries = isAll
        ? provider.entries
        : provider.entriesForProject(project.id);
    final filteredEntries = allEntries
        .where(
          (e) =>
              !e.date.isBefore(_fromDate) &&
              !e.date.isAfter(_toDate.add(const Duration(days: 1))),
        )
        .toList();
    final categoryCosts = {
      'Material': report.materialCost,
      'Labour': report.labourCost,
      'Equipment': report.equipmentCost,
    };
    final categoryBudgets = {
      'Material': report.targetMaterial,
      'Labour': report.targetLabour,
      'Equipment': report.targetEquipment,
    };
    return Scaffold(
      backgroundColor: AppColors.gradientStart,
      floatingActionButton: _ExportFab(
        onTap: () => _showExportSheet(
          context,
          project!,
          report,
          categoryCosts,
          categoryBudgets,
          filteredEntries,
          phases,
          _inventoryItems,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: 'Report Insights',
              isSubScreen: true,
              leftIcon: Icons.arrow_back,
              onLeftTap: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DateRangeRow(
                      fromDate: _fromDate,
                      toDate: _toDate,
                      onChanged: (from, to) => setState(() {
                        _fromDate = from;
                        _toDate = to;
                      }),
                    ),
                    const SizedBox(height: 10),
                    _ProjectSummaryCard(project: project, report: report),
                    const SizedBox(height: 14),
                    ChartSection(report: report),
                    const SizedBox(height: 14),
                    const AppSectionHeader(title: 'Category Breakdown'),
                    _CategoryBreakdownCard(
                      project: project,
                      categoryCosts: categoryCosts,
                      categoryBudgets: categoryBudgets,
                    ),
                    const SizedBox(height: 18),
                    _ExportDetailsHintCard(
                      onTap: () => _showExportSheet(
                        context,
                        project!,
                        report,
                        categoryCosts,
                        categoryBudgets,
                        filteredEntries,
                        phases,
                        _inventoryItems,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Update Progress',
                      icon: Icons.trending_up,
                      onPressed: () =>
                          Navigator.pushNamed(context, '/update-progress'),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'View Full Logs',
                      icon: Icons.receipt_long_outlined,
                      variant: AppButtonVariant.outline,
                      onPressed: () => Navigator.pushNamed(context, '/logs'),
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
  ReportModel _buildReportForProject(
    ProjectProvider provider,
    String projectId,
    bool isAll,
  ) {
    if (provider.projects.isEmpty) return ReportModel.empty();
    final targetProjects = isAll
        ? provider.projects
        : provider.projects.where((p) => p.id == projectId).toList();
    if (targetProjects.isEmpty) return ReportModel.empty();
    double material = 0, labour = 0, equipment = 0;
    for (final p in targetProjects) {
      for (final entry in provider.entriesForProject(p.id)) {
        switch (entry.type) {
          case EntryType.material:
            material += entry.amount;
            break;
          case EntryType.labour:
            labour += entry.amount;
            break;
          case EntryType.equipment:
            equipment += entry.amount;
            break;
        }
      }
    }
    double targetMaterial = 0,
        targetLabour = 0,
        targetEquipment = 0,
        targetMisc = 0;
    for (final p in targetProjects) {
      targetMaterial += p.budgetMaterial ?? 0;
      targetLabour += p.budgetLabour ?? 0;
      targetEquipment += p.budgetEquipment ?? 0;
      targetMisc += p.budgetMisc ?? 0;
    }
    final total = material + labour + equipment;
    final totalTarget =
        targetMaterial + targetLabour + targetEquipment + targetMisc;
    final isOver = totalTarget > 0 && total > totalTarget;
    return ReportModel(
      totalCost: total,
      materialCost: material,
      labourCost: labour,
      equipmentCost: equipment,
      miscCost: 0,
      categoryBudget: {
        'Material': targetMaterial,
        'Labour': targetLabour,
        'Equipment': targetEquipment,
      },
      targetMaterial: targetMaterial,
      targetLabour: targetLabour,
      targetEquipment: targetEquipment,
      targetMisc: targetMisc,
      efficiencyNote: isOver
          ? 'Budget exceeded by ₹${(total - totalTarget).toStringAsFixed(0)}'
          : 'Project is within budget',
    );
  }
  void _showExportSheet(
    BuildContext context,
    ProjectModel project,
    ReportModel report,
    Map<String, double> categoryCosts,
    Map<String, double> categoryBudgets,
    List<EntryModel> entries,
    List<ProjectPhase> phases,
    List<dynamic> inventoryItems,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExportSheet(
        project: project,
        report: report,
        categoryCosts: categoryCosts,
        categoryBudgets: categoryBudgets,
        entries: entries,
        phases: phases,
        inventoryItems: inventoryItems,
        fromDate: _fromDate,
        toDate: _toDate,
      ),
    );
  }
}
class _DateRangeRow extends StatelessWidget {
  const _DateRangeRow({
    required this.fromDate,
    required this.toDate,
    required this.onChanged,
  });
  final DateTime fromDate;
  final DateTime toDate;
  final void Function(DateTime from, DateTime to) onChanged;
  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: DateTimeRange(start: fromDate, end: toDate),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.light(primary: AppColors.primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          onChanged(picked.start, picked.end);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE0F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_fmt(fromDate)}  →  ${_fmt(toDate)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const Icon(
              Icons.edit_outlined,
              size: 13,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}
class _ExportFab extends StatelessWidget {
  const _ExportFab({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.share_outlined, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Export Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ExportSheet extends StatefulWidget {
  const _ExportSheet({
    required this.project,
    required this.report,
    required this.categoryCosts,
    required this.categoryBudgets,
    required this.entries,
    required this.phases,
    required this.inventoryItems,
    required this.fromDate,
    required this.toDate,
  });
  final ProjectModel project;
  final ReportModel report;
  final Map<String, double> categoryCosts;
  final Map<String, double> categoryBudgets;
  final List<EntryModel> entries;
  final List<ProjectPhase> phases;
  final List<dynamic> inventoryItems;
  final DateTime fromDate;
  final DateTime toDate;
  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}
class _ExportSheetState extends State<_ExportSheet> {
  bool _includeCostBreakdown = true;
  bool _includeCategoryChart = true;
  bool _includeEntryLog = false;
  bool _includeActivityProgress = true;
  bool _includeInventory = true;
  bool _isGenerating = false;
  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String get _dateRangeLabel =>
      '${_fmt(widget.fromDate)} – ${_fmt(widget.toDate)}';
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE0F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Report',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          widget.project.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.date_range,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dateRangeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'INCLUDE IN REPORT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textLight,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              _toggle(
                'Cost Breakdown',
                'Total material, labour & equipment costs',
                Icons.pie_chart_outline,
                _includeCostBreakdown,
                (v) => setState(() => _includeCostBreakdown = v),
              ),
              _toggle(
                'Category Chart',
                'Visual chart + table of budget vs actual',
                Icons.bar_chart_outlined,
                _includeCategoryChart,
                (v) => setState(() => _includeCategoryChart = v),
              ),
              _toggle(
                'Entry Log',
                'Line-by-line list of all entries',
                Icons.receipt_long_outlined,
                _includeEntryLog,
                (v) => setState(() => _includeEntryLog = v),
              ),
              _toggle(
                'Activity Progress',
                'Phase-wise completed activities',
                Icons.checklist_outlined,
                _includeActivityProgress,
                (v) => setState(() => _includeActivityProgress = v),
              ),
              _toggle(
                'Inventory Status',
                'Stock levels and reorder alerts',
                Icons.inventory_2_outlined,
                _includeInventory,
                (v) => setState(() => _includeInventory = v),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.visibility_outlined,
                      label: 'Preview',
                      isPrimary: false,
                      isLoading: false,
                      onTap: _previewPdf,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.share_outlined,
                      label: _isGenerating ? 'Generating…' : 'Share PDF',
                      isPrimary: true,
                      isLoading: _isGenerating,
                      onTap: _isGenerating ? null : _sharePdf,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _toggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: value
                ? AppColors.primary.withValues(alpha: 0.06)
                : const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : const Color(0xFFE8EAF5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: value ? AppColors.primary : AppColors.textLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: value ? AppColors.textDark : AppColors.textLight,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _actionButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary ? AppColors.primary : Color(0xFFDDE0F0),
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isPrimary ? Colors.white : AppColors.primary,
                    ),
                  )
                : Icon(
                    icon,
                    size: 16,
                    color: isPrimary ? Colors.white : AppColors.primary,
                  ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<Uint8List> _buildPdfBytes() {
    return _ReportPdfBuilder.build(
      project: widget.project,
      report: widget.report,
      categoryCosts: widget.categoryCosts,
      categoryBudgets: widget.categoryBudgets,
      entries: widget.entries,
      phases: widget.phases,
      inventoryItems: widget.inventoryItems,
      fromDate: widget.fromDate,
      toDate: widget.toDate,
      includeCostBreakdown: _includeCostBreakdown,
      includeCategoryChart: _includeCategoryChart,
      includeEntryLog: _includeEntryLog,
      includeActivityProgress: _includeActivityProgress,
      includeInventory: _includeInventory,
    );
  }
  Future<void> _previewPdf() async {
    Navigator.pop(context);
    final bytes = await _buildPdfBytes();
    if (!mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
  Future<void> _sharePdf() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _buildPdfBytes();
      final fileName =
          'buildtrack_${widget.project.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      if (kIsWeb) {
        if (!mounted) return;
        Navigator.pop(context);
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                name: fileName,
                mimeType: 'application/pdf',
              ),
            ],
            subject: 'BuildTrack Report – ${widget.project.name}',
          ),
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        if (!mounted) return;
        Navigator.pop(context);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/pdf')],
            subject: 'BuildTrack Report – ${widget.project.name}',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
class _ReportPdfBuilder {
  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _fmtAmt(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)} L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} K';
    return v.toStringAsFixed(0);
  }
  static Future<Uint8List> build({
    required ProjectModel project,
    required ReportModel report,
    required Map<String, double> categoryCosts,
    required Map<String, double> categoryBudgets,
    required List<EntryModel> entries,
    required List<ProjectPhase> phases,
    required List<dynamic> inventoryItems,
    required DateTime fromDate,
    required DateTime toDate,
    required bool includeCostBreakdown,
    required bool includeCategoryChart,
    required bool includeEntryLog,
    required bool includeActivityProgress,
    required bool includeInventory,
  }) async {
    final doc = pw.Document();
    final primaryColor = PdfColor.fromHex('#5B5FCF');
    final lightBg = PdfColor.fromHex('#F5F6FA');
    final textDark = PdfColor.fromHex('#1A1D3A');
    final textGray = PdfColor.fromHex('#8A92A6');
    final successColor = PdfColor.fromHex('#2E7D32');
    final errorColor = PdfColor.fromHex('#C62828');
    final targetBarColor = PdfColor.fromHex('#EF9A9A');
    final totalSpent = categoryCosts.values.fold(0.0, (s, v) => s + v);
    final totalBudget = categoryBudgets.values.fold(0.0, (s, v) => s + v);
    final isOver = totalBudget > 0 && totalSpent > totalBudget;
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'BuildTrack',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Project Report',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    project.name,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${_fmt(fromDate)} – ${_fmt(toDate)}',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}   •   Generated ${_fmt(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: textGray),
          ),
        ),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      project.name,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      project.location,
                      style: pw.TextStyle(fontSize: 10, color: textGray),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${(project.progress * 100).toStringAsFixed(1)}% Complete',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Budget: ${_fmtAmt(project.totalBudget)}',
                      style: pw.TextStyle(fontSize: 10, color: textGray),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          if (includeCostBreakdown) ...[
            _sectionTitle('Cost Summary', primaryColor),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                _summaryBox(
                  'Total Spent',
                  _fmtAmt(totalSpent),
                  primaryColor,
                  lightBg,
                ),
                pw.SizedBox(width: 12),
                _summaryBox(
                  'Total Budget',
                  _fmtAmt(totalBudget),
                  successColor,
                  lightBg,
                ),
                pw.SizedBox(width: 12),
                _summaryBox(
                  'Variance',
                  _fmtAmt((totalSpent - totalBudget).abs()),
                  isOver ? errorColor : successColor,
                  lightBg,
                  sub: isOver ? 'Over budget' : 'Within budget',
                ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
          if (includeCategoryChart) ...[
            _sectionTitle('Spend vs Budget by Category', primaryColor),
            pw.SizedBox(height: 10),
            _categoryChart(
              categoryCosts,
              categoryBudgets,
              primaryColor,
              targetBarColor,
              textGray,
              textDark,
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                _legendDot(primaryColor),
                pw.SizedBox(width: 4),
                pw.Text(
                  'Actual',
                  style: pw.TextStyle(fontSize: 8, color: textGray),
                ),
                pw.SizedBox(width: 14),
                _legendDot(targetBarColor),
                pw.SizedBox(width: 4),
                pw.Text(
                  'Budget',
                  style: pw.TextStyle(fontSize: 8, color: textGray),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColor.fromHex('#E8EAF5'),
                  width: 0.5,
                ),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBg),
                  children: [
                    _tCell('Category', bold: true, color: textGray),
                    _tCell('Actual', bold: true, color: textGray),
                    _tCell('Budget', bold: true, color: textGray),
                    _tCell('Variance', bold: true, color: textGray),
                    _tCell('Usage', bold: true, color: textGray),
                  ],
                ),
                ...categoryCosts.entries.map((e) {
                  final budget = categoryBudgets[e.key] ?? 0;
                  final hasBudget = budget > 0;
                  final pct = hasBudget
                      ? '${(e.value / budget * 100).toStringAsFixed(0)}%'
                      : '—';
                  final over = hasBudget && e.value > budget;
                  final varColor = over ? errorColor : successColor;
                  return pw.TableRow(
                    children: [
                      _tCell(e.key, color: textDark),
                      _tCell(_fmtAmt(e.value), color: primaryColor, bold: true),
                      _tCell(
                        hasBudget ? _fmtAmt(budget) : '—',
                        color: textGray,
                      ),
                      _tCell(
                        hasBudget ? _fmtAmt((e.value - budget).abs()) : '—',
                        color: varColor,
                        bold: true,
                      ),
                      _tCell(
                        pct,
                        color: over ? errorColor : successColor,
                        bold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
          if (includeEntryLog && entries.isNotEmpty) ...[
            _sectionTitle(
              'Entry Log (${entries.length} entries)',
              primaryColor,
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColor.fromHex('#E8EAF5'),
                  width: 0.5,
                ),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(3.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBg),
                  children: [
                    _tCell('Date', bold: true, color: textGray),
                    _tCell('Description', bold: true, color: textGray),
                    _tCell('Type', bold: true, color: textGray),
                    _tCell('Amount', bold: true, color: textGray),
                  ],
                ),
                ...entries
                    .take(100)
                    .map(
                      (e) => pw.TableRow(
                        children: [
                          _tCell(_fmt(e.date), color: textGray),
                          _tCell(
                            e.description.isNotEmpty
                                ? e.description
                                : e.type.name,
                            color: textDark,
                          ),
                          _tCell(e.type.name, color: textGray),
                          _tCell(
                            _fmtAmt(e.amount),
                            color: primaryColor,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                if (entries.length > 100)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '… and ${entries.length - 100} more entries not shown',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: textGray,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ),
                      _tCell('', color: textGray),
                      _tCell('', color: textGray),
                      _tCell('', color: textGray),
                    ],
                  ),
              ],
            ),
          ],
          if (includeEntryLog && entries.isEmpty) ...[
            _sectionTitle('Entry Log', primaryColor),
            pw.SizedBox(height: 10),
            pw.Text(
              'No entries found for the selected date range.',
              style: pw.TextStyle(fontSize: 10, color: textGray),
            ),
          ],
          if (includeActivityProgress) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Activity Progress', primaryColor),
            pw.SizedBox(height: 10),
            if (phases.isEmpty)
              pw.Text(
                'No phases/activities tracked for this project.',
                style: pw.TextStyle(fontSize: 10, color: textGray),
              )
            else
              ...phases.map((phase) {
                final total = phase.totalCount;
                final done = phase.completedCount;
                final pct = total > 0
                    ? '${((done / total) * 100).toStringAsFixed(0)}%'
                    : '—';
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            phase.phaseName,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          pw.Text(
                            '$done / $total ($pct)',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      if (phase.activities.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        ...phase.activities.map(
                          (a) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            child: pw.Text(
                              '${a.completed ? "[x]" : "[ ]"} ${a.name}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: a.completed ? textDark : textGray,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
          if (includeInventory) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Inventory Status', primaryColor),
            pw.SizedBox(height: 10),
            if (inventoryItems.isEmpty)
              pw.Text(
                'No inventory data available for this project.',
                style: pw.TextStyle(fontSize: 10, color: textGray),
              )
            else
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                    color: PdfColor.fromHex('#E8EAF5'),
                    width: 0.5,
                  ),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      _tCell('Material', bold: true, color: textGray),
                      _tCell('Stock', bold: true, color: textGray),
                      _tCell('Status', bold: true, color: textGray),
                    ],
                  ),
                  ...inventoryItems.map((raw) {
                    final item = raw as Map<String, dynamic>;
                    final name = item['materialName']?.toString() ?? 'Unknown';
                    final unit = item['unit']?.toString() ?? '';
                    final closing =
                        (item['closingStock'] as num?)?.toDouble() ?? 0.0;
                    final threshold =
                        (item['threshold'] as num?)?.toDouble() ?? 10.0;
                    final pct = threshold > 0 ? closing / threshold : 1.0;
                    final isCritical = closing <= 0 || pct < 0.30;
                    final isLow = !isCritical && pct < 0.60;
                    final statusColor = isCritical
                        ? errorColor
                        : isLow
                        ? PdfColor.fromHex('#E65100')
                        : successColor;
                    final statusLabel = isCritical
                        ? 'Critical'
                        : isLow
                        ? 'Low'
                        : 'OK';
                    return pw.TableRow(
                      children: [
                        _tCell(name, color: textDark),
                        _tCell(
                          '${closing.toStringAsFixed(0)} $unit',
                          color: textGray,
                        ),
                        _tCell(statusLabel, color: statusColor, bold: true),
                      ],
                    );
                  }),
                ],
              ),
          ],
        ],
      ),
    );
    return doc.save();
  }
  static pw.Widget _sectionTitle(String title, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: color, width: 2)),
    ),
    child: pw.Text(
      title.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: color,
        letterSpacing: 1.2,
      ),
    ),
  );
  static pw.Widget _summaryBox(
    String label,
    String value,
    PdfColor color,
    PdfColor bg, {
    String? sub,
  }) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromHex('#8A92A6'),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          if (sub != null)
            pw.Text(sub, style: pw.TextStyle(fontSize: 9, color: color)),
        ],
      ),
    ),
  );
  static pw.Widget _tCell(String text, {bool bold = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColor.fromHex('#1A1D3A'),
          ),
        ),
      );
  static pw.Widget _categoryChart(
    Map<String, double> categoryCosts,
    Map<String, double> categoryBudgets,
    PdfColor actualColor,
    PdfColor targetColor,
    PdfColor textGray,
    PdfColor textDark,
  ) {
    const maxBarHeight = 90.0;
    final allValues = [...categoryCosts.values, ...categoryBudgets.values];
    final maxVal = allValues.isEmpty
        ? 1.0
        : allValues.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FAFBFF'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: categoryCosts.entries.map((e) {
          final actual = e.value;
          final budget = categoryBudgets[e.key] ?? 0;
          final actualH = (actual / safeMax) * maxBarHeight;
          final budgetH = (budget / safeMax) * maxBarHeight;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 16,
                    height: actualH < 2 ? 2 : actualH,
                    decoration: pw.BoxDecoration(
                      color: actualColor,
                      borderRadius: const pw.BorderRadius.vertical(
                        top: pw.Radius.circular(3),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Container(
                    width: 16,
                    height: budgetH < 2 ? 2 : budgetH,
                    decoration: pw.BoxDecoration(
                      color: targetColor,
                      borderRadius: const pw.BorderRadius.vertical(
                        top: pw.Radius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                e.key,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: textDark,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
  static pw.Widget _legendDot(PdfColor color) => pw.Container(
    width: 8,
    height: 8,
    decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
  );
}
class _ExportDetailsHintCard extends StatelessWidget {
  const _ExportDetailsHintCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E5FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A6CF7), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Want the full breakdown?',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Activity log, inventory status & every entry — pick what to include and export as PDF.',
                  style: AppTheme.caption.copyWith(
                    color: AppColors.textLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Export',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _ProjectSummaryCard extends StatelessWidget {
  final ProjectModel project;
  final ReportModel report;
  const _ProjectSummaryCard({required this.project, required this.report});
  @override
  Widget build(BuildContext context) {
    final totalTarget =
        report.targetMaterial +
        report.targetLabour +
        report.targetEquipment +
        report.targetMisc;
    final spentPct = totalTarget > 0
        ? (report.totalCost / totalTarget).clamp(0.0, 1.0)
        : project.progress;
    final isOver = totalTarget > 0 && report.totalCost > totalTarget;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.name,
            style: AppTheme.heading2.copyWith(
              fontSize: 18,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.textLight,
              ),
              const SizedBox(width: 4),
              Text(
                project.location,
                style: AppTheme.caption.copyWith(
                  fontSize: 13,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (project.id != 'all')
                Text(
                  'Stage: ${project.stage.name.toUpperCase()}',
                  style: AppTheme.label.copyWith(color: AppColors.primary),
                )
              else
                Text(
                  'Aggregate Portfolio View',
                  style: AppTheme.label.copyWith(color: AppColors.primary),
                ),
              Text(
                '${(project.progress * 100).toStringAsFixed(1)}% Complete',
                style: AppTheme.label.copyWith(color: AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: ${report.formattedTotal}',
                style: AppTheme.caption.copyWith(
                  color: isOver ? AppColors.error : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (totalTarget > 0)
                Text(
                  'Budget: ${formatCurrency(totalTarget)}',
                  style: AppTheme.caption.copyWith(color: AppColors.textLight),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LinearProgressIndicator(
              value: spentPct,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8ECF8),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
          if (isOver)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Budget exceeded by ${formatCurrency(report.totalCost - totalTarget)}',
                style: AppTheme.caption.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
class _CategoryBreakdownCard extends StatelessWidget {
  final ProjectModel project;
  final Map<String, double> categoryCosts;
  final Map<String, double> categoryBudgets;
  const _CategoryBreakdownCard({
    required this.project,
    required this.categoryCosts,
    required this.categoryBudgets,
  });
  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: categoryCosts.entries.map((e) {
          final cat = e.key;
          final cost = e.value;
          final budget = categoryBudgets[cat] ?? 0.0;
          final hasBudget = budget > 0;
          final pct = hasBudget ? (cost / budget).clamp(0.0, 1.0) : 0.0;
          final color = pct >= 0.9
              ? AppColors.error
              : pct >= 0.6
              ? AppColors.warning
              : AppColors.primary;
          return InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              '/logs',
              arguments: {'projectId': project.id, 'category': cat},
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cat,
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        formatCurrency(cost),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        hasBudget ? ' / ${formatCurrency(budget)}' : ' / —',
                        style: AppTheme.caption.copyWith(
                          color: AppColors.textLight,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: AppColors.textLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: const Color(0xFFEEF0F8),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 38,
                        child: Text(
                          hasBudget
                              ? '${(pct * 100).toStringAsFixed(0)}%'
                              : '—',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasBudget && cost > budget)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Exceeded by ${formatCurrency(cost - budget)}',
                        style: AppTheme.caption.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
