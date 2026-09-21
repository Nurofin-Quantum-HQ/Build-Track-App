import re

file_path = 'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/reports/csv_import_helper.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

new_logic = r'''
      // Identify Transaction ID
      final idIdx = headerLower.indexOf("transaction id");
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
         final amtIdx = headerLower.indexWhere((h) => h == "payment ${pIdx} amount");
         final dateIdxPay = headerLower.indexWhere((h) => h == "payment ${pIdx} date");
         final modeIdx = headerLower.indexWhere((h) => h == "payment ${pIdx} mode");
         
         if (amtIdx != -1 && amtIdx < row.length) {
            final amtVal = parseDouble(row[amtIdx]);
            if (amtVal > 0) {
               String pMode = "Cash";
               if (modeIdx != -1 && modeIdx < row.length) {
                   final mRaw = parseString(row[modeIdx]);
                   if (mRaw.isNotEmpty) pMode = mRaw;
               }
               
               DateTime payDate = DateTime.now();
               if (dateIdxPay != -1 && dateIdxPay < row.length) {
                   final dRaw = parseString(row[dateIdxPay]);
                   if (dRaw.isNotEmpty) {
                       final dp = DateTime.tryParse(dRaw);
                       if (dp != null) payDate = DateTime.utc(dp.year, dp.month, dp.day, 12, 0, 0);
                   }
               }
               
               payments.add({
                   "amount": amtVal,
                   "date": payDate.toIso8601String(),
                   "paymentMode": pMode,
               });
            }
         }
      }

      try {
        final dateStr = dateIdx != -1 && dateIdx < row.length ? parseString(row[dateIdx]) : "";
        DateTime date = DateTime.now();
        if (dateStr.isNotEmpty) {
          final parsed = DateTime.tryParse(dateStr);
          if (parsed != null) {
            date = DateTime.utc(parsed.year, parsed.month, parsed.day, 12, 0, 0);
          } else {
            try {
              final parts = dateStr.split(RegExp(r"[/|-]"));
              if (parts.length == 3) {
                final d = int.tryParse(parts[0]);
                final m = int.tryParse(parts[1]);
                final y = int.tryParse(parts[2]);
                if (d != null && m != null && y != null) {
                  if (y > 31) date = DateTime.utc(y, m, d, 12, 0, 0);
                  else date = DateTime.utc(d, m, y, 12, 0, 0);
                }
              }
            } catch(e) {}
          }
        }
        final csvProjName = projectIdx != -1 && projectIdx < row.length ? parseString(row[projectIdx]) : "";
        var matchedProject = projects.cast<ProjectModel?>().firstWhere(
          (p) => p?.name.trim().toLowerCase() == csvProjName.trim().toLowerCase() || p?.id == csvProjName,
          orElse: () => null,
        );
        matchedProject ??= defaultProject;
        if (matchedProject == null) {
          throw Exception("Row ${rowNum}: Project '${csvProjName}' not found");
        }
        final projectId = matchedProject.id;
        final csvFloor = floorIdx != -1 && floorIdx < row.length ? parseString(row[floorIdx]) : "";
        String? resolvedFloor;
        if (csvFloor.isNotEmpty) {
          resolvedFloor = csvFloor;
        } else if (matchedProject.floors != null && matchedProject.floors!.isNotEmpty) {
          resolvedFloor = matchedProject.floors!.first;
        }
        final csvPhase = phaseIdx != -1 && phaseIdx < row.length ? parseString(row[phaseIdx]) : "";
        String? phaseName;
        String? phaseId;
        if (csvPhase.isNotEmpty && matchedProject.selectedPhases != null) {
          final phaseMatch = matchedProject.selectedPhases!.cast<ProjectPhase?>().firstWhere(
                (p) => p?.phaseName.trim().toLowerCase() == csvPhase.trim().toLowerCase(),
                orElse: () => null,
              );
          if (phaseMatch != null) {
            phaseName = phaseMatch.phaseName;
            phaseId = phaseMatch.id;
          } else {
            phaseName = csvPhase;
          }
        }
        final csvActivity = activityIdx != -1 && activityIdx < row.length ? parseString(row[activityIdx]) : "";
        String? activityName;
        String? activityId;
        if (csvActivity.isNotEmpty && matchedProject.selectedPhases != null) {
          for (final phase in matchedProject.selectedPhases!) {
            if (phaseName != null && phase.phaseName.trim().toLowerCase() != phaseName.trim().toLowerCase()) {
              continue;
            }
            if (phase.activities == null) continue;
            final activityMatch = phase.activities!.cast<PhaseActivity?>().firstWhere(
                  (a) => a?.activityName.trim().toLowerCase() == csvActivity.trim().toLowerCase(),
                  orElse: () => null,
                );
            if (activityMatch != null) {
              activityName = activityMatch.activityName;
              activityId = activityMatch.id;
              break;
            }
          }
        }
        activityName ??= csvActivity.isNotEmpty ? csvActivity : null;
        final name = nameIdx != -1 && nameIdx < row.length ? parseString(row[nameIdx]) : "";
        if (name.isEmpty) {
          throw Exception("Row ${rowNum}: Name/Description is empty");
        }
        final typeStr = typeIdx != -1 && typeIdx < row.length ? parseString(row[typeIdx]).toLowerCase() : "";
        EntryType entryType;
        if (typeStr == "labour" || typeStr == "labor") {
          entryType = EntryType.labour;
        } else if (typeStr == "equipment") {
          entryType = EntryType.equipment;
        } else {
          entryType = EntryType.material;
        }
        final brand = brandIdx != -1 && brandIdx < row.length ? parseString(row[brandIdx]) : "";
        final qty = parseDouble(qtyIdx != -1 && qtyIdx < row.length ? row[qtyIdx] : "");
        final rate = parseDouble(rateIdx != -1 && rateIdx < row.length ? row[rateIdx] : "");
        final unit = unitIdx != -1 && unitIdx < row.length ? parseString(row[unitIdx]) : "";
        final statusStr = statusIdx != -1 && statusIdx < row.length ? parseString(row[statusIdx]).toLowerCase() : "";
        final csvAmount = parseDouble(amountIdx != -1 && amountIdx < row.length ? row[amountIdx] : "");
        double finalAmount = csvAmount;
        if (finalAmount == 0 && qty > 0 && rate > 0) {
          finalAmount = qty * rate;
        }
        final payDateStr = payDateIdx != -1 && payDateIdx < row.length ? parseString(row[payDateIdx]) : "";
        DateTime? pDate;
        if (payDateStr.isNotEmpty) {
          try {
            final parts = payDateStr.split(RegExp(r"[/|-]"));
            if (parts.length == 3) {
              final d = int.tryParse(parts[0]);
              final m = int.tryParse(parts[1]);
              final y = int.tryParse(parts[2]);
              if (d != null && m != null && y != null) {
                if (y > 31) pDate = DateTime.utc(y, m, d, 12, 0, 0);
                else pDate = DateTime.utc(d, m, y, 12, 0, 0);
              }
            } else {
              final parsed = DateTime.tryParse(payDateStr);
              if (parsed != null) pDate = DateTime.utc(parsed.year, parsed.month, parsed.day, 12, 0, 0);
            }
          } catch(e) {}
        }
        double paidAmt = parseDouble(paidAmountIdx != -1 && paidAmountIdx < row.length ? row[paidAmountIdx] : "");
        String resolvedStatus = "Pending";
        if (statusStr.contains("fully") || statusStr == "paid") {
          resolvedStatus = "Fully Paid";
          if (paidAmt == 0 && finalAmount > 0) {
            paidAmt = finalAmount;
          }
        } else if (statusStr.contains("partial")) {
          resolvedStatus = "Partial";
          if (paidAmt == 0 && finalAmount > 0) {
            paidAmt = finalAmount / 2;
          }
        } else if (statusStr.contains("not")) {
          resolvedStatus = "Not Paid";
          paidAmt = 0.0;
        } else {
          if (paidAmt > 0 && paidAmt >= finalAmount) {
            resolvedStatus = "Fully Paid";
          } else if (paidAmt > 0) {
            resolvedStatus = "Partial";
          } else {
            paidAmt = 0.0;
          }
        }
        final notes = notesIdx != -1 && notesIdx < row.length ? parseString(row[notesIdx]) : "";
        
        final payload = <String, dynamic>{};
        if (tId != null) payload["_id"] = tId;
        if (payments.isNotEmpty) payload["paymentHistory"] = payments;
        
        if (entryType == EntryType.labour) {
          payload.addAll({
            "title": name,
            "type": "Labour",
            "subType": "Labour",
            "workerType": name,
            "ratePerUnit": rate,
            "quantity": qty,
            "project": projectId,
            "notes": notes,
            "date": date.toIso8601String(),
            if (resolvedFloor != null) "floor": resolvedFloor,
            if (phaseName != null) "phase": phaseName,
            if (phaseId != null) "phaseId": phaseId,
            if (activityName != null) "activity": activityName,
            if (activityId != null) "activityId": activityId,
            "amount": finalAmount,
            "paymentStatus": resolvedStatus,
            "paidAmount": paidAmt,
            "paymentMode": "Cash",
            if (pDate != null) "paymentDate": pDate.toIso8601String(),
            if (resolvedFloor != null || phaseName != null || activityName != null)
              "executionContext": {
                "project": projectId,
                if (resolvedFloor != null) "floor": resolvedFloor,
                if (phaseName != null) "phase": phaseName,
                if (phaseId != null) "phaseId": phaseId,
                if (activityName != null) "activity": activityName,
                if (activityId != null) "activityId": activityId,
              },
          });
          labourCount++;
        } else if (entryType == EntryType.equipment) {
          payload.addAll({
            "title": name,
            "type": "Equipment",
            "subType": "Equipment",
            "equipmentName": name,
            "rate": rate,
            "duration": qty,
            "project": projectId,
            "notes": notes,
            "date": date.toIso8601String(),
            if (resolvedFloor != null) "floor": resolvedFloor,
            if (phaseName != null) "phase": phaseName,
            if (phaseId != null) "phaseId": phaseId,
            if (activityName != null) "activity": activityName,
            if (activityId != null) "activityId": activityId,
            "amount": finalAmount,
            "paymentStatus": resolvedStatus,
            "paidAmount": paidAmt,
            "paymentMode": "Cash",
            if (pDate != null) "paymentDate": pDate.toIso8601String(),
            if (resolvedFloor != null || phaseName != null || activityName != null)
              "executionContext": {
                "project": projectId,
                if (resolvedFloor != null) "floor": resolvedFloor,
                if (phaseName != null) "phase": phaseName,
                if (phaseId != null) "phaseId": phaseId,
                if (activityName != null) "activity": activityName,
                if (activityId != null) "activityId": activityId,
              },
          });
          equipmentCount++;
        } else {
          final normalizedUnit = (unit == "bag" || unit == "bags")
              ? "bag"
              : (unit == "cft")
              ? "cft"
              : (unit == "sqft")
              ? "sqft"
              : (unit == "ton" || unit == "tons")
              ? "ton"
              : (unit == "kg" || unit == "kgs")
              ? "kg"
              : "unit";
          payload.addAll({
            "title": name,
            "type": "Materials",
            "subType": "Purchase",
            "materialType": "purchase",
            "category": brand.isNotEmpty ? brand : name,
            "brand": brand.isEmpty ? null : brand,
            "quantity": qty,
            "rate": rate,
            "unit": normalizedUnit,
            "project": projectId,
            "notes": notes,
            "date": date.toIso8601String(),
            if (resolvedFloor != null) "floor": resolvedFloor,
            if (phaseName != null) "phase": phaseName,
            if (phaseId != null) "phaseId": phaseId,
            if (activityName != null) "activity": activityName,
            if (activityId != null) "activityId": activityId,
            "amount": finalAmount,
            "paymentStatus": resolvedStatus,
            "paidAmount": paidAmt,
            "paymentMode": "Cash",
            if (pDate != null) "paymentDate": pDate.toIso8601String(),
            if (resolvedFloor != null || phaseName != null || activityName != null)
              "executionContext": {
                "project": projectId,
                if (resolvedFloor != null) "floor": resolvedFloor,
                if (phaseName != null) "phase": phaseName,
                if (phaseId != null) "phaseId": phaseId,
                if (activityName != null) "activity": activityName,
                if (activityId != null) "activityId": activityId,
              },
          });
          materialCount++;
        }
        allPayloads.add(payload);
      } catch (e) {
        failedCount++;
        errors.add(e.toString());
      }
'''

pattern = re.compile(r'      try \{\s*// -- Date --.*?materialCount\+\+;\s*\}\s*final success = await ApiService\.addMaterial\(payload\);\s*if \(!success\) \{\s*throw Exception\(\s*\'Row \$rowNum: Failed to create transaction on the server\',\s*\);\s*\}\s*successCount\+\+;\s*\} catch \(e\) \{\s*failedCount\+\+;\s*errors\.add\(e\.toString\(\)\);\s*\}\s*\}\s*return CsvImportResult\(\s*totalRows: totalRows,\s*successCount: successCount,\s*failedCount: failedCount,\s*materialCount: materialCount,\s*labourCount: labourCount,\s*equipmentCount: equipmentCount,\s*errors: errors,\s*\);\s*\}\s*\}\s*', re.DOTALL)

end_logic = r'''
    final List<Map<String, dynamic>> createPayloads = [];
    final List<Map<String, dynamic>> updatePayloads = [];
    for (var p in allPayloads) {
       if (p.containsKey("_id") && p["_id"] != null && p["_id"].toString().isNotEmpty) {
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
                throw Exception("Bulk upload failed");
            }
        } catch(e) {
            for (var p in createPayloads) {
                try {
                    final successResult = await ApiService.addTransactionsBulk([p]);
                    if (successResult != null) {
                        successCount++;
                    } else {
                        failedCount++;
                        final title = p["title"] ?? "Unknown";
                        errors.add("Failed to create new transaction: ${title}");
                    }
                } catch(innerE) {
                    failedCount++;
                    final title = p["title"] ?? "Unknown";
                    errors.add("Error creating new transaction '${title}': ${innerE}");
                }
            }
        }
    }
    
    if (updatePayloads.isNotEmpty) {
        for (var p in updatePayloads) {
            try {
                final id = p["_id"].toString();
                final payloadWithoutId = Map<String, dynamic>.from(p)..remove("_id");
                final success = await ApiService.updateTransaction(id, payloadWithoutId);
                if (success) {
                    successCount++;
                } else {
                    failedCount++;
                    errors.add("Failed to update existing transaction ${id}");
                }
            } catch (e) {
                failedCount++;
                errors.add("Error updating existing transaction ${p['_id']}: ${e}");
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
'''

new_content = re.sub(pattern, "    final List<Map<String, dynamic>> allPayloads = [];\n" + new_logic + "    }\n" + end_logic, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
print("Replaced successfully")
