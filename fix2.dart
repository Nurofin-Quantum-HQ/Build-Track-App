import 'dart:io';

void main() {
  final file = File('lib/screen/reports/csv_import_helper.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst('for (int i = 1; i < parsedCsv.length; i++) {', 
    'final List<Map<String, dynamic>> allPayloads = [];\n    for (int i = 1; i < parsedCsv.length; i++) {');

  final oldStart = '''      final rowNum = i + 1;
      try {
        // -- Date --''';
        
  final newStart = '''      final rowNum = i + 1;
      
      // Identify Transaction ID
      final idIdx = headerLower.indexWhere((h) => h.contains('transaction id'));
      String? tId;
      if (idIdx != -1 && idIdx < row.length) {
        final rawId = row[idIdx]?.toString().trim() ?? '';
        if (rawId.isNotEmpty) {
           tId = rawId;
        }
      }

      // Identify Payments
      List<Map<String, dynamic>> payments = [];
      for (int pIdx = 1; pIdx <= 20; pIdx++) {
         final amtIdx = headerLower.indexWhere((h) => h == 'payment \$pIdx amount');
         final dateIdxPay = headerLower.indexWhere((h) => h == 'payment \$pIdx date');
         final modeIdx = headerLower.indexWhere((h) => h == 'payment \$pIdx mode');
         
         if (amtIdx != -1 && amtIdx < row.length) {
            final amtRaw = row[amtIdx]?.toString() ?? '';
            final amtVal = double.tryParse(amtRaw) ?? 0.0;
            if (amtVal > 0) {
               String pMode = 'Cash';
               if (modeIdx != -1 && modeIdx < row.length) {
                   final mRaw = row[modeIdx]?.toString() ?? '';
                   if (mRaw.isNotEmpty) pMode = mRaw;
               }
               
               DateTime payDate = DateTime.now();
               if (dateIdxPay != -1 && dateIdxPay < row.length) {
                   final dRaw = row[dateIdxPay]?.toString() ?? '';
                   if (dRaw.isNotEmpty) {
                       final dp = DateTime.tryParse(dRaw);
                       if (dp != null) payDate = DateTime.utc(dp.year, dp.month, dp.day, 12, 0, 0);
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

      try {
        // -- Date --''';

  content = content.replaceFirst(oldStart, newStart);
  
  final oldPayload = '''        final payload = <String, dynamic>{};''';
  final newPayload = '''        final payload = <String, dynamic>{};
        if (tId != null) payload['_id'] = tId;
        if (payments.isNotEmpty) payload['paymentHistory'] = payments;''';
        
  content = content.replaceAll(oldPayload, newPayload);

  final oldEnd = '''        }
        final success = await ApiService.addMaterial(payload);
        if (!success) {
          throw Exception(
            \\'Row \$rowNum: Failed to create transaction on the server\\',
          );
        }
        successCount++;
      } catch (e) {
        failedCount++;
        errors.add(e.toString());
      }
    }
    return CsvImportResult('''.replaceAll('\\\\', '');
    
  final newEnd = '''        }
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
                        errors.add('Failed to create new transaction: \$title');
                    }
                } catch(innerE) {
                    failedCount++;
                    final title = p['title'] ?? 'Unknown';
                    errors.add('Error creating new transaction "\$title": \$innerE');
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
                    errors.add('Failed to update existing transaction \$id');
                }
            } catch (e) {
                failedCount++;
                errors.add('Error updating existing transaction \${p['_id']}: \$e');
            }
        }
    }

    return CsvImportResult(''';

  content = content.replaceFirst(oldEnd, newEnd);
  
  file.writeAsStringSync(content);
}
