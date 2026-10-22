import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/screen/reports/save_helper_stub.dart'
    if (dart.library.html) 'package:buildtrack_mobile/screen/reports/save_helper_web.dart'
    if (dart.library.io) 'package:buildtrack_mobile/screen/reports/save_helper_mobile.dart';

/// Bulk CSV import shared by Add Entry and Reports.
///
/// There is ONE template ([CsvTemplate]) and ONE parser ([CsvImportHelper.parseRows]),
/// so a file downloaded on either screen can be uploaded on either screen.
/// The parser also still reads the older files: the per-type Add Entry
/// templates (`Material / Item`, `Labour Type`, `Equipment Name` …) and the
/// Reports export/template headers (`Purchased Date`, `Description`,
/// `Amount (INR)`, `Paid`, `Transaction ID`, `Payment 1 Amount` …).

class CsvImportResult {
  final int totalRows;
  final int successCount;
  final int failedCount;
  final int materialCount;
  final int labourCount;
  final int equipmentCount;
  final List<String> errors;
  const CsvImportResult({
    required this.totalRows,
    required this.successCount,
    required this.failedCount,
    required this.materialCount,
    required this.labourCount,
    required this.equipmentCount,
    required this.errors,
  });
}

/// Rows turned into API payloads, before upload.
class CsvParseResult {
  CsvParseResult();
  int totalRows = 0;
  final List<Map<String, dynamic>> payloads = [];
  /// Spreadsheet row number (header = row 1) of each payload.
  final List<int> rowNumbers = [];
  final List<String> errors = [];
  int materialCount = 0;
  int labourCount = 0;
  int equipmentCount = 0;
}

// ─────────────────────────────────────────────────────────────── template

/// The single bulk-import template (column names, order, required columns)
/// and the user's saved column choice — shared by Add Entry and Reports.
class CsvTemplate {
  static const List<String> defaultColumns = [
    'Date',
    'Project',
    'Floor',
    'Phase',
    'Activity',
    'Type',
    'Name',
    'Category / Trade',
    'Subtype',
    'Brand',
    'Supplier / Operator',
    'Quantity',
    'Unit',
    'Rate',
    'Overtime',
    'IsWithGst',
    'GstPercentage',
    'Payment Status',
    'Paid Amount',
    'Payment Date',
    'Payment Mode',
    'Notes',
  ];

  /// Always in the file: every row needs a type and a name.
  static const Set<String> requiredColumns = {'Type', 'Name'};

  /// One-line help per column (shown in the Columns sheet).
  static const Map<String, String> help = {
    'Date': 'Entry date, e.g. 2026-10-22 or 22/10/2026',
    'Project': 'Project name; blank uses the selected project',
    'Floor': 'Optional',
    'Phase': 'Optional, matched to the project phases',
    'Activity': 'Optional, matched to the phase activities',
    'Type': 'Material, Labour or Equipment',
    'Name': 'Item, worker type or machine',
    'Category / Trade': 'Material category or labour trade',
    'Subtype': 'Materials: Purchase or Consumption',
    'Brand': 'Brand, or machine model',
    'Supplier / Operator': 'Supplier, contractor or operator',
    'Quantity': 'Qty, days or hours',
    'Unit': 'bag, kg, ton, sqft, day, hour, trip…',
    'Rate': 'Price per unit',
    'Overtime': 'Labour overtime amount',
    'IsWithGst': 'yes / no',
    'GstPercentage': 'e.g. 18',
    'Payment Status': 'Paid, Partial or Pending',
    'Paid Amount': 'Amount already paid',
    'Payment Date': 'Date of the payment',
    'Payment Mode': 'Cash, UPI, Bank transfer, Cheque…',
    'Notes': 'Optional',
  };

  static String get _orderKey => 'csvTemplateColumns_${UserSession.userId}';
  static String get _hiddenKey => 'csvTemplateHidden_${UserSession.userId}';

  /// Saved order (all columns) and the hidden ones.
  static Future<({List<String> order, Set<String> hidden})> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_orderKey);
      final hidden = (prefs.getStringList(_hiddenKey) ?? const <String>[]).toSet();
      final order = <String>[
        ...?saved?.where(defaultColumns.contains),
        ...defaultColumns.where((c) => saved == null || !saved.contains(c)),
      ];
      hidden
        ..removeWhere((c) => !defaultColumns.contains(c))
        ..removeAll(requiredColumns);
      return (order: order, hidden: hidden);
    } catch (_) {
      return (order: List<String>.from(defaultColumns), hidden: <String>{});
    }
  }

  static Future<void> save(List<String> order, Set<String> hidden) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_orderKey, order);
      await prefs.setStringList(_hiddenKey, hidden.toList());
    } catch (_) {}
  }

  /// Column headers the template file will have, in order.
  static Future<List<String>> visibleColumns() async {
    final c = await load();
    return c.order.where((col) => !c.hidden.contains(col)).toList();
  }

  /// Opens the shared "Template columns" sheet; returns the new visible
  /// columns, or null if the user closed it without applying.
  static Future<List<String>?> openColumnsSheet(BuildContext context) async {
    final current = await load();
    if (!context.mounted) return null;
    final result = await showModalBottomSheet<({List<String> order, Set<String> hidden})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Bt.scrim,
      builder: (_) => CsvTemplateColumnsSheet(initialOrder: current.order, initialHidden: current.hidden),
    );
    if (result == null) return null;
    await save(result.order, result.hidden);
    return result.order.where((c) => !result.hidden.contains(c)).toList();
  }
}

/// Pick, hide and reorder the template columns (shared by both screens).
class CsvTemplateColumnsSheet extends StatefulWidget {
  const CsvTemplateColumnsSheet({super.key, required this.initialOrder, required this.initialHidden});
  final List<String> initialOrder;
  final Set<String> initialHidden;
  @override
  State<CsvTemplateColumnsSheet> createState() => _CsvTemplateColumnsSheetState();
}

class _CsvTemplateColumnsSheetState extends State<CsvTemplateColumnsSheet> {
  late List<String> _order = List.of(widget.initialOrder);
  late Set<String> _hidden = Set.of(widget.initialHidden);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BtSheetHeader(
              title: 'Template columns',
              subtitle: '${_order.length - _hidden.length} of ${_order.length} in the file · drag ≡ to reorder',
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Bt.rCard),
                    border: Border.all(color: Bt.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    itemCount: _order.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        _order.insert(newIndex, _order.removeAt(oldIndex));
                      });
                    },
                    itemBuilder: (context, index) {
                      final col = _order[index];
                      final required = CsvTemplate.requiredColumns.contains(col);
                      final shown = !_hidden.contains(col);
                      return Material(
                        key: ValueKey(col),
                        color: Bt.card,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (index > 0) const Divider(height: 1, indent: 16, color: Bt.line),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 56),
                              child: Row(children: [
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(col, style: BtText.body(context, color: shown ? Bt.ink : Bt.ink3)),
                                        Text(
                                          required ? 'Required · ${CsvTemplate.help[col] ?? ''}' : (CsvTemplate.help[col] ?? ''),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: BtText.caption(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                BtSwitch(
                                  value: shown,
                                  onChanged: required
                                      ? null
                                      : (val) => setState(() => val ? _hidden.remove(col) : _hidden.add(col)),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const SizedBox(width: 48, height: 52, child: Icon(Icons.drag_handle_rounded, color: Bt.ink3)),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: BtButton(
                      label: 'Reset to default',
                      variant: BtButtonVariant.secondary,
                      onPressed: () => setState(() {
                        _order = List.of(CsvTemplate.defaultColumns);
                        _hidden = {};
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: BtButton(
                      label: 'Apply Changes',
                      onPressed: () => Navigator.pop(context, (order: _order, hidden: _hidden)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── import

class CsvImportHelper {
  static const int maxRows = 100;

  /// Downloads the shared template with the user's saved columns.
  static Future<void> downloadTemplate({List<String>? columns}) async {
    final headers = columns ?? await CsvTemplate.visibleColumns();
    final csv = const ListToCsvConverter().convert([headers]);
    await saveAndShareCsv(
      csvContent: csv,
      filename: 'buildtrack_import_template.csv',
      shareText: 'BuildTrack bulk import template',
    );
  }

  /// Opens the file picker; null when the user cancels.
  static Future<List<List<dynamic>>?> pickCsvRows() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.first.bytes;
    if (bytes == null) throw Exception('Failed to read file data');
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1); // Excel BOM
    // Excel writes \r\n, Numbers/Sheets often \n; the parser needs the right one.
    final eol = text.contains('\r\n') ? '\r\n' : (text.contains('\n') ? '\n' : '\r');
    return const CsvToListConverter(shouldParseNumbers: false).convert(text, eol: eol);
  }

  /// Picks a file, parses it and uploads it. Null when the user cancels.
  static Future<CsvImportResult?> importCsv({
    required List<ProjectModel> projects,
    ProjectModel? defaultProject,
    void Function(String text, double value)? onProgress,
  }) async {
    final rows = await pickCsvRows();
    if (rows == null) return null;
    return importRows(rows, projects: projects, defaultProject: defaultProject, onProgress: onProgress);
  }

  /// Parses [rows] and uploads them in one bulk call.
  static Future<CsvImportResult> importRows(
    List<List<dynamic>> rows, {
    required List<ProjectModel> projects,
    ProjectModel? defaultProject,
    void Function(String text, double value)? onProgress,
  }) async {
    final parsed = parseRows(rows, projects: projects, defaultProject: defaultProject, onProgress: onProgress);
    var success = 0;
    var failed = parsed.errors.length;
    final errors = List<String>.from(parsed.errors);
    if (parsed.payloads.isNotEmpty) {
      onProgress?.call('Uploading ${parsed.payloads.length} entries…', .9);
      // Snapshot for "Revert last CSV import".
      try {
        await ApiService.backupCsv();
      } catch (_) {}
      final res = await ApiService.addTransactionsBulk(parsed.payloads);
      final results = res?['results'];
      if (results is Map) {
        int n(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
        success = results.containsKey('successCount')
            ? n(results['successCount'])
            : n(results['created']) + n(results['updated']);
        failed += n(results['failedCount']);
        for (final f in (results['failures'] as List? ?? const [])) {
          if (f is! Map) continue;
          final i = f['index'];
          final row = i is num && i >= 0 && i < parsed.rowNumbers.length ? 'Row ${parsed.rowNumbers[i.toInt()]}' : 'Row';
          errors.add('$row (${f['title'] ?? 'Unknown'}): ${f['reason'] ?? f['error'] ?? 'Unknown error'}');
        }
      } else {
        // Not retried row by row: the server may already have saved some rows.
        failed += parsed.payloads.length;
        errors.add('Upload failed. Check your entries before trying again — some rows may already be saved.');
      }
    }
    return CsvImportResult(
      totalRows: parsed.totalRows,
      successCount: success,
      failedCount: failed,
      materialCount: parsed.materialCount,
      labourCount: parsed.labourCount,
      equipmentCount: parsed.equipmentCount,
      errors: errors,
    );
  }

  // Header aliases → field. Lower-case, single spaces.
  static const Map<String, String> _aliases = {
    'date': 'date', 'purchased date': 'date', 'entry date': 'date',
    'project': 'project', 'project name': 'project',
    'floor': 'floor',
    'phase': 'phase',
    'activity': 'activity',
    'type': 'type', 'entry type': 'type',
    'name': 'name', 'description': 'name', 'title': 'name', 'item': 'name',
    'material': 'name', 'material / item': 'name', 'material_item': 'name',
    'worker type': 'name', 'labour type': 'name', 'labour_type': 'name',
    'equipment': 'name', 'equipment name': 'name', 'equipment_name': 'name',
    'category / trade': 'category', 'category_or_trade': 'category', 'category': 'category',
    'trade / work type': 'category', 'trade_work_type': 'category', 'trade': 'category',
    'subtype': 'subtype', 'sub type': 'subtype',
    'brand': 'brand', 'machinery sub-class / model': 'brand', 'machinery_subclass_model': 'brand', 'model': 'brand',
    'supplier / operator': 'supplier', 'supplier_or_operator': 'supplier', 'supplier': 'supplier',
    'operator / vendor': 'supplier', 'operator_vendor': 'supplier', 'operator': 'supplier', 'vendor': 'supplier',
    'contractor / team': 'supplier', 'contractor_team': 'supplier', 'contractor': 'supplier',
    'quantity': 'qty', 'qty': 'qty', 'days': 'qty', 'duration': 'qty',
    'unit': 'unit',
    'rate': 'rate', 'rate/day': 'rate', 'rent rate': 'rate', 'unit rate': 'rate',
    'overtime': 'overtime', 'overtime amount': 'overtime', 'overtime_amount': 'overtime',
    'iswithgst': 'isWithGst', 'with gst': 'isWithGst',
    'gstpercentage': 'gstPct', 'gst %': 'gstPct', 'gst percentage': 'gstPct',
    'payment status': 'status', 'payment_status': 'status', 'status': 'status',
    'paid amount': 'paid', 'paid': 'paid', 'amount paid': 'paid',
    'amount': 'amount', 'amount (inr)': 'amount', 'total': 'amount', 'total amount': 'amount',
    'payment date': 'payDate', 'pay date': 'payDate',
    'payment mode': 'payMode', 'payment method': 'payMode',
    'notes': 'notes', 'note': 'notes', 'remarks': 'notes',
    'transaction id': 'transactionId',
    'action': 'action', 'row action status': 'action', 'changed': 'action',
  };

  /// Old per-type templates had no Type column; the name header tells the type.
  static const Map<String, String> _typeFromNameHeader = {
    'material': 'material', 'material / item': 'material', 'material_item': 'material',
    'worker type': 'labour', 'labour type': 'labour', 'labour_type': 'labour',
    'equipment': 'equipment', 'equipment name': 'equipment', 'equipment_name': 'equipment',
  };

  static String _clean(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    final l = s.toLowerCase();
    // "###" is the template's "skipped" marker.
    if (l == 'null' || s == '-' || s == '—' || s == '###') return '';
    return s;
  }

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    final clean = _clean(v).replaceAll(RegExp(r'[^\d.\-]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  static bool _bool(dynamic v) {
    final s = _clean(v).toLowerCase();
    return s == 'true' || s == 'yes' || s == 'y' || s == '1';
  }

  /// ISO (2026-10-22), d/m/y (22/10/2026, 22-10-2026) or y/m/d.
  static DateTime? _date(String s) {
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.isUtc ? iso.toLocal() : iso;
    final parts = s.split(RegExp(r'[/\-.| ]')).where((p) => p.isNotEmpty).toList();
    if (parts.length < 3) return null;
    final a = int.tryParse(parts[0]), b = int.tryParse(parts[1]), c = int.tryParse(parts[2]);
    if (a == null || b == null || c == null) return null;
    if (a > 31) return DateTime(a, b, c); // y/m/d
    if (c > 31) return DateTime(c, b, a); // d/m/y
    return null;
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String? _kind(String raw) {
    final t = raw.toLowerCase();
    if (t.isEmpty) return null;
    if (t.contains('labour') || t.contains('labor') || t.contains('wage')) return 'labour';
    if (t.contains('equip') || t.contains('expense') || t.contains('machin')) return 'equipment';
    if (t.contains('material')) return 'material';
    return '?';
  }

  /// Turns CSV rows (first row = headers) into bulk-API payloads.
  static CsvParseResult parseRows(
    List<List<dynamic>> rows, {
    required List<ProjectModel> projects,
    ProjectModel? defaultProject,
    void Function(String text, double value)? onProgress,
  }) {
    final out = CsvParseResult();
    if (rows.length <= 1) throw Exception('CSV file is empty or has no data rows');
    final dataRows = rows.skip(1).where((r) => r.any((c) => _clean(c).isNotEmpty)).length;
    out.totalRows = dataRows;
    if (dataRows == 0) throw Exception('CSV file is empty or has no data rows');
    if (dataRows > maxRows) {
      throw Exception('CSV has $dataRows rows; the limit is $maxRows per upload. Split the file and try again.');
    }

    final headers = rows.first.map((h) => h.toString().replaceAll('﻿', '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')).toList();
    final idx = <String, int>{};
    String? headerType;
    for (var i = 0; i < headers.length; i++) {
      final field = _aliases[headers[i]];
      if (field != null) idx.putIfAbsent(field, () => i);
      headerType ??= _typeFromNameHeader[headers[i]];
    }
    final payCols = <int, ({int? amount, int? date, int? mode})>{};
    for (var i = 0; i < headers.length; i++) {
      final m = RegExp(r'^payment (\d+) (amount|date|mode)$').firstMatch(headers[i]);
      if (m == null) continue;
      final n = int.parse(m.group(1)!);
      final p = payCols[n] ?? (amount: null, date: null, mode: null);
      payCols[n] = switch (m.group(2)) {
        'amount' => (amount: i, date: p.date, mode: p.mode),
        'date' => (amount: p.amount, date: i, mode: p.mode),
        _ => (amount: p.amount, date: p.date, mode: i),
      };
    }
    if (!idx.containsKey('name')) {
      throw Exception("CSV is missing the 'Name' column (Description, Material, Worker Type or Equipment also work).");
    }

    var done = 0;
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (!row.any((c) => _clean(c).isNotEmpty)) continue;
      final rowNum = r + 1;
      done++;
      onProgress?.call('Processing row $done of $dataRows…', .9 * done / dataRows);
      String cell(String f) {
        final i = idx[f];
        return i != null && i < row.length ? _clean(row[i]) : '';
      }
      double number(String f) {
        final i = idx[f];
        return i != null && i < row.length ? _num(row[i]) : 0.0;
      }
      try {
        // ── project
        final projName = cell('project');
        ProjectModel? project;
        if (projName.isNotEmpty) {
          project = projects.where((p) => p.name.trim().toLowerCase() == projName.toLowerCase() || p.id == projName).firstOrNull;
          if (project == null) throw Exception("Row $rowNum: No project named '$projName' in your account");
        } else {
          project = defaultProject;
          if (project == null) throw Exception('Row $rowNum: No project in the row and no project selected in the app');
        }
        final projectId = project.id;

        // ── floor / phase / activity
        final csvFloor = cell('floor');
        final floor = csvFloor.isNotEmpty ? csvFloor : (project.floors?.isNotEmpty == true ? project.floors!.first : null);
        final csvPhase = cell('phase');
        String? phaseName;
        String? phaseId;
        if (csvPhase.isNotEmpty) {
          final m = project.selectedPhases?.where((p) => p.phaseName.trim().toLowerCase() == csvPhase.toLowerCase()).firstOrNull;
          phaseName = m?.phaseName ?? csvPhase;
          phaseId = m?.id;
        }
        final csvActivity = cell('activity');
        String? activityName;
        String? activityId;
        if (csvActivity.isNotEmpty) {
          for (final phase in project.selectedPhases ?? const <ProjectPhase>[]) {
            if (phaseName != null && phase.phaseName.trim().toLowerCase() != phaseName.trim().toLowerCase()) continue;
            final a = phase.activities.where((a) => a.name.trim().toLowerCase() == csvActivity.toLowerCase()).firstOrNull;
            if (a != null) {
              activityName = a.name;
              activityId = a.id;
              if (phaseName == null) {
                phaseName = phase.phaseName;
                phaseId = phase.id;
              }
              break;
            }
          }
          activityName ??= csvActivity;
        }

        // ── type
        var kind = _kind(cell('type')) ?? headerType;
        if (kind == '?') throw Exception("Row $rowNum: Unknown type '${cell('type')}'. Use Material, Labour or Equipment.");
        kind ??= cell('subtype').isNotEmpty
            ? 'material'
            : number('overtime') > 0
                ? 'labour'
                : cell('supplier').isNotEmpty && cell('brand').isEmpty
                    ? 'equipment'
                    : 'material';

        // ── name
        var name = cell('name');
        if (name.isEmpty) throw Exception('Row $rowNum: Name is empty');

        // ── numbers
        final rate = number('rate');
        final qtyRaw = cell('qty');
        final qty = qtyRaw.isNotEmpty ? _num(qtyRaw) : (rate > 0 ? 1.0 : 0.0);
        final overtime = kind == 'labour' ? number('overtime') : 0.0;
        final isWithGst = kind != 'labour' && _bool(cell('isWithGst'));
        final gstPct = kind != 'labour' ? number('gstPct') : 0.0;
        final subtotal = qty * rate;
        var amount = subtotal + (isWithGst ? subtotal * gstPct / 100 : 0) + overtime;
        if (subtotal == 0) {
          final direct = number('amount');
          if (direct != 0) amount = direct + overtime;
        }

        // ── payment
        final statusRaw = cell('status').toLowerCase();
        final paidCol = number('paid');
        String status;
        if (statusRaw == 'fully paid' || statusRaw == 'paid' || statusRaw == 'fullypaid') {
          status = 'Paid';
        } else if (statusRaw == 'partial' || statusRaw == 'partially paid') {
          status = 'Partial';
        } else if (statusRaw.isEmpty && paidCol > 0) {
          status = paidCol >= amount ? 'Paid' : 'Partial';
        } else {
          status = 'Pending';
        }
        final paid = paidCol > 0
            ? paidCol
            : status == 'Paid'
                ? amount
                : status == 'Partial'
                    ? amount / 2
                    : 0.0;
        final payMode = cell('payMode').isNotEmpty ? cell('payMode') : 'Cash';
        final date = _date(cell('date')) ?? DateTime.now();
        final payDate = _date(cell('payDate'));
        final history = <Map<String, dynamic>>[];
        for (final p in (payCols.keys.toList()..sort())) {
          final c = payCols[p]!;
          final amt = c.amount != null && c.amount! < row.length ? _num(row[c.amount!]) : 0.0;
          if (amt <= 0) continue;
          final d = c.date != null && c.date! < row.length ? _date(_clean(row[c.date!])) : null;
          final mode = c.mode != null && c.mode! < row.length ? _clean(row[c.mode!]) : '';
          history.add({'amount': amt, 'date': _ymd(d ?? date), 'method': mode.isEmpty ? payMode : mode});
        }

        final unit = cell('unit').toLowerCase();
        final notes = cell('notes');
        final brand = cell('brand');
        final category = cell('category');
        final supplier = cell('supplier');
        final transactionId = cell('transactionId');
        final action = cell('action').toUpperCase();

        final payload = <String, dynamic>{
          if (transactionId.isNotEmpty) 'transactionId': transactionId,
          if (action.isNotEmpty) 'rowStatus': action,
          if (history.isNotEmpty) 'paymentHistory': history,
          'title': name,
          'quantity': qty,
          'rate': rate,
          'project': projectId,
          'date': _ymd(date),
          'floor': floor,
          'phase': ?phaseName,
          'phaseId': ?phaseId,
          'activity': ?activityName,
          'activityId': ?activityId,
          'amount': amount,
          'notes': notes,
          'paymentStatus': status,
          'paidAmount': paid,
          'paymentMode': payMode,
          if (payDate != null) 'paymentDate': _ymd(payDate),
        };

        if (kind == 'labour') {
          payload.addAll({
            'type': 'Wages',
            'category': category.isNotEmpty ? category : 'General Labor',
            'unit': switch (unit) {
              'day' || 'days' => 'day',
              'hour' || 'hours' || 'hr' || 'hrs' => 'hour',
              'sqft' || 'sq.ft' => 'sqft',
              _ => 'unit',
            },
            'overtime': overtime,
            'remarks': supplier.isNotEmpty ? supplier : notes,
            'worker': name,
          });
          out.labourCount++;
        } else if (kind == 'equipment') {
          payload.addAll({
            'type': 'Expense',
            'category': name,
            'unit': switch (unit) {
              'day' || 'days' => 'day',
              'hour' || 'hours' || 'hr' || 'hrs' => 'hour',
              'trip' || 'trips' || 'load' || 'shift' || 'truck' => 'truck',
              _ => 'unit',
            },
            'brand': brand,
            'supplier': supplier,
            'gst': gstPct,
            'isWithGst': isWithGst,
            'gstPercentage': isWithGst ? gstPct : 0,
            'totalAmount': amount,
          });
          out.equipmentCount++;
        } else {
          final consumption = cell('subtype').toLowerCase() == 'consumption';
          payload.addAll({
            'type': 'Materials',
            'subType': consumption ? 'Consumption' : 'Purchase',
            'materialType': consumption ? 'usage' : 'purchase',
            'category': category,
            'brand': brand.isEmpty ? null : brand,
            'supplier': supplier,
            'unit': switch (unit) {
              'bag' || 'bags' => 'bag',
              'sqft' || 'sq.ft' => 'sqft',
              'ton' || 'tons' => 'ton',
              'kg' || 'kgs' => 'kg',
              _ => 'unit',
            },
            'gst': gstPct,
            'isWithGst': isWithGst,
            if (floor != null || phaseName != null || activityName != null)
              'executionContext': {
                'project': projectId,
                'floor': ?floor,
                'phase': ?phaseName,
                'phaseId': ?phaseId,
                'activity': ?activityName,
                'activityId': ?activityId,
              },
          });
          out.materialCount++;
        }
        out.payloads.add(payload);
        out.rowNumbers.add(rowNum);
      } catch (e) {
        out.errors.add(e.toString().replaceFirst('Exception: ', ''));
      }
    }
    return out;
  }
}
