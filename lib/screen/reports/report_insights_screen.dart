import 'package:buildtrack_mobile/design/design.dart';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
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
      return const Scaffold(
        backgroundColor: Bt.ground,
        body: BtPageLoader(label: 'Loading insights'),
      );
    }
    if (project == null) {
      return const Scaffold(
        backgroundColor: Bt.ground,
        appBar: BtNavBar(title: 'Report Insights'),
        body: BtEmpty(
          icon: Icons.bar_chart_outlined,
          title: 'No project selected.',
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
    void openExport() => _showExportSheet(
          context,
          project!,
          report,
          categoryCosts,
          categoryBudgets,
          filteredEntries,
          phases,
          _inventoryItems,
        );
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: 'Report Insights',
        subtitle: project.name,
      ),
      bottomNavigationBar: BtCtaBar(
        children: [
          Expanded(
            child: BtButton(
              label: 'Export Report',
              icon: Icons.share_outlined,
              onPressed: openExport,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Bt.gutter, 4, Bt.gutter, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: btStagger([
            _DateRangeRow(
              fromDate: _fromDate,
              toDate: _toDate,
              onChanged: (from, to) => setState(() {
                _fromDate = from;
                _toDate = to;
              }),
            ),
            const SizedBox(height: 12),
            _ProjectSummaryCard(project: project, report: report),
            const SizedBox(height: 12),
            ChartSection(report: report),
            const SizedBox(height: 24),
            const BtSectionHeader(title: 'Category Breakdown', caption: true),
            _CategoryBreakdownCard(
              project: project,
              categoryCosts: categoryCosts,
              categoryBudgets: categoryBudgets,
            ),
            const SizedBox(height: 16),
            _ExportDetailsHintCard(onTap: openExport),
            const SizedBox(height: 24),
            BtButton(
              label: 'Update Progress',
              icon: Icons.trending_up,
              variant: BtButtonVariant.secondary,
              onPressed: () =>
                  Navigator.pushNamed(context, '/update-progress'),
            ),
            const SizedBox(height: 10),
            BtButton(
              label: 'View Full Logs',
              icon: Icons.receipt_long_outlined,
              variant: BtButtonVariant.quiet,
              onPressed: () => Navigator.pushNamed(context, '/logs'),
            ),
          ]),
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
      useSafeArea: true,
      backgroundColor: Bt.card,
      barrierColor: Bt.scrim,
      sheetAnimationStyle: btSheetStyle(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
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
    return BtPickerField(
      text: '${_fmt(fromDate)}  →  ${_fmt(toDate)}',
      leading: Icons.calendar_today_outlined,
      icon: Icons.edit_outlined,
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: DateTimeRange(start: fromDate, end: toDate),
        );
        if (picked != null) {
          onChanged(picked.start, picked.end);
        }
      },
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
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BtSheetHeader(title: 'Export Report', subtitle: widget.project.name),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.date_range, size: 16, color: Bt.ink3),
                        const SizedBox(width: 8),
                        Text(_dateRangeLabel.toUpperCase(), style: BtText.num(BtText.mono(context))),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const BtSectionHeader(title: 'Include in report', caption: true),
                    BtGroup(
                      children: [
                        _toggle('Cost Breakdown', 'Total material, labour & equipment costs', Icons.pie_chart_outline, _includeCostBreakdown, (v) => setState(() => _includeCostBreakdown = v)),
                        _toggle('Category Chart', 'Visual chart + table of budget vs actual', Icons.bar_chart_outlined, _includeCategoryChart, (v) => setState(() => _includeCategoryChart = v)),
                        _toggle('Entry Log', 'Line-by-line list of all entries', Icons.receipt_long_outlined, _includeEntryLog, (v) => setState(() => _includeEntryLog = v)),
                        _toggle('Activity Progress', 'Phase-wise completed activities', Icons.checklist_outlined, _includeActivityProgress, (v) => setState(() => _includeActivityProgress = v)),
                        _toggle('Inventory Status', 'Stock levels and reorder alerts', Icons.inventory_2_outlined, _includeInventory, (v) => setState(() => _includeInventory = v)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: BtButton(
                            label: 'Preview',
                            icon: Icons.visibility_outlined,
                            variant: BtButtonVariant.secondary,
                            onPressed: _previewPdf,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: BtButton(
                            label: _isGenerating ? 'Generating…' : 'Share PDF',
                            icon: Icons.share_outlined,
                            loading: _isGenerating,
                            onPressed: _isGenerating ? null : _sharePdf,
                          ),
                        ),
                      ],
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
  Widget _toggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return BtRow(
      leading: BtTile(icon: icon, size: 38, bg: value ? context.bt.accentSoft : Bt.fill, fg: value ? context.bt.accentInk : Bt.ink3),
      title: title,
      subtitle: subtitle,
      titleColor: value ? Bt.ink : Bt.ink2,
      minHeight: 60,
      onTap: () => onChanged(!value),
      trailing: BtSwitch(value: value, onChanged: onChanged),
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
        btToast(context, 'Export failed: $e', error: true);
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
                      fontSize: 13,
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
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${_fmt(fromDate)} – ${_fmt(toDate)}',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
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
                        fontSize: 13,
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
                            fontSize: 12,
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
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          pw.Text(
                            '$done / $total ($pct)',
                            style: pw.TextStyle(
                              fontSize: 12,
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
                                fontSize: 12,
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
        fontSize: 13,
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
              fontSize: 12,
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
            fontSize: 12,
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
                  fontSize: 12,
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
    final bt = context.bt;
    return BtCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          BtTile(icon: Icons.fact_check_outlined, bg: bt.accent, fg: bt.onAccent, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Want the full breakdown?', style: BtText.body(context, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Activity log, inventory status & every entry — pick what to include and export as PDF.',
                  style: BtText.caption(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BtButton(label: 'Export', small: true, expand: false, onPressed: onTap),
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
    return BtCard(
      variant: BtCardVariant.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('COST SUMMARY', style: BtText.mono(context, color: Bt.onNoir2))),
              Text(
                '${(project.progress * 100).toStringAsFixed(1)}% Complete',
                style: BtText.num(BtText.caption(context, color: Bt.onNoir2, weight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(project.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.headline(context).copyWith(color: Bt.bone)),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Bt.onNoir2),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  project.id != 'all'
                      ? '${project.location} · Stage: ${project.stage.name[0].toUpperCase()}${project.stage.name.substring(1).toLowerCase()}'
                      : '${project.location} · Aggregate Portfolio View',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BtText.caption(context, color: Bt.onNoir2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total spent', style: BtText.caption(context, color: Bt.onNoir2).copyWith(fontSize: 12)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: BtCountUp(
                        value: report.totalCost,
                        format: (v) => formatCurrency(v),
                        style: BtText.d2(context, color: isOver ? const Color(0xFFFF8A8E) : Bt.bone),
                      ),
                    ),
                  ],
                ),
              ),
              if (totalTarget > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total budget', style: BtText.caption(context, color: Bt.onNoir2).copyWith(fontSize: 12)),
                    Text(formatCurrency(totalTarget), style: BtText.num(BtText.headline(context).copyWith(color: Bt.bone))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          BtBricks(value: spentPct.toDouble(), onDark: true, color: isOver ? Bt.redBright : null),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(isOver ? Icons.warning_amber_rounded : Icons.check_circle_rounded, size: 16, color: isOver ? const Color(0xFFFF8A8E) : const Color(0xFF4ADBA4)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isOver ? 'Budget exceeded by ${formatCurrency(report.totalCost - totalTarget)}' : report.efficiencyNote,
                  style: BtText.caption(context, color: isOver ? const Color(0xFFFF8A8E) : const Color(0xFF4ADBA4), weight: FontWeight.w600),
                ),
              ),
            ],
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
    final bt = context.bt;
    return BtGroup(
      children: categoryCosts.entries.map((e) {
        final cat = e.key;
        final cost = e.value;
        final budget = categoryBudgets[cat] ?? 0.0;
        final hasBudget = budget > 0;
        final pct = hasBudget ? (cost / budget).clamp(0.0, 1.0) : 0.0;
        final color = pct >= 0.9
            ? Bt.red
            : pct >= 0.6
            ? Bt.amber
            : bt.accentInk;
        final barColor = pct >= 0.9
            ? Bt.redBright
            : pct >= 0.6
            ? Bt.amberBright
            : bt.accent;
        return InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            '/logs',
            arguments: {'projectId': project.id, 'category': cat},
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BtTypeTile(type: cat),
                    const SizedBox(width: 12),
                    Expanded(child: Text(cat, style: BtText.body(context, weight: FontWeight.w600))),
                    Text(formatCurrency(cost), style: BtText.num(BtText.subhead(context, color: color, weight: FontWeight.w700))),
                    Text(hasBudget ? ' / ${formatCurrency(budget)}' : ' / —', style: BtText.num(BtText.caption(context))),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: Bt.placeholder),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: BtProgress(value: pct.toDouble(), color: barColor, thin: true)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 40,
                      child: Text(
                        hasBudget ? '${(pct * 100).toStringAsFixed(0)}%' : '—',
                        textAlign: TextAlign.right,
                        style: BtText.num(BtText.caption(context, color: color, weight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                if (hasBudget && cost > budget)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Exceeded by ${formatCurrency(cost - budget)}',
                      style: BtText.caption(context, color: Bt.red, weight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
