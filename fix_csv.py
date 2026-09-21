import os

content = """import 'dart:convert';
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

  static Future<CsvImportResult> importCsv({
    required EntryType entryType,
    required String projectId,
    required List<Project> allProjects,
  }) async {
    int successCount = 0;
    int failedCount = 0;
    int materialCount = 0;
    int labourCount = 0;
    int equipmentCount = 0;
    List<String> errors = [];

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return CsvImportResult(
        totalRows: 0,
        successCount: 0,
        failedCount: 0,
        materialCount: 0,
        labourCount: 0,
        equipmentCount: 0,
        errors: ['Import cancelled'],
      );
    }

    final fileBytes = result.files.first.bytes;
    String csvString;
    if (fileBytes != null) {
      csvString = utf8.decode(fileBytes);
    } else {
      final path = result.files.first.path;
      if (path != null) {
        final file = File(path);
        csvString = await file.readAsString();
      } else {
        throw Exception('Failed to read file content');
      }
    }

    final converter = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    );
    List<List<dynamic>> parsedCsv = converter.convert(csvString);

    if (parsedCsv.length < 2) {
      throw Exception('CSV file is empty or missing data rows');
    }

    final totalRows = parsedCsv.length - 1;
    if (totalRows > 100) {
      throw Exception(
        'CSV file exceeds the maximum limit of 100 rows. Please reduce entries and try again.',
      );
    }

    final headers = parsedCsv.first.map((h) => h.toString().trim()).toList();
    final headerLower = headers.map((h) => h.toLowerCase()).toList();

    final dateIdx = headerLower.indexWhere((h) => h == 'purchased date' || h == 'date');
    final projectIdx = headerLower.indexOf('project');
    final typeIdx = headerLower.indexOf('type');
    final nameIdx = headerLower.indexWhere((h) => h == 'description' || h == 'worker' || h == 'equipment' || h == 'name');
    final brandIdx = headerLower.indexOf('brand');
    final floorIdx = headerLower.indexOf('floor');
    final phaseIdx = headerLower.indexOf('phase');
    final activityIdx = headerLower.indexOf('activity');
    final unitIdx = headerLower.indexOf('unit');
    final rateIdx = headerLower.indexWhere((h) => h == 'rate' || h == 'rate/day' || h == 'rent rate');
    final qtyIdx = headerLower.indexWhere((h) => h == 'qty' || h == 'days' || h == 'duration' || h == 'quantity');
    final statusIdx = headerLower.indexOf('status');
    final amountIdx = headerLower.indexWhere((h) => h.contains('amount') && !h.contains('paid') && !h.contains('remaining') && !h.contains('overtime') || h == 'total');
    final payDateIdx = headerLower.indexWhere((h) => h.contains('payment date') || h.contains('pay date'));
    final paidAmountIdx = headerLower.indexWhere((h) => h.contains('paid') && !h.contains('unpaid'));
    final notesIdx = headerLower.indexOf('notes');

    if (dateIdx == -1) throw Exception('CSV missing "Purchased Date" column');

    String parseString(dynamic v) {
      if (v == null) return '';
      return v.toString().trim();
    }

    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      final clean = v.toString().trim().replaceAll(RegExp(r'[^\\d.\\-]'), '');
      return double.tryParse(clean) ?? 0.0;
    }

    final List<Map<String, dynamic>> allPayloads = [];

    for (int i = 1; i < parsedCsv.length; i++) {
      final row = parsedCsv[i];
      if (row.isEmpty || row.every((e) => e == null || e.toString().trim().isEmpty)) {
        continue;
      }
      final rowNum = i + 1;

      try {
        final idIdx = headerLower.indexWhere((h) => h.contains('transaction id'));
        String? tId;
        if (idIdx != -1 && idIdx < row.length) {
          final rawId = parseString(row[idIdx]).trim();
          if (rawId.isNotEmpty) {
             tId = rawId;
          }
        }

        final dateStr = dateIdx != -1 && dateIdx < row.length ? parseString(row[dateIdx]) : '';
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
                  date = (y > 31) ? DateTime(y, m, d) : DateTime(d, m, y);
                }
              }
            } catch (_) {}
          }
        }

        List<Map<String, dynamic>> payments = [];
        for (int pIdx = 1; pIdx <= 20; pIdx++) {
           final amtIdx = headerLower.indexWhere((h) => h == 'payment ${pIdx} amount');
           final dateIdxPay = headerLower.indexWhere((h) => h == 'payment ${pIdx} date');
           final modeIdx = headerLower.indexWhere((h) => h == 'payment ${pIdx} mode');
           
           if (amtIdx != -1 && amtIdx < row.length) {
              final amtVal = parseDouble(row[amtIdx]);
              if (amtVal > 0) {
                 String pMode = 'Cash';
                 if (modeIdx != -1 && modeIdx < row.length) {
                     final mRaw = parseString(row[modeIdx]);
                     if (mRaw.isNotEmpty) pMode = mRaw;
                 }
                 
                 DateTime payDate = date; // Default to entry date
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
                     'paymentMode': pMode,
                 });
              }
           }
        }

        String resolvedProjectId = projectId;
        if (projectIdx != -1 && projectIdx < row.length) {
          final pName = parseString(row[projectIdx]);
          if (pName.isNotEmpty) {
            final match = allProjects.where((p) => p.projectName.toLowerCase() == pName.toLowerCase());
            if (match.isNotEmpty) {
              resolvedProjectId = match.first.id;
            }
          }
        }

        final floorStr = floorIdx != -1 && floorIdx < row.length ? parseString(row[floorIdx]) : null;
        String? resolvedFloor = floorStr?.isNotEmpty == true ? floorStr : null;

        String? phaseName;
        String? phaseId;
        if (phaseIdx != -1 && phaseIdx < row.length) {
          final csvPhase = parseString(row[phaseIdx]);
          if (csvPhase.isNotEmpty) {
            final pProj = allProjects.firstWhere((p) => p.id == resolvedProjectId, orElse: () => Project(id: '', projectName: '', createdBy: '', phases: []));
            final matchedPhase = pProj.phases?.where((p) => p.name.toLowerCase() == csvPhase.toLowerCase());
            if (matchedPhase != null && matchedPhase.isNotEmpty) {
              phaseId = matchedPhase.first.id;
            }
            phaseName = csvPhase;
          }
        }

        String? activityName;
        String? activityId;
        if (activityIdx != -1 && activityIdx < row.length) {
          final csvActivity = parseString(row[activityIdx]);
          if (csvActivity.isNotEmpty) {
            final pProj = allProjects.firstWhere((p) => p.id == resolvedProjectId, orElse: () => Project(id: '', projectName: '', createdBy: '', phases: []));
            final matchedPhase = pProj.phases?.firstWhere((p) => p.id == phaseId, orElse: () => ProjectPhase(id: '', name: '', activities: []));
            if (matchedPhase != null) {
              final matchedAct = matchedPhase.activities?.where((a) => a.name.toLowerCase() == csvActivity.toLowerCase());
              if (matchedAct != null && matchedAct.isNotEmpty) {
                activityId = matchedAct.first.id;
              }
            }
            activityName = csvActivity;
          }
        }

        final qty = qtyIdx != -1 && qtyIdx < row.length ? parseDouble(row[qtyIdx]) : 0.0;
        final rate = rateIdx != -1 && rateIdx < row.length ? parseDouble(row[rateIdx]) : 0.0;
        final brand = brandIdx != -1 && brandIdx < row.length ? parseString(row[brandIdx]) : '';
        final unit = unitIdx != -1 && unitIdx < row.length ? parseString(row[unitIdx]).toLowerCase() : 'unit';
        final notes = notesIdx != -1 && notesIdx < row.length ? parseString(row[notesIdx]) : '';
        
        final name = nameIdx != -1 && nameIdx < row.length ? parseString(row[nameIdx]) : '';

        String resolvedStatus = 'Pending';
        if (statusIdx != -1 && statusIdx < row.length) {
          final statusStr = parseString(row[statusIdx]).trim().toLowerCase();
          if (statusStr == 'fully paid' || statusStr == 'paid' || statusStr == 'fullypaid') {
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
          } else if (resolvedStatus == 'Paid') {
            paidAmt = finalAmount;
          } else if (resolvedStatus == 'Partial') {
            paidAmt = finalAmount / 2;
          } else {
            paidAmt = 0.0;
          }
        } else {
          if (resolvedStatus == 'Paid') {
            paidAmt = finalAmount;
          } else if (resolvedStatus == 'Partial') {
            paidAmt = finalAmount / 2;
          } else {
            paidAmt = 0.0;
          }
        }

        final payDateStr = payDateIdx != -1 && payDateIdx < row.length ? parseString(row[payDateIdx]) : '';
        DateTime? pDate;
        if (payDateStr.isNotEmpty) {
          try {
            final parts = payDateStr.split(RegExp(r'[/|-]'));
            if (parts.length == 3) {
              final d = int.tryParse(parts[0]);
              final m = int.tryParse(parts[1]);
              final y = int.tryParse(parts[2]);
              if (d != null && m != null && y != null) {
                pDate = (y > 31) ? DateTime(y, m, d) : DateTime(d, m, y);
              }
            }
          } catch(e) {}
        }

        final Map<String, dynamic> payload = {};
        if (tId != null) payload['_id'] = tId;
        if (payments.isNotEmpty) payload['paymentHistory'] = payments;

        if (entryType == EntryType.labour) {
          final normalizedUnit = (unit == 'day' || unit == 'days') ? 'day' : (unit == 'hour' || unit == 'hours') ? 'hour' : (unit == 'sqft' || unit == 'sq.ft') ? 'sqft' : 'unit';
          payload.addAll({
            'title': name,
            'type': 'Wages',
            'category': name,
            'quantity': qty,
            'rate': rate,
            'unit': normalizedUnit,
            'project': resolvedProjectId,
            'date': date.toIso8601String(),
            if (resolvedFloor != null) 'floor': resolvedFloor,
            if (phaseName != null) 'phase': phaseName,
            if (phaseId != null) 'phaseId': phaseId,
            if (activityName != null) 'activity': activityName,
            if (activityId != null) 'activityId': activityId,
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
          final normalizedUnit = (unit == 'day') ? 'day' : (unit == 'hour') ? 'hour' : (unit == 'trip' || unit == 'load' || unit == 'shift' || unit == 'truck') ? 'truck' : 'unit';
          payload.addAll({
            'title': name,
            'type': 'Expense',
            'category': name,
            'quantity': qty,
            'rate': rate,
            'unit': normalizedUnit,
            'project': resolvedProjectId,
            'date': date.toIso8601String(),
            if (resolvedFloor != null) 'floor': resolvedFloor,
            if (phaseName != null) 'phase': phaseName,
            if (phaseId != null) 'phaseId': phaseId,
            if (activityName != null) 'activity': activityName,
            if (activityId != null) 'activityId': activityId,
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
          final normalizedUnit = (unit == 'bags' || unit == 'bag') ? 'bag' : (unit == 'sq.ft' || unit == 'sqft') ? 'sqft' : (unit == 'ton' || unit == 'tons') ? 'ton' : (unit == 'kg' || unit == 'kgs') ? 'kg' : 'unit';
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
            'project': resolvedProjectId,
            'notes': notes,
            'date': date.toIso8601String(),
            if (resolvedFloor != null) 'floor': resolvedFloor,
            if (phaseName != null) 'phase': phaseName,
            if (phaseId != null) 'phaseId': phaseId,
            if (activityName != null) 'activity': activityName,
            if (activityId != null) 'activityId': activityId,
            'amount': finalAmount,
            'paymentStatus': resolvedStatus,
            'paidAmount': paidAmt,
            'paymentMode': 'Cash',
            if (pDate != null) 'paymentDate': pDate.toIso8601String(),
            if (resolvedFloor != null || phaseName != null || activityName != null)
              'executionContext': {
                'project': resolvedProjectId,
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

    final List<Map<String, dynamic>> createPayloads = [];
    final List<Map<String, dynamic>> updatePayloads = [];
    for (var p in allPayloads) {
       if (p.containsKey('_id') && p['_id'] != null && p['_id'].toString().isNotEmpty) {
           updatePayloads.add(p);
       } else {
           createPayloads.add(p);
       }
    }

    if (createPayloads.isNotEmpty) {
        try {
            final res = await ApiService.addTransactionsBulk(createPayloads);
            if (res != null) {
                successCount += createPayloads.length; 
            } else {
                throw Exception('Bulk upload failed');
            }
        } catch(e) {
            for (var p in createPayloads) {
                try {
                    final successResult = await ApiService.addTransactionsBulk([p]);
                    if (successResult != null) {
                        successCount++;
                    } else {
                        failedCount++;
                        final title = p['title'] ?? 'Unknown';
                        errors.add('Failed to create new transaction: $title');
                    }
                } catch(innerE) {
                    failedCount++;
                    final title = p['title'] ?? 'Unknown';
                    errors.add('Error creating new transaction "$title": $innerE');
                }
            }
        }
    }

    if (updatePayloads.isNotEmpty) {
        for (var p in updatePayloads) {
            try {
                final id = p['_id'].toString();
                final payloadWithoutId = Map<String, dynamic>.from(p)..remove('_id');
                final success = await ApiService.updateTransaction(id, payloadWithoutId);
                if (success) {
                    successCount++;
                } else {
                    failedCount++;
                    errors.add('Failed to update existing transaction $id');
                }
            } catch (e) {
                failedCount++;
                errors.add('Error updating existing transaction ${p['_id']}: $e');
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
"""

with open(r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\screen\reports\csv_import_helper.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("done")
