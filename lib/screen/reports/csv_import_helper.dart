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
    final List<Map<String, dynamic>> allPayloads = [];

    for (int i = 1; i < parsedCsv.length; i++) {
      final row = parsedCsv[i];
      if (row.isEmpty ||
          row.every((e) => e == null || e.toString().trim().isEmpty)) {
        continue;
      }
      final rowNum = i + 1;
      try {
        // Identify Transaction ID
        final idIdx = headerLower.indexWhere((h) => h.contains('transaction id'));
        String? tId;
        if (idIdx != -1 && idIdx < row.length) {
          final rawId = parseString(row[idIdx]).trim();
          if (rawId.isNotEmpty) {
             tId = rawId;
          }
        }

        // Identify Payments
        List<Map<String, dynamic>> payments = [];
        for (int pIdx = 1; pIdx <= 20; pIdx++) {
           final amtIdx = headerLower.indexWhere((h) => h == 'payment $pIdx amount');
           final dateIdxPay = headerLower.indexWhere((h) => h == 'payment $pIdx date');
           final modeIdx = headerLower.indexWhere((h) => h == 'payment $pIdx mode');
           
           if (amtIdx != -1 && amtIdx < row.length) {
              final amtVal = parseDouble(row[amtIdx]);
              if (amtVal > 0) {
                 String pMode = 'UPI';
                 if (modeIdx != -1 && modeIdx < row.length) {
                     final mRaw = parseString(row[modeIdx]);
                     if (mRaw.isNotEmpty) pMode = mRaw;
                 }
                 
                 DateTime payDate = DateTime.now(); // Will update to main date below
                 if (dateIdxPay != -1 && dateIdxPay < row.length) {
                     final dRaw = parseString(row[dateIdxPay]);
                     if (dRaw.isNotEmpty) {
                         final dp = DateTime.tryParse(dRaw);
                         if (dp != null) {
                             payDate = DateTime.utc(dp.year, dp.month, dp.day, 12, 0, 0);
                         } else {
                            try {
                               final parts = dRaw.split(RegExp(r'[/|-]'));
                               if (parts.length == 3) {
                                  final d = int.tryParse(parts[0]);
                                  final m = int.tryParse(parts[1]);
                                  final y = int.tryParse(parts[2]);
                                  if (d != null && m != null && y != null) {
                                     payDate = (y > 31) ? DateTime.utc(y, m, d, 12, 0, 0) : DateTime.utc(d, m, y, 12, 0, 0);
                                  }
                               }
                            } catch(_) {}
                         }
                     }
                 }
                 
                 payments.add({
                     'amount': amtVal,
                     'date': payDate.toIso8601String(),
                     'method': pMode,
                 });
              }
           }
        }

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
                  if (y > 31) {
                     date = DateTime(y, m, d);
                  } else if (d > 31) {
                     date = DateTime(d, m, y);
                  }
                }
              }
            } catch(e) {}
          }
        }
        
        // Update payments with main date if they didn't specify one
        final nowStr = DateTime.now().toIso8601String().substring(0, 10);
        for (var p in payments) {
           if (p['date'].toString().startsWith(nowStr)) {
               p['date'] = date.toIso8601String();
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
        // Action column
        final actionIdx = headerLower.indexWhere((h) => h == 'action' || h == 'row action status' || h == 'changed');
        String actionVal = '';
        if (actionIdx != -1 && actionIdx < row.length) {
            actionVal = parseString(row[actionIdx]).toUpperCase();
        }
        
        final String localDateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        // ── Build payload ──
        final Map<String, dynamic> payload = {};
        if (tId != null) payload['transactionId'] = tId;
        if (actionIdx != -1 && actionVal.isNotEmpty) payload['rowStatus'] = actionVal;
        if (payments.isNotEmpty) payload['paymentHistory'] = payments;
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
            'date': localDateStr,
            'floor': resolvedFloor,
            'phase': phaseName,
            'phaseId': phaseId,
            'activity': activityName,
            'activityId': activityId,
            'amount': finalAmount,
            'remarks': notes,
            'notes': notes,
            'paymentStatus': resolvedStatus,
            'paidAmount': paidAmt,
            'paymentMode': 'UPI',
            if (pDate != null) 'paymentDate': '${pDate.year}-${pDate.month.toString().padLeft(2, '0')}-${pDate.day.toString().padLeft(2, '0')}',
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
            'date': localDateStr,
            'floor': resolvedFloor,
            'phase': phaseName,
            'phaseId': phaseId,
            'activity': activityName,
            'activityId': activityId,
            'amount': finalAmount,
            'totalAmount': finalAmount,
            'brand': brand,
            'notes': notes,
            'paymentStatus': resolvedStatus,
            'paidAmount': paidAmt,
            'paymentMode': 'UPI',
            if (pDate != null) 'paymentDate': '${pDate.year}-${pDate.month.toString().padLeft(2, '0')}-${pDate.day.toString().padLeft(2, '0')}',
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
            'date': localDateStr,
            'floor': resolvedFloor,
            'phase': phaseName,
            'phaseId': phaseId,
            'activity': activityName,
            'activityId': activityId,
            'amount': finalAmount,
            'paymentStatus': resolvedStatus,
            'paidAmount': paidAmt,
            'paymentMode': 'UPI',
            if (pDate != null) 'paymentDate': '${pDate.year}-${pDate.month.toString().padLeft(2, '0')}-${pDate.day.toString().padLeft(2, '0')}',
            if (resolvedFloor != null ||
                phaseName != null ||
                activityName != null)
              'executionContext': {
                'project': projectId,
                if (resolvedFloor != null) 'floor': resolvedFloor,
                if (phaseName != null) 'phase': phaseName,
                if (phaseId != null) 'phaseId': phaseId,
                if (activityName != null) 'activity': activityName,
                if (activityId != null) 'activityId': activityId,
              },
          });
          materialCount++;
        }
        allPayloads.add(payload);
      } catch (e) {
        failedCount++;
        errors.add(e.toString());
      }
    }
    
    try {
        await ApiService.backupCsv();
    } catch(e) {}
    
    if (allPayloads.isNotEmpty) {
        try {
            final res = await ApiService.addTransactionsBulk(allPayloads);
            if (res != null) {
                final results = res['results'] as Map<String, dynamic>?;
                if (results != null) {
                    successCount += ((results['created'] ?? 0) as num).toInt();
                    successCount += ((results['updated'] ?? 0) as num).toInt();
                    failedCount += ((results['failedCount'] ?? 0) as num).toInt();
                    final skips = ((results['unchangedSkipped'] ?? 0) as num).toInt();
                    
                    final failures = results['failures'] as List<dynamic>? ?? [];
                    for (var f in failures) {
                        final title = f['title'] ?? 'Unknown';
                        final reason = f['reason'] ?? f['error'] ?? 'Unknown error';
                        errors.add('Row error ($title): $reason');
                    }
                } else {
                    successCount += allPayloads.length;
                }
            } else {
                throw Exception('Bulk upload failed');
            }
        } catch(e) {
            // fallback to individual creates/updates
            for (var p in allPayloads) {
                try {
                    if (p.containsKey('_id') && p['_id'] != null && p['_id'].toString().isNotEmpty) {
                        final id = p['_id'].toString();
                        final payloadWithoutId = Map<String, dynamic>.from(p)..remove('_id');
                        final success = await ApiService.updateTransaction(id, payloadWithoutId);
                        if (success) {
                            successCount++;
                        } else {
                            failedCount++;
                            errors.add('Failed to update transaction: $id');
                        }
                    } else {
                        final successResult = await ApiService.addTransactionsBulk([p]);
                        if (successResult != null) {
                            successCount++;
                        } else {
                            failedCount++;
                            final title = p['title'] ?? 'Unknown';
                            errors.add('Failed to create new transaction: $title');
                        }
                    }
                } catch(innerE) {
                    failedCount++;
                    final title = p['title'] ?? 'Unknown';
                    errors.add('Error processing transaction "$title": $innerE');
                }
            }
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
