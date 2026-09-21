import os

filepath = r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\screen\reports\csv_import_helper.dart"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Replace the loop start and add allPayloads
old_loop_start = """    for (int i = 1; i < parsedCsv.length; i++) {
      final row = parsedCsv[i];
      if (row.isEmpty ||
          row.every((e) => e == null || e.toString().trim().isEmpty)) {
        continue;
      }
      final rowNum = i + 1;
      try {
        // -- Date --"""

new_loop_start = """    final List<Map<String, dynamic>> allPayloads = [];

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

        // -- Date --"""

content = content.replace(old_loop_start, new_loop_start)

# 2. Extract Payments (Before resolving project)
old_proj_res = """        // -- Project resolution --"""
new_proj_res = """        // Identify Payments
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
                 
                 DateTime payDate = date; // Default to main date
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
        
        // -- Project resolution --"""

content = content.replace(old_proj_res, new_proj_res)

# 3. Add to Payload
old_payload_init = """        final Map<String, dynamic> payload = {};"""
new_payload_init = """        final Map<String, dynamic> payload = {};
        if (tId != null) payload['_id'] = tId;
        if (payments.isNotEmpty) payload['paymentHistory'] = payments;"""

content = content.replace(old_payload_init, new_payload_init)

# 4. Modify End logic (Replacing addMaterial loop with allPayloads and bulkUpload logic)
old_end = """        final success = await ApiService.addMaterial(payload);
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
    return CsvImportResult("""

new_end = """        allPayloads.add(payload);
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

    return CsvImportResult("""

content = content.replace(old_end, new_end)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)
print("done")
