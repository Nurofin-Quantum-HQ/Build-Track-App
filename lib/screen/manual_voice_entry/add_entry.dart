import 'package:buildtrack_mobile/design/design.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/log_sheet.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/inventory_provider.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/screen/reports/csv_import_helper.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';

class AddEntryScreen extends StatelessWidget {
  AddEntryScreen({super.key});
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
        UserSession.markModuleVisited('AddEntryScreen');
        if (UserSession.globalTourActive) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) {
              // Next tab the user can open (never Inventory); ends the tour at the end.
              context.read<NavController>().continueTour(context, from: '/add-entry');
            }
          });
        }
      },
      builder: (context) => const _AddEntryScreenContent(),
    );
  }
}

class _AddEntryScreenContent extends StatefulWidget {
  const _AddEntryScreenContent();
  @override
  State<_AddEntryScreenContent> createState() => _AddEntryScreenContentState();
}
class _AddEntryScreenContentState extends State<_AddEntryScreenContent> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isUploadingCsv = false;
  /// Template columns (shared with Reports via CsvTemplate).
  List<String> _templateColumns = List.of(CsvTemplate.defaultColumns);
  final GlobalKey _csvKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    CsvTemplate.visibleColumns().then((cols) {
      if (mounted) setState(() => _templateColumns = cols);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!UserSession.hasSkippedTour && !UserSession.visitedModules.contains('AddEntryScreen')) {
        _startTour();
        UserSession.markModuleVisited('AddEntryScreen');
      }
    });
  }

  /// Tour steps in visual order; only widgets that are on screen.
  void _startTour() {
    final keys = <GlobalKey>[
      ShowcaseKeys.addEntryMaterial,
      ShowcaseKeys.addEntryLabour,
      ShowcaseKeys.addEntryEquipment,
      ShowcaseKeys.addEntryCSV,
      _csvKey,
    ].where((k) => k.currentContext != null).toList();
    if (keys.isNotEmpty) ShowCaseWidget.of(context).startShowCase(keys);
  }
  List<Map<String, dynamic>> get _entries {
    final items = <Map<String, dynamic>>[];
    if (RoleManager.canManageExpenses) {
      items.add({
        'icon': Icons.category,
        'title': 'Material',
        'subtitle':
            'Log concrete, steel, lumber, or site-specific procurement items.',
        'type': 'material',
        'short': 'Concrete, steel, lumber & site items',
      });
    }
    if (RoleManager.canAddEntries) {
      items.add({
        'icon': Icons.people,
        'title': 'Labour',
        'subtitle':
            'Track crew hours, specialized trade performance, and site presence.',
        'type': 'labour',
        'short': 'Crew hours, trades, site presence',
      });
    }
    if (RoleManager.canManageEquipmentMaster) {
      items.add({
        'icon': Icons.precision_manufacturing,
        'title': 'Equipment',
        'subtitle':
            'Record heavy machinery runtime, fuel logs, and maintenance events.',
        'type': 'equipment',
        'short': 'Machine runtime, fuel, maintenance',
      });
    }
    return items;
  }
  void _navigateToContext(BuildContext context, String type) {
    Navigator.pushNamed(
      context,
      '/execution-context',
      arguments: {'type': type},
    );
  }
  /// Same template as Reports (shared generator in csv_import_helper.dart).
  Future<void> _downloadCsvTemplate() async {
    try {
      await CsvImportHelper.downloadTemplate(columns: _templateColumns);
      if (mounted) btToast(context, 'Template downloaded successfully!');
    } catch (e) {
      if (mounted) btToast(context, 'Download failed: $e', error: true);
    }
  }

  /// Same parser and upload as Reports (csv_import_helper.dart).
  Future<void> _uploadCsv() async {
    setState(() => _isUploadingCsv = true);
    var dialogOpen = false;
    try {
      final rows = await CsvImportHelper.pickCsvRows();
      if (rows == null || !mounted) return; // cancelled
      final projectProvider = context.read<ProjectProvider>();
      if (projectProvider.projects.isEmpty) await projectProvider.load();
      if (!mounted) return;

      StateSetter? dialogSetState;
      var progressText = 'Preparing import...';
      var progressValue = 0.0;
      dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDlgState) {
            dialogSetState = setDlgState;
            return _ImportProgressDialog(text: progressText, value: progressValue);
          },
        ),
      );
      final result = await CsvImportHelper.importRows(
        rows,
        projects: projectProvider.projects,
        defaultProject: projectProvider.selectedProject,
        onProgress: (text, value) {
          progressText = text;
          progressValue = value;
          dialogSetState?.call(() {});
        },
      );
      if (mounted && dialogOpen) {
        dialogOpen = false;
        Navigator.pop(context);
      }
      if (!mounted) return;
      final activeProjId = projectProvider.selectedProject?.id;
      if (activeProjId != null) {
        context.read<InventoryProvider>().loadInventory(activeProjId);
      }
      context.read<ProjectProvider>().load();
      if (result.successCount > 0) {
        await showBtSuccess(
          context,
          kind: BtSuccessKind.bags,
          title: 'Entries imported',
          message: '${result.successCount} ${result.successCount == 1 ? 'entry' : 'entries'} added from your spreadsheet',
        );
        if (!mounted) return;
      }
      showDialog(
        context: context,
        barrierColor: Bt.scrim,
        builder: (ctx) => _ImportResultsDialog(
          successCount: result.successCount,
          failedCount: result.failedCount,
          materialCount: result.materialCount,
          labourCount: result.labourCount,
          equipmentCount: result.equipmentCount,
          errorMessages: result.errors,
        ),
      );
    } catch (e) {
      if (mounted && dialogOpen) {
        dialogOpen = false;
        Navigator.pop(context);
      }
      if (mounted) btToast(context, 'Upload failed: ${e.toString().replaceFirst('Exception: ', '')}', error: true);
    } finally {
      if (mounted) setState(() => _isUploadingCsv = false);
    }
  }
  Widget _buildCsvImportCard(BuildContext context) {
    final bt = context.bt;
    final visibleCols = _templateColumns;
    return Showcase(
      key: ShowcaseKeys.addEntryCSV,
      description: 'Add many entries at once: download the template (the same one Reports uses), fill one row per entry, then upload it here.',
      tooltipBackgroundColor: Bt.ink,
      textColor: Colors.white,
      tooltipBorderRadius: BorderRadius.circular(16),
      tooltipPadding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('IMPORT MANY', style: BtText.mono(context, color: bt.accentInk)),
          const SizedBox(height: 4),
          Text('From a\nspreadsheet.', style: BtText.d2(context)),
          const SizedBox(height: 8),
          Text(
            'Import Materials, Labour, or Equipment entries. Download the template, fill it, and upload the file — each row becomes an entry.',
            style: BtText.subhead(context),
          ),
          const SizedBox(height: 22),
          _Timeline(steps: [
            // 01 · Get the template
            _TimelineStep(
              number: 1,
              active: true,
              title: 'Get the template',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${visibleCols.length} of ${CsvTemplate.defaultColumns.length} columns · one template for all entry types, same as Reports', style: BtText.caption(context)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: BtButton(
                      label: 'Download template',
                      icon: Icons.download_rounded,
                      small: true,
                      onPressed: _isUploadingCsv ? null : _downloadCsvTemplate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Showcase(
                    key: _csvKey,
                    title: 'Customize Template',
                    description: 'Choose which columns appear in the CSV and their order. Type and Name are always included. Reports uses the same choice.',
                    child: BtButton(
                      label: 'Columns',
                      icon: Icons.tune_rounded,
                      small: true,
                      expand: false,
                      variant: BtButtonVariant.secondary,
                      onPressed: _isUploadingCsv ? null : _openCustomizeColumnsSheet,
                    ),
                  ),
                ]),
              ]),
            ),
            // 02 · Fill one row per entry
            _TimelineStep(
              number: 2,
              title: 'Fill one row per entry',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _MiniSheet(columns: visibleCols),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.info_outline_rounded, size: 15, color: Bt.ink3)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'If you skip an optional column in a row, type "###" instead of leaving it blank so the file parses correctly.',
                      style: BtText.caption(context),
                    ),
                  ),
                ]),
              ]),
            ),
            // 03 · Upload it
            _TimelineStep(
              number: 3,
              title: 'Upload it',
              child: _UploadDrop(uploading: _isUploadingCsv, onTap: _isUploadingCsv ? null : _uploadCsv),
            ),
          ]),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final types = _entries;
    return Scaffold(
      backgroundColor: Bt.ground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            SizedBox(
              height: 56,
              child: Row(children: [
                const SizedBox(width: 4),
                if (canPop)
                  BtIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 19,
                    semantic: 'Back',
                    onTap: () => Navigator.pop(context),
                  ),
                const Spacer(),
                BtIconButton(
                  icon: Icons.help_outline_rounded,
                  semantic: 'Help',
                  color: Bt.ink2,
                  onTap: _startTour,
                ),
                Semantics(
                  button: true,
                  label: 'Account',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: const Padding(padding: EdgeInsets.all(4), child: ProfileAvatar(radius: 18)),
                  ),
                ),
                const SizedBox(width: 12),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Bt.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  BtReveal(child: Text('ADD ENTRY', style: BtText.mono(context, color: context.bt.accentInk))),
                  const SizedBox(height: 4),
                  BtReveal(index: 1, child: Text('What are you\nadding?', style: BtText.d1(context))),
                  const SizedBox(height: 8),
                  BtReveal(index: 2, child: Text('Select the entry type to log for the current shift.', style: BtText.body(context, color: Bt.ink2))),
                  const SizedBox(height: 20),
                  if (types.isNotEmpty)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (var i = 0; i < types.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: _entryCard(context, i)),
                      ],
                    ]),
                  const SizedBox(height: 36),
                  _buildCsvImportCard(context),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(),
    );
  }
  Widget _entryCard(BuildContext context, int index) {
    final entry = _entries[index];
    final String type = entry['type'] as String;
    GlobalKey? showcaseKey;
    String description = '';
    if (type == 'material') {
      showcaseKey = ShowcaseKeys.addEntryMaterial;
      description = 'Log concrete, steel, lumber, or site-specific procurement items.';
    } else if (type == 'labour') {
      showcaseKey = ShowcaseKeys.addEntryLabour;
      description = 'Track crew hours, specialized trade performance, and site presence.';
    } else if (type == 'equipment') {
      showcaseKey = ShowcaseKeys.addEntryEquipment;
      description = 'Record heavy machinery runtime, fuel logs, and maintenance events.';
    }

    Widget cardContent = LogKindTile(
      type: type,
      title: entry['title'] as String,
      subtitle: entry['short'] as String,
      onTap: () => _navigateToContext(context, type),
    );

    if (showcaseKey != null) {
      return Showcase(
        key: showcaseKey,
        description: description,
        tooltipBackgroundColor: Bt.ink,
        textColor: Colors.white,
        tooltipBorderRadius: BorderRadius.circular(16),
        tooltipPadding: const EdgeInsets.all(16),
        child: cardContent,
      );
    }
    return cardContent;
  }
  Future<void> _openCustomizeColumnsSheet() async {
    final cols = await CsvTemplate.openColumnsSheet(context);
    if (cols != null && mounted) {
      setState(() => _templateColumns = cols);
      btToast(context, 'Template customization applied! Ready to download.');
    }
  }
}

// ─────────────────────────────────────────────── CSV import (Design V2 · CSV-Import board)

/// Vertical dashed timeline holding the three import steps.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});
  final List<Widget> steps;
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedRail(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 26),
          steps[i],
        ],
      ]),
    );
  }
}

class _DashedRail extends CustomPainter {
  const _DashedRail();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Bt.inputBorder
      ..strokeWidth = 1.5;
    const x = 14.0;
    for (double y = 32; y < size.height - 24; y += 8) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 4), p);
    }
  }

  @override
  bool shouldRepaint(_DashedRail oldDelegate) => false;
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.number, required this.title, required this.child, this.active = false});
  final int number;
  final String title;
  final Widget child;
  final bool active;
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Bt.ink : Bt.card,
          borderRadius: BorderRadius.circular(9),
          border: active ? null : Border.all(color: Bt.inputBorder, width: 1.5),
        ),
        child: Text(number.toString().padLeft(2, '0'), style: BtText.mono(context, color: active ? Bt.bone : Bt.ink2, size: 11)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(title, style: BtText.body(context, weight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    ]);
  }
}

/// Mini spreadsheet illustration: the first visible template columns as the
/// header, with empty rows sliding in (no fake data).
class _MiniSheet extends StatelessWidget {
  const _MiniSheet({required this.columns});
  final List<String> columns;
  @override
  Widget build(BuildContext context) {
    final cols = columns.take(4).toList();
    if (cols.isEmpty) return const SizedBox.shrink();
    final mono = BtText.mono(context, size: 9.5);
    Widget row(List<Widget> cells, {bool header = false}) => DecoratedBox(
          decoration: BoxDecoration(
            color: header ? Bt.ink.withValues(alpha: .05) : Bt.card,
            border: header ? null : const Border(top: BorderSide(color: Bt.line)),
          ),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < cells.length; i++)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(border: i < cells.length - 1 ? const Border(right: BorderSide(color: Bt.line)) : null),
                    child: cells[i],
                  ),
                ),
            ]),
          ),
        );
    return ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Bt.inputBorder)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          row([for (final c in cols) Text(c.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: mono.copyWith(color: Bt.ink))], header: true),
          for (var r = 0; r < 3; r++)
            BtReveal(
              index: r + 1,
              distance: 0,
              child: _SlideIn(
                delay: r,
                child: row([
                  for (var c = 0; c < cols.length; c++)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: const [.8, .55, .7, .45, .65][(r + c) % 5],
                        child: Container(height: 6, decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(3))),
                      ),
                    ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Slides a row in from the right once (CSV board `slideL`).
class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.child, required this.delay});
  final Widget child;
  final int delay;
  @override
  Widget build(BuildContext context) {
    if (Bt.reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + 150 * delay),
      curve: Bt.ease,
      child: child,
      builder: (_, t, c) => t >= 1 ? c! : Transform.translate(offset: Offset(24 * (1 - t), 0), child: c),
    );
  }
}

/// Dashed upload drop-zone (tap to pick a CSV).
class _UploadDrop extends StatelessWidget {
  const _UploadDrop({required this.uploading, required this.onTap});
  final bool uploading;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return BtPressable(
      onTap: onTap,
      scale: .98,
      semanticLabel: uploading ? 'Uploading' : 'Upload CSV File',
      child: CustomPaint(
        painter: const _DashedBox(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: bt.accentSoft, borderRadius: BorderRadius.circular(Bt.rTile)),
              alignment: Alignment.center,
              child: uploading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: bt.accentInk))
                  : Icon(Icons.upload_file_rounded, size: 22, color: bt.accentInk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(uploading ? 'Uploading…' : 'Upload CSV File', style: BtText.body(context, weight: FontWeight.w600)),
                Text("We'll show what imported and what didn't", style: BtText.caption(context, color: Bt.ink2)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DashedBox extends CustomPainter {
  const _DashedBox();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Bt.inputBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, (d + 5).clamp(0, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox oldDelegate) => false;
}

/// Non-dismissible progress dialog shown while rows are parsed/uploaded.
class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({required this.text, required this.value});
  final String text;
  final double value;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Bt.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: BtBrickLoader()),
          const SizedBox(height: 18),
          Text('Importing Entries', textAlign: TextAlign.center, style: BtText.d3(context)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: BtText.num(BtText.subhead(context))),
          const SizedBox(height: 16),
          BtProgress(value: value),
        ]),
      ),
    );
  }
}

/// Import results: totals, per-type breakdown and every detail/error line.
class _ImportResultsDialog extends StatelessWidget {
  const _ImportResultsDialog({
    required this.successCount,
    required this.failedCount,
    required this.materialCount,
    required this.labourCount,
    required this.equipmentCount,
    required this.errorMessages,
  });
  final int successCount;
  final int failedCount;
  final int materialCount;
  final int labourCount;
  final int equipmentCount;
  final List<String> errorMessages;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, int value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Bt.ground, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: BtText.mono(context)),
              const SizedBox(height: 4),
              Text('$value', style: BtText.d2(context, color: color)),
            ]),
          ),
        );
    return Dialog(
      backgroundColor: Bt.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Import Results', style: BtText.d3(context)),
                const SizedBox(height: 2),
                Text('Total rows processed: ${successCount + failedCount}', style: BtText.num(BtText.caption(context))),
                const SizedBox(height: 16),
                Row(children: [
                  stat('Imported', successCount, Bt.green),
                  const SizedBox(width: 8),
                  stat('Failed', failedCount, failedCount > 0 ? Bt.red : Bt.ink3),
                ]),
                const SizedBox(height: 12),
                BtValueRow(label: 'Materials', value: '$materialCount'),
                BtValueRow(label: 'Labour', value: '$labourCount'),
                BtValueRow(label: 'Equipment', value: '$equipmentCount'),
                if (errorMessages.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('DETAILS / ERRORS', style: BtText.mono(context, color: Bt.red)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Bt.redSoft, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final msg in errorMessages)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(msg, style: BtText.caption(context, color: Bt.red)),
                          ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
            child: BtButton(label: 'OK', onPressed: () => Navigator.pop(context)),
          ),
        ]),
      ),
    );
  }
}
