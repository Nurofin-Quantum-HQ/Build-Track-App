import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/screen/reports/report_export_helper.dart';
import 'package:buildtrack_mobile/screen/reports/save_helper_stub.dart'
    if (dart.library.html) 'package:buildtrack_mobile/screen/reports/save_helper_web.dart'
    if (dart.library.io) 'package:buildtrack_mobile/screen/reports/save_helper_mobile.dart';
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
class CsvImportHelper {
  static Future<void> downloadTemplate({
    required String quickCategoryTab,
    required List<String> activeColumns,
  }) async {
    final headers = ReportExportHelper.getExportHeaders(
      quickCategoryTab: quickCategoryTab,
      activeColumns: activeColumns,
    );
    final csvBuffer = StringBuffer();
    csvBuffer.writeln(
      headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','),
    );
    final filename =
        'BuildTrack_Import_${quickCategoryTab}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final shareText = 'BuildTrack Import Template ($quickCategoryTab)';
    await saveAndShareCsv(
      csvContent: csvBuffer.toString(),
      filename: filename,
      shareText: shareText,
    );
  }
  /// Opens file picker, parses CSV, validates, and imports entries via API.
  static Future<CsvImportResult> importCsv({
    required List<ProjectModel> projects,
    required String? selectedProjectId,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return const CsvImportResult(
        totalRows: 0,
        successCount: 0,
        failedCount: 0,
        materialCount: 0,
        labourCount: 0,
        equipmentCount: 0,
        errors: [],
      );
    }
    final fileBytes = result.files.first.bytes;
    if (fileBytes == null) throw Exception('Failed to read file data');
    final csvString = utf8.decode(fileBytes);
    final List<List<dynamic>> parsedCsv = const CsvToListConverter().convert(
      csvString,
    );
    String parseString(dynamic v) {
      if (v == null) return '';
      final str = v.toString().trim();
      if (str.toLowerCase() == 'null' || str == '-' || str == '—' || str.contains('?')) return '';
      return str;
    }
    int materialCount = 0;
    int labourCount = 0;
    int equipmentCount = 0;
    int successCount = 0;
    int failedCount = 0;
    final List<String> errors = [];
    final totalRows = parsedCsv.length - 1;
    if (totalRows <= 0) {
      throw Exception('CSV file is empty or has no data rows');
    }
    final headers = parsedCsv.first.map((h) => h.toString().trim()).toList();
    final headerLower = headers.map((h) => h.toLowerCase()).toList();
    
    final dateIdx = headerLower.indexWhere(
      (h) => h == 'purchased date' || h == 'date',
    );
    final projectIdx = headerLower.indexOf('project');
    final typeIdx = headerLower.indexOf('type');
    // Name/description columns — use whichever is present
    final nameIdx = headerLower.indexWhere(
      (h) =>
          h == 'description' ||
          h == 'material' ||
          h == 'worker type' ||
          h == 'equipment' ||
          h == 'name',
    );
    final brandIdx = headerLower.indexOf('brand');
    final floorIdx = headerLower.indexOf('floor');
    final phaseIdx = headerLower.indexOf('phase');
    final activityIdx = headerLower.indexOf('activity');
    final unitIdx = headerLower.indexOf('unit');
    final rateIdx = headerLower.indexWhere(
      (h) => h == 'rate' || h == 'rate/day' || h == 'rent rate',
    );
    final qtyIdx = headerLower.indexWhere(
      (h) => h == 'qty' || h == 'days' || h == 'duration' || h == 'quantity',
    );
    final statusIdx = headerLower.indexOf('status');
    final amountIdx = headerLower.indexWhere(
      (h) => h.contains('amount') && !h.contains('paid') && !h.contains('remaining') && !h.contains('overtime') || h == 'total',
    );
    final payDateIdx = headerLower.indexWhere((h) => h.contains('payment date') || h.contains('pay date'));
    final paidAmountIdx = headerLower.indexWhere(
      (h) => h.contains('paid') && !h.contains('unpaid'),
    );
    final notesIdx = headerLower.indexOf('notes');
    // Validate required columns exist
    if (dateIdx == -1) throw Exception('CSV missing "Purchased Date" column');
    if (nameIdx == -1) {
      throw Exception(
        'CSV missing a name column (Description, Material, Worker Type, or Equipment)',
      );
    }
    // Resolve default project
    ProjectModel? defaultProject;
    if (selectedProjectId != null) {
      defaultProject = projects.cast<ProjectModel?>().firstWhere(
        (p) => p?.id == selectedProjectId,
        orElse: () => null,
      );
    }
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      final clean = v.toString().trim().replaceAll(RegExp(r'[^\d.\-]'), '');
      return double.tryParse(clean) ?? 0.0;
    }

    if (totalRows > 100) {
      throw Exception(
        'CSV file exceeds the maximum limit of 100 rows (Found $totalRows rows). Please reduce the number of entries and try again.',
      );
    }
    for (int i = 1; i < parsedCsv.length; i++) {
      final row = parsedCsv[i];
      if (row.isEmpty ||
          row.every((e) => e == null || e.toString().trim().isEmpty)) {
        continue;
      }
      final rowNum = i + 1;
      try {
        // ── Date ──
        final dateStr = dateIdx != -1 && dateIdx < row.length
            ? parseString(row[dateIdx])
            : '';
        DateTime date = DateTime.now();
        if (dateStr.isNotEmpty) {
          final parsed = DateTime.tryParse(dateStr);
          if (parsed != null) {
            date = parsed;
          } else {
            try {
              final parts = dateStr.split(RegExp(r'[/|-]'));
              if (parts.length == 3) {
                final d = int.tryParse(parts[0]);
                final m = int.tryParse(parts[1]);
                final y = int.tryParse(parts[2]);
                if (d != null && m != null && y != null) {
                  if (y > 31) date = DateTime(y, m, d);
                  else date = DateTime(d, m, y);
                }
              }
            } catch(e) {}
          }
        }
        // ── Project resolution ──
        final csvProjName = projectIdx != -1 && projectIdx < row.length
            ? parseString(row[projectIdx])
            : '';
        var matchedProject = projects.cast<ProjectModel?>().firstWhere(
          (p) =>
              p?.name.trim().toLowerCase() ==
                  csvProjName.trim().toLowerCase() ||
              p?.id == csvProjName,
          orElse: () => null,
        );
        matchedProject ??= defaultProject;
        if (matchedProject == null) {
          throw Exception('Row $rowNum: Project "$csvProjName" not found');
        }
        final projectId = matchedProject.id;
        // ── Floor ──
        final csvFloor = floorIdx != -1 && floorIdx < row.length
            ? parseString(row[floorIdx])
            : '';
        String? resolvedFloor;
        if (csvFloor.isNotEmpty) {
          resolvedFloor = csvFloor;
        } else if (matchedProject.floors != null &&
            matchedProject.floors!.isNotEmpty) {
          resolvedFloor = matchedProject.floors!.first;
        }
        // ── Phase ──
        final csvPhase = phaseIdx != -1 && phaseIdx < row.length
            ? parseString(row[phaseIdx])
            : '';
        String? phaseName;
        String? phaseId;
        if (csvPhase.isNotEmpty && matchedProject.selectedPhases != null) {
          final phaseMatch = matchedProject.selectedPhases!
              .cast<ProjectPhase?>()
              .firstWhere(
                (p) =>
                    p?.phaseName.trim().toLowerCase() ==
                    csvPhase.trim().toLowerCase(),
                orElse: () => null,
              );
          if (phaseMatch != null) {
            phaseName = phaseMatch.phaseName;
            phaseId = phaseMatch.id;
          } else {
            phaseName = csvPhase;
          }
        }
        // ── Activity ──
        final csvActivity = activityIdx != -1 && activityIdx < row.length
            ? parseString(row[activityIdx])
            : '';
        String? activityName;
        String? activityId;
        if (csvActivity.isNotEmpty && matchedProject.selectedPhases != null) {
          for (final phase in matchedProject.selectedPhases!) {
            if (phaseName != null &&
                phase.phaseName.trim().toLowerCase() !=
                    phaseName.trim().toLowerCase()) {
              continue;
            }
            final actMatch = phase.activities
                .cast<ProjectActivity?>()
                .firstWhere(
                  (a) =>
                      a?.name.trim().toLowerCase() ==
                      csvActivity.trim().toLowerCase(),
                  orElse: () => null,
                );
            if (actMatch != null) {
              activityName = actMatch.name;
              activityId = actMatch.id;
              if (phaseName == null) {
                phaseName = phase.phaseName;
                phaseId = phase.id;
              }
              break;
            }
          }
          activityName ??= csvActivity;
        }
        // ── Name / description ──
        final name = nameIdx != -1 && nameIdx < row.length
            ? parseString(row[nameIdx])
            : '';
        if (name.isEmpty) {
          throw Exception('Row $rowNum: Name/Description is empty');
        }
        // ── Type ──
        final typeStr = typeIdx != -1 && typeIdx < row.length
            ? parseString(row[typeIdx]).toLowerCase()
            : '';
        EntryType entryType;
        if (typeStr.contains('wage') ||
            typeStr.contains('labour') ||
            typeStr.contains('labor')) {
          entryType = EntryType.labour;
        } else if (typeStr.contains('expense') ||
            typeStr.contains('equipment')) {
          entryType = EntryType.equipment;
        } else {
          entryType = EntryType.material;
        }
        // ── Numeric fields ──
        final qty = qtyIdx != -1 && qtyIdx < row.length
            ? parseDouble(row[qtyIdx])
            : 0.0;
        final rate = rateIdx != -1 && rateIdx < row.length
            ? parseDouble(row[rateIdx])
            : 0.0;
        final brand = brandIdx != -1 && brandIdx < row.length
            ? parseString(row[brandIdx])
            : '';
        final unit = unitIdx != -1 && unitIdx < row.length
            ? parseString(row[unitIdx]).toLowerCase()
            : 'unit';
        final notes = notesIdx != -1 && notesIdx < row.length
            ? parseString(row[notesIdx])
            : '';
        // ── Payment status ──
        String resolvedStatus = 'Pending';
        if (statusIdx != -1 && statusIdx < row.length) {
          final statusStr = parseString(row[statusIdx]).trim().toLowerCase();
          if (statusStr == 'fully paid' ||
              statusStr == 'paid' ||
              statusStr == 'fullypaid') {
            resolvedStatus = 'Paid';
          } else if (statusStr == 'partial' || statusStr == 'partially paid') {
            resolvedStatus = 'Partial';
          }
        }
        double finalAmount = qty * rate;
        if (finalAmount == 0 && amountIdx != -1 && amountIdx < row.length) {
          finalAmount = parseDouble(row[amountIdx]);
        }

        double paidAmt;
        if (paidAmountIdx != -1 && paidAmountIdx < row.length) {
          final parsedPaid = parseDouble(row[paidAmountIdx]);
          if (parsedPaid > 0) {
            paidAmt = parsedPaid;
          } else if (resolvedStatus == 'Paid' || resolvedStatus == 'Fully Paid') {
            paidAmt = finalAmount;
          } else if (resolvedStatus == 'Partial') {
            paidAmt = finalAmount / 2;
          } else {
            paidAmt = 0.0;
          }
        } else {
          if (resolvedStatus == 'Paid' || resolvedStatus == 'Fully Paid') {
            paidAmt = finalAmount;
          } else if (resolvedStatus == 'Partial') {
            paidAmt = finalAmount / 2;
          } else {
            paidAmt = 0.0;
          }
        }

        final payDateStr = payDateIdx != -1 && payDateIdx < row.length
            ? parseString(row[payDateIdx])
            : '';
        
        DateTime? pDate;
        if (payDateStr.isNotEmpty) {
          try {
            // handle DD-MM-YYYY or ISO formats here if necessary, or just rely on the backend accepting ISO or trying simple parse.
            // Actually, backend might accept DD/MM/YYYY or YYYY-MM-DD. Since flutter formats it using _formatYmd which is dd/MM/yyyy typically, we'll let backend parse or we pass ISO.
            final parts = payDateStr.split(RegExp(r'[/|-]'));
            if (parts.length == 3) {
              final d = int.tryParse(parts[0]);
              final m = int.tryParse(parts[1]);
              final y = int.tryParse(parts[2]);
              if (d != null && m != null && y != null) {
                if (y > 31) {
                  pDate = DateTime(y, m, d);
                } else {
                  pDate = DateTime(d, m, y); // yy-mm-dd
                }
              }
            }
          } catch(e) {
            // Ignore parse errors, leave pDate null
          }
        }
        // ── Build payload ──
        final Map<String, dynamic> payload = {};
        if (entryType == EntryType.labour) {
          final normalizedUnit = (unit == 'day' || unit == 'days')
              ? 'day'
              : (unit == 'hour' || unit == 'hours')
              ? 'hour'
              : (unit == 'sqft' || unit == 'sq.ft')
              ? 'sqft'
              : 'unit';
          payload.addAll({
            'title': name,
            'type': 'Wages',
            'category': name,
            'quantity': qty,
            'rate': rate,
            'unit': normalizedUnit,
            'project': projectId,
            'date': date.toIso8601String(),
            'floor': resolvedFloor,
            'phase': ?phaseName,
            'phaseId': ?phaseId,
            'activity': ?activityName,
            'activityId': ?activityId,
            'amount': finalAmount,
            'remarks': notes,
            'notes': notes,
            'paymentStatus': resolvedStatus,
            'paidAmount': paidAmt,
            'paymentMode': 'Cash',
            if (pDate != null) 'paymentDate': pDate.toIso8601String(),
            'worker': name,
          });
          labourCount++;
        } else if (entryType == EntryType.equipment) {
          final normalizedUnit = (unit == 'day')
              ? 'day'
              : (unit == 'hour')
              ? 'hour'
              : (unit == 'trip' ||
                    unit == 'load' ||
                    unit == 'shift' ||
                    unit == 'truck')
              ? 'truck'
              : 'unit';
          payload.addAll({
            'title': name,
            'type': 'Expense',
            'category': name,
            'quantity': qty,
            'rate': rate,
            'unit': normalizedUnit,
            'project': projectId,
            'date': date.toIso8601String(),
            'floor': resolvedFloor,
            'phase': ?phaseName,
            'phaseId': ?phaseId,
            'activity': ?activityName,
            'activityId': ?activityId,
            'amount': finalAmount,
            'totalAmount': finalAmount,
            'brand': brand,
            'notes': notes,
            'paymentStatus': resolvedStatus,
            'paidAmount': paidAmt,
            'paymentMode': 'Cash',
            if (pDate != null) 'paymentDate': pDate.toIso8601String(),
          });
          equipmentCount++;
        } else {
          final normalizedUnit = (unit == 'bags' || unit == 'bag')
              ? 'bag'
              : (unit == 'sq.ft' || unit == 'sqft')
              ? 'sqft'
              : (unit == 'ton' || unit == 'tons')
              ? 'ton'
              : (unit == 'kg' || unit == 'kgs')
              ? 'kg'
              : 'unit';
          payload.addAll({
            'title': name,
            'type': 'Materials',
            'subType': 'Purchase',
            'materialType': 'purchase',
            'category': brand.isNotEmpty ? brand : name,
            'brand': brand.isEmpty ? null : brand,
            'quantity': qty,
            'rate': rate,
            'unit': normalizedUnit,
            'project': projectId,
            'notes': notes,
            'date': date.toIso8601String(),
            'floor': resolvedFloor,
            'phase': ?phaseName,
            'phaseId': ?phaseId,
            'activity': ?activityName,
            'activityId': ?activityId,
            'amount': finalAmount,
            'paymentStatus': resolvedStatus,
            'paidAmount': paidAmt,
            'paymentMode': 'Cash',
            if (pDate != null) 'paymentDate': pDate.toIso8601String(),
            if (resolvedFloor != null ||
                phaseName != null ||
                activityName != null)
              'executionContext': {
                'project': projectId,
                'floor': ?resolvedFloor,
                'phase': ?phaseName,
                'phaseId': ?phaseId,
                'activity': ?activityName,
                'activityId': ?activityId,
              },
          });
          materialCount++;
        }
        final success = await ApiService.addMaterial(payload);
        if (!success) {
          throw Exception(
            'Row $rowNum: Failed to create transaction on the server',
          );
        }
        successCount++;
      } catch (e) {
        failedCount++;
        errors.add(e.toString());
      }
    }
    return CsvImportResult(
      totalRows: totalRows,
      successCount: successCount,
      failedCount: failedCount,
      materialCount: materialCount,
      labourCount: labourCount,
      equipmentCount: equipmentCount,
      errors: errors,
    );
  }
}
