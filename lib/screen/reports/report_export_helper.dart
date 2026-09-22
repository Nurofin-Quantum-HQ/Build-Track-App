import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'save_helper_stub.dart'
    if (dart.library.html) 'save_helper_web.dart'
    if (dart.library.io) 'save_helper_mobile.dart';
class ReportExportHelper {
  static String _getPaymentStatusLabel(String status, {double? amount, double? paidAmount}) {
    if (amount != null && paidAmount != null && amount > 0) {
      if (paidAmount >= amount) return 'Fully Paid';
      if (paidAmount > 0) return 'Partial';
    }
    switch (status.toLowerCase().trim()) {
      case 'paid':
      case 'fully paid':
      case 'fullypaid':
        return 'Fully Paid';
      case 'partial':
      case 'partially paid':
      case 'partiallypaid':
      case 'partially':
      case 'partpaid':
        return 'Partial';
      case 'pending':
      case 'not paid':
      case 'notpaid':
      case 'unpaid':
      default:
        return 'Not Paid';
    }
  }
  static String _formatYmd(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  static String _formatIndianCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final decimal = parts[1];
    if (whole.length <= 3) {
      return 'Rs. $whole.$decimal';
    }
    final lastThree = whole.substring(whole.length - 3);
    final remaining = whole.substring(0, whole.length - 3);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = remaining.length - 1; i >= 0; i--) {
      if (count > 0 && count % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
      count++;
    }
    final formattedRemaining = buffer.toString().split('').reversed.join('');
    return 'Rs. $formattedRemaining,$lastThree.$decimal';
  }
  static List<String> getExportHeaders({
    required String quickCategoryTab,
    List<String>? activeColumns,
    List<EntryModel>? entries,
  }) {
    int maxPayments = 0;
    if (entries != null) {
      for (var entry in entries) {
        if (entry.paymentHistory.length > maxPayments) {
          maxPayments = entry.paymentHistory.length;
        }
      }
    }

    List<String> getPaymentColumns() {
      if (maxPayments == 0) return ['Payment Date', 'Payment Mode'];
      List<String> cols = [];
      for (int i = 1; i <= maxPayments; i++) {
        cols.addAll(['Payment $i Amount', 'Payment $i Date', 'Payment $i Mode']);
      }
      return cols;
    }

    List<String> headers = [];
    if (activeColumns != null) {
      headers = activeColumns.map((col) => col == 'Amount' ? 'Amount (INR)' : col).toList();
      if (!headers.contains('Transaction ID')) {
        headers.insert(0, 'Transaction ID');
      }
      if (!headers.contains('Action')) {
        headers.insert(1, 'Action');
      }
      int payIdx = headers.indexOf('Payment Date');
      if (payIdx != -1) {
        headers.removeAt(payIdx);
        headers.insertAll(payIdx, getPaymentColumns());
      }
      return headers;
    }
    
    switch (quickCategoryTab) {
      case 'Materials':
        headers = [
          'Transaction ID', 'Action', 'Purchased Date', 'Project', 'Material', 'Brand', 'Rate', 'Qty', 'Unit', 'Status', 'Amount (INR)', 'Payment Date',
        ];
        break;
      case 'Labour':
        headers = [
          'Transaction ID', 'Action', 'Purchased Date', 'Project', 'Worker Type', 'Rate/Day', 'Days', 'Status', 'Amount (INR)', 'Payment Date',
        ];
        break;
      case 'Equipment':
        headers = [
          'Transaction ID', 'Action', 'Purchased Date', 'Project', 'Equipment', 'Rent Rate', 'Duration', 'Status', 'Amount (INR)', 'Payment Date',
        ];
        break;
      default:
        headers = [
          'Transaction ID', 'Action', 'Purchased Date', 'Project', 'Type', 'Description', 'Brand', 'Floor', 'Phase', 'Activity', 'Unit', 'Status', 'Amount (INR)', 'Payment Date',
        ];
        break;
    }
    
    int payIdx = headers.indexOf('Payment Date');
    if (payIdx != -1) {
      headers.removeAt(payIdx);
      headers.insertAll(payIdx, getPaymentColumns());
    }
    
    return headers;
  }
  static Future<void> exportToCsv({
    required List<EntryModel> entries,
    required String Function(String) getProjectName,
    required String quickCategoryTab,
    List<String>? activeColumns,
    bool includePaymentHistory = true,
  }) async {
    if (entries.isEmpty) return;
    final csvBuffer = StringBuffer();

    int maxPayments = 0;
    if (includePaymentHistory) {
      for (var entry in entries) {
        if (entry.paymentHistory.length > maxPayments) {
          maxPayments = entry.paymentHistory.length;
        }
      }
    }

    final List<String> headers = getExportHeaders(
      quickCategoryTab: quickCategoryTab,
      activeColumns: activeColumns,
      entries: includePaymentHistory ? entries : null,
    );
    
    csvBuffer.writeln(
      headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','),
    );
    
    for (final entry in entries) {
      final dateStr = _formatYmd(entry.date);
      final projectName = getProjectName(entry.projectId);
      final amount = entry.amount;
      final status = _getPaymentStatusLabel(
        entry.paymentStatus,
        amount: entry.amount,
        paidAmount: entry.paidAmount,
      );
      final payDateStr = entry.paymentDate != null
          ? _formatYmd(entry.paymentDate!)
          : '';
          
      final List<String> rowValues = [];
      
      if (activeColumns != null) {
        if (!activeColumns.contains('Transaction ID')) {
          rowValues.add(entry.id);
        }
        if (!activeColumns.contains('Action')) {
          rowValues.add('');
        }
        for (final col in activeColumns) {
          if (col == 'Action') {
            rowValues.add('');
          } else if (col == 'Purchased Date') {
            rowValues.add(dateStr);
          } else if (col == 'Payment Date') {
            if (includePaymentHistory && maxPayments > 0) {
              for (int i = 0; i < maxPayments; i++) {
                if (i < entry.paymentHistory.length) {
                  final p = entry.paymentHistory[i];
                  rowValues.add(p['date']?.toString() ?? '');
                  rowValues.add((p['amount'] ?? 0.0).toString());
                  rowValues.add(p['method']?.toString() ?? p['mode']?.toString() ?? '');
                } else {
                  rowValues.addAll(['', '', '']);
                }
              }
            } else {
              rowValues.add(payDateStr);
              rowValues.add(entry.paymentMode ?? '');
            }
          } else if (col == 'Project') {
            rowValues.add(projectName);
          } else if (col == 'Type') {
            rowValues.add(entry.type.name.toUpperCase());
          } else if (col == 'Description' ||
              col == 'Material' ||
              col == 'Worker Type' ||
              col == 'Equipment') {
            rowValues.add(entry.description.isEmpty ? '' : entry.description);
          } else if (col == 'Brand') {
            rowValues.add(entry.brand ?? '');
          } else if (col == 'Floor') {
            rowValues.add(entry.floor ?? '');
          } else if (col == 'Phase') {
            rowValues.add(entry.phase ?? '');
          } else if (col == 'Activity') {
            rowValues.add(entry.activity ?? '');
          } else if (col == 'Unit') {
            rowValues.add(entry.unit ?? '');
          } else if (col == 'Status') {
            rowValues.add(status);
          } else if (col == 'Amount') {
            rowValues.add(amount.toStringAsFixed(2));
          } else if (col == 'Paid') {
            rowValues.add(entry.paidAmount.toStringAsFixed(2));
          } else if (col == 'Remaining') {
            rowValues.add(entry.remainingAmount.toStringAsFixed(2));
          } else if (col == 'Rate' || col == 'Rate/Day' || col == 'Rent Rate') {
            final rate = entry.ratePerUnit ?? 0.0;
            rowValues.add(rate.toStringAsFixed(2));
          } else if (col == 'Qty' || col == 'Days' || col == 'Duration') {
            if (entry.quantity != null && entry.quantity! > 0) {
              rowValues.add(entry.quantity!.toStringAsFixed(1));
            } else {
              final rate = entry.ratePerUnit;
              final val = (rate == null || rate == 0) ? null : entry.amount / rate;
              rowValues.add(val != null ? val.toStringAsFixed(1) : '');
            }
          } else if (col == 'Transaction ID') {
            rowValues.add(entry.id);
          }
        }
      } else {
        if (quickCategoryTab != 'All') {
          rowValues.add(entry.id); // Default headers add Transaction ID first
        } else {
          rowValues.add(entry.id);
        }
        
        rowValues.add(''); // Action column
        
        List<String> baseVals = [];
        
        if (quickCategoryTab == 'Materials') {
          final rate = entry.ratePerUnit;
          final qty = (rate == null || rate == 0) ? null : entry.amount / rate;
          baseVals = [
            dateStr,
            projectName,
            entry.description.isEmpty ? '' : entry.description,
            entry.brand ?? '',
            (entry.ratePerUnit ?? 0.0).toStringAsFixed(2),
            qty != null ? qty.toStringAsFixed(1) : '',
            entry.unit ?? 'unit',
            status,
            amount.toStringAsFixed(2),
          ];
        } else if (quickCategoryTab == 'Labour') {
          final rate = entry.ratePerUnit;
          final days = (rate == null || rate == 0) ? null : entry.amount / rate;
          baseVals = [
            dateStr,
            projectName,
            entry.description.isEmpty ? '' : entry.description,
            (entry.ratePerUnit ?? 0.0).toStringAsFixed(2),
            days != null ? days.toStringAsFixed(1) : '',
            status,
            amount.toStringAsFixed(2),
          ];
        } else if (quickCategoryTab == 'Equipment') {
          final rate = entry.ratePerUnit;
          final duration = (rate == null || rate == 0) ? null : entry.amount / rate;
          baseVals = [
            dateStr,
            projectName,
            entry.description.isEmpty ? '' : entry.description,
            (entry.ratePerUnit ?? 0.0).toStringAsFixed(2),
            duration != null ? duration.toStringAsFixed(1) : '',
            status,
            amount.toStringAsFixed(2),
          ];
        } else {
          baseVals = [
            dateStr,
            projectName,
            entry.type.name.toUpperCase(),
            entry.description.isEmpty ? '' : entry.description,
            entry.brand ?? '',
            entry.floor ?? '',
            entry.phase ?? '',
            entry.activity ?? '',
            entry.unit ?? '',
            status,
            amount.toStringAsFixed(2),
          ];
        }
        
        rowValues.addAll(baseVals);
        
        if (includePaymentHistory && maxPayments > 0) {
          for (int i = 0; i < maxPayments; i++) {
            if (i < entry.paymentHistory.length) {
              final p = entry.paymentHistory[i];
              rowValues.add((p['amount'] ?? 0.0).toString());
              rowValues.add(p['date']?.toString() ?? '');
              rowValues.add(p['mode']?.toString() ?? '');
            } else {
              rowValues.addAll(['', '', '']);
            }
          }
        } else {
          rowValues.add(payDateStr);
          rowValues.add(entry.paymentMode ?? '');
        }
      }
      
      final escapedRow = rowValues
          .map((val) => '"${val.replaceAll('"', '""')}"')
          .join(',');
      csvBuffer.writeln(escapedRow);
    }
    final filename =
        'BuildTrack_Report_${DateTime.now().millisecondsSinceEpoch}.csv';
    final shareText = 'BuildTrack Filtered Report (${entries.length} entries)';
    await saveAndShareCsv(
      csvContent: csvBuffer.toString(),
      filename: filename,
      shareText: shareText,
    );
  }
  static Future<void> exportToPdf({
    required List<EntryModel> entries,
    required String Function(String) getProjectName,
    required String title,
    required String filterSummary,
    required String quickCategoryTab,
    List<String>? activeColumns,
  }) async {
    final pdf = pw.Document();
    double materialTotal = 0;
    double labourTotal = 0;
    double equipmentTotal = 0;
    double grandTotal = 0;
    for (final entry in entries) {
      grandTotal += entry.amount;
      switch (entry.type) {
        case EntryType.material:
          materialTotal += entry.amount;
          break;
        case EntryType.labour:
          labourTotal += entry.amount;
          break;
        case EntryType.equipment:
          equipmentTotal += entry.amount;
          break;
      }
    }
    final List<String> pdfHeaders;
    final List<List<String>> pdfData;
    final Map<int, pw.Alignment> cellAlignmentsMap;
    final double headerFontSize;
    final double cellFontSize;
    if (activeColumns != null) {
      pdfHeaders = activeColumns
          .map((col) => col == 'Amount' ? 'Amount (INR)' : col)
          .toList();
      headerFontSize = 7;
      cellFontSize = 6;
      cellAlignmentsMap = {};
      for (int i = 0; i < activeColumns.length; i++) {
        final col = activeColumns[i];
        if (col == 'Purchased Date' ||
            col == 'Payment Date' ||
            col == 'Project' ||
            col == 'Description' ||
            col == 'Material' ||
            col == 'Worker Type' ||
            col == 'Equipment' ||
            col == 'Brand' ||
            col == 'Floor' ||
            col == 'Phase' ||
            col == 'Activity') {
          cellAlignmentsMap[i] = pw.Alignment.centerLeft;
        } else if (col == 'Type' || col == 'Unit' || col == 'Status') {
          cellAlignmentsMap[i] = pw.Alignment.center;
        } else if (col == 'Amount' ||
            col == 'Rate' ||
            col == 'Rate/Day' ||
            col == 'Rent Rate' ||
            col == 'Qty' ||
            col == 'Days' ||
            col == 'Duration') {
          cellAlignmentsMap[i] = pw.Alignment.centerRight;
        }
      }
      pdfData = entries.map((e) {
        final List<String> rowValues = [];
        for (final col in activeColumns) {
          if (col == 'Purchased Date') {
            rowValues.add(_formatYmd(e.date));
          } else if (col == 'Payment Date') {
            rowValues.add(
              e.paymentDate != null ? _formatYmd(e.paymentDate!) : '',
            );
          } else if (col == 'Project') {
            rowValues.add(getProjectName(e.projectId));
          } else if (col == 'Type') {
            rowValues.add(e.type.name.toUpperCase());
          } else if (col == 'Description' ||
              col == 'Material' ||
              col == 'Worker Type' ||
              col == 'Equipment') {
            rowValues.add(e.description.isEmpty ? '' : e.description);
          } else if (col == 'Brand') {
            rowValues.add(e.brand ?? '');
          } else if (col == 'Floor') {
            rowValues.add(e.floor ?? '');
          } else if (col == 'Phase') {
            rowValues.add(e.phase ?? '');
          } else if (col == 'Activity') {
            rowValues.add(e.activity ?? '');
          } else if (col == 'Unit') {
            rowValues.add(e.unit ?? '');
          } else if (col == 'Status') {
            rowValues.add(
              _getPaymentStatusLabel(
                e.paymentStatus,
                amount: e.amount,
                paidAmount: e.paidAmount,
              ),
            );
          } else if (col == 'Amount') {
            rowValues.add(_formatIndianCurrency(e.amount));
          } else if (col == 'Paid') {
            rowValues.add(_formatIndianCurrency(e.paidAmount));
          } else if (col == 'Remaining') {
            rowValues.add(_formatIndianCurrency(e.remainingAmount));
          } else if (col == 'Rate' || col == 'Rate/Day' || col == 'Rent Rate') {
            final rate = e.ratePerUnit ?? 0.0;
            rowValues.add(_formatIndianCurrency(rate));
          } else if (col == 'Qty' || col == 'Days' || col == 'Duration') {
            final rate = e.ratePerUnit;
            final val = (rate == null || rate == 0) ? null : e.amount / rate;
            rowValues.add(val != null ? val.toStringAsFixed(1) : '');
          }
        }
        return rowValues;
      }).toList();
    } else if (quickCategoryTab == 'Materials') {
      pdfHeaders = [
        'Purchased Date',
        'Project',
        'Material',
        'Brand',
        'Rate',
        'Qty',
        'Unit',
        'Status',
        'Amount (INR)',
        'Payment Date',
      ];
      headerFontSize = 8;
      cellFontSize = 7;
      cellAlignmentsMap = {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.center,
        7: pw.Alignment.center,
        8: pw.Alignment.centerRight,
        9: pw.Alignment.center,
      };
      pdfData = entries.map((e) {
        final rate = e.ratePerUnit;
        final qty = (rate == null || rate == 0) ? null : e.amount / rate;
        return [
          _formatYmd(e.date),
          getProjectName(e.projectId),
          e.description.isEmpty ? '' : e.description,
          e.brand ?? '',
          _formatIndianCurrency(rate ?? 0.0),
          qty != null ? qty.toStringAsFixed(1) : '',
          e.unit ?? 'unit',
          _getPaymentStatusLabel(
            e.paymentStatus,
            amount: e.amount,
            paidAmount: e.paidAmount,
          ),
          _formatIndianCurrency(e.amount),
          e.paymentDate != null ? _formatYmd(e.paymentDate!) : '',
        ];
      }).toList();
    } else if (quickCategoryTab == 'Labour') {
      pdfHeaders = [
        'Purchased Date',
        'Project',
        'Worker Type',
        'Rate/Day',
        'Days',
        'Status',
        'Amount (INR)',
        'Payment Date',
      ];
      headerFontSize = 8;
      cellFontSize = 7;
      cellAlignmentsMap = {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.center,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.center,
      };
      pdfData = entries.map((e) {
        final rate = e.ratePerUnit;
        final days = (rate == null || rate == 0) ? null : e.amount / rate;
        return [
          _formatYmd(e.date),
          getProjectName(e.projectId),
          e.description.isEmpty ? '' : e.description,
          _formatIndianCurrency(rate ?? 0.0),
          days != null ? days.toStringAsFixed(1) : '',
          _getPaymentStatusLabel(
            e.paymentStatus,
            amount: e.amount,
            paidAmount: e.paidAmount,
          ),
          _formatIndianCurrency(e.amount),
          e.paymentDate != null ? _formatYmd(e.paymentDate!) : '',
        ];
      }).toList();
    } else if (quickCategoryTab == 'Equipment') {
      pdfHeaders = [
        'Purchased Date',
        'Project',
        'Equipment',
        'Rent Rate',
        'Duration',
        'Status',
        'Amount (INR)',
        'Payment Date',
      ];
      headerFontSize = 8;
      cellFontSize = 7;
      cellAlignmentsMap = {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.center,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.center,
      };
      pdfData = entries.map((e) {
        final rate = e.ratePerUnit;
        final duration = (rate == null || rate == 0) ? null : e.amount / rate;
        return [
          _formatYmd(e.date),
          getProjectName(e.projectId),
          e.description.isEmpty ? '' : e.description,
          _formatIndianCurrency(rate ?? 0.0),
          duration != null ? duration.toStringAsFixed(1) : '',
          _getPaymentStatusLabel(
            e.paymentStatus,
            amount: e.amount,
            paidAmount: e.paidAmount,
          ),
          _formatIndianCurrency(e.amount),
          e.paymentDate != null ? _formatYmd(e.paymentDate!) : '',
        ];
      }).toList();
    } else {
      pdfHeaders = [
        'Purchased Date',
        'Project',
        'Type',
        'Description',
        'Brand',
        'Floor',
        'Phase',
        'Activity',
        'Unit',
        'Status',
        'Amount (INR)',
        'Payment Date',
      ];
      headerFontSize = 7;
      cellFontSize = 6;
      cellAlignmentsMap = {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerLeft,
        6: pw.Alignment.centerLeft,
        7: pw.Alignment.centerLeft,
        8: pw.Alignment.center,
        9: pw.Alignment.center,
        10: pw.Alignment.centerRight,
        11: pw.Alignment.center,
      };
      pdfData = entries.map((e) {
        return [
          _formatYmd(e.date),
          getProjectName(e.projectId),
          e.type.name.toUpperCase(),
          e.description.isEmpty ? '' : e.description,
          e.brand ?? '',
          e.floor ?? '',
          e.phase ?? '',
          e.activity ?? '',
          e.unit ?? '',
          _getPaymentStatusLabel(
            e.paymentStatus,
            amount: e.amount,
            paidAmount: e.paidAmount,
          ),
          _formatIndianCurrency(e.amount),
          e.paymentDate != null ? _formatYmd(e.paymentDate!) : '',
        ];
      }).toList();
    }
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BuildTrack Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#173EEA'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColor.fromHex('#6B7280'),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated on:',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      _formatDateTime(DateTime.now()),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 2, color: PdfColor.fromHex('#173EEA')),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F3F4F6'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    'Filters applied: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      filterSummary,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfSummaryCard(
                  'Material',
                  _formatIndianCurrency(materialTotal),
                  '#5B5FCF',
                ),
                _buildPdfSummaryCard(
                  'Labour',
                  _formatIndianCurrency(labourTotal),
                  '#B137FF',
                ),
                _buildPdfSummaryCard(
                  'Equipment',
                  _formatIndianCurrency(equipmentTotal),
                  '#67C8FF',
                ),
                _buildPdfSummaryCard(
                  'Total Cost',
                  _formatIndianCurrency(grandTotal),
                  '#173EEA',
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Report Logs',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1A1A2E'),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: pdfHeaders,
              data: pdfData,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: headerFontSize,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#173EEA'),
              ),
              cellStyle: pw.TextStyle(fontSize: cellFontSize),
              cellAlignments: cellAlignmentsMap,
            ),
          ];
        },
      ),
    );
    await Printing.layoutPdf(
      name: 'BuildTrack_Report_${_formatYmd(DateTime.now())}',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
  static pw.Widget _buildPdfSummaryCard(
    String title,
    String value,
    String colorHex,
  ) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex(colorHex),
            ),
          ),
        ],
      ),
    );
  }
}
