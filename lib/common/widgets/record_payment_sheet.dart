import 'dart:convert';

import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:buildtrack_mobile/config/api_config.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Category a "Money Out" entry is saved under. The server rejects negative
/// amounts, so money out is a positive `Expense` tagged with this category: it
/// counts in the project's cost and stays out of `totalIncome`.
const String kMoneyOutCategory = 'Money Out';

/// Image provider for a stored proof (https URL, server-relative path or data URI).
ImageProvider? proofImageProvider(String? src) {
  if (src == null || src.isEmpty) return null;
  if (src.startsWith('/')) return NetworkImage('${ApiConfig.baseUrl.replaceAll('/api', '')}$src');
  return getProfileImageProvider(src);
}

/// Project chooser used when the sheet is opened without a fixed project.
Future<String?> _pickPaymentProject(BuildContext context, String? current) {
  final projects = context.read<ProjectProvider>().projects;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Bt.ground,
    barrierColor: Bt.scrim,
    sheetAnimationStyle: btSheetStyle(context),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BtSheetHeader(title: 'Choose a project'),
        Flexible(
          child: projects.isEmpty
              ? const Padding(padding: EdgeInsets.fromLTRB(18, 8, 18, 32), child: BtEmpty(icon: Icons.folder_open_outlined, title: 'No projects yet'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: BtGroup(children: [
                    for (final p in projects)
                      BtRow(
                        leading: const BtTile(icon: Icons.apartment_rounded, size: 36),
                        title: p.name,
                        subtitle: p.location.isNotEmpty ? p.location : null,
                        trailing: p.id == current ? const Icon(Icons.check_rounded, color: Bt.green) : null,
                        onTap: () => Navigator.pop(ctx, p.id),
                      ),
                  ]),
                ),
        ),
      ],
    ),
  );
}

/// New loans must carry `loan_received`. If the create response already says
/// so there is nothing to do; otherwise PATCH /transactions/:id/ledger-category
/// (Admin or View finances). Returns a message when it could not be done.
Future<String?> _ensureLoanCategory(Map<String, dynamic>? created) async {
  const failed = 'Saved, but it could not be marked as a loan. Change its category in Reports.';
  if (created == null) return failed;
  if (created['offline'] == true) return 'Saved offline. Mark it as a loan in Reports once it syncs.';
  Map<String, dynamic> tx = created;
  for (final k in const ['transaction', 'data']) {
    if (created[k] is Map) {
      tx = Map<String, dynamic>.from(created[k] as Map);
      break;
    }
  }
  if (tx['ledgerCategory']?.toString() == 'loan_received') return null;
  final id = (tx['_id'] ?? tx['id'])?.toString() ?? '';
  if (id.isEmpty) return failed;
  try {
    final res = await ApiService.patch('/transactions/$id/ledger-category', {'ledgerCategory': 'loan_received'});
    return res.statusCode == 200 ? null : failed;
  } catch (e) {
    if (kDebugMode) debugPrint('PATCH ledger-category error: $e');
    return failed;
  }
}

/// "Record payment" sheet: money in from the client or a loan (and, as before,
/// money out). Pass [projectId] to fix the project; leave it null to show a
/// project picker (prefilled with [initialProjectId]). [editingTx] edits an
/// existing entry. Returns true when something was saved; [onSaved] runs after
/// the success overlay.
Future<bool> showRecordPaymentSheet(
  BuildContext context, {
  String? projectId,
  VoidCallback? onSaved,
  String? initialProjectId,
  Map<String, dynamic>? editingTx,
}) async {
  final titleCtrl = TextEditingController(
    text: editingTx?['title']?.toString() ?? '',
  );
  final double initialAmt =
      double.tryParse(editingTx?['amount']?.toString() ?? '') ?? 0.0;
  final amountCtrl = TextEditingController(
    text: initialAmt != 0.0 ? initialAmt.abs().toString() : '',
  );
  final notesCtrl = TextEditingController(
    text: editingTx?['notes']?.toString() ?? '',
  );
  String selectedMode =
      editingTx?['paymentMode']?.toString() ?? 'Bank Transfer';
  DateTime selectedDate = DateTime.now();
  if (editingTx?['date'] != null) {
    try {
      selectedDate = DateTime.parse(editingTx!['date'].toString()).toLocal();
    } catch (_) {}
  }
  PickedImage? pickedImage;
  // The entry's uploaded image (kept unless replaced / removed). Only known
  // when the row carries `attachments` (see _withProof).
  final bool knowsAttachments = editingTx?['attachments'] is List;
  final List<dynamic> attachments = knowsAttachments ? editingTx!['attachments'] as List : const [];
  String? existingImageUrl = attachments.map((a) => a?.toString() ?? '').firstWhere((a) => a.isNotEmpty, orElse: () => '');
  if (existingImageUrl.isEmpty) existingImageUrl = null;
  // Cash e-signature already on the entry (shown, not editable here).
  final String? existingSignatureUrl = (editingTx?['paymentReceipt']?.toString().isNotEmpty ?? false) ? editingTx!['paymentReceipt'].toString() : null;
  bool isInflow = editingTx != null ? initialAmt >= 0 : true;
  // Which project the money belongs to. When the caller did not fix one, the
  // sheet opens with a project picker (prefilled with `initialProjectId`).
  final bool askProject = projectId == null && editingTx == null;
  String? pickedProjectId = projectId ?? initialProjectId;
  if (askProject && !context.read<ProjectProvider>().projects.any((p) => p.id == pickedProjectId)) {
    pickedProjectId = null;
  }
  // "From: Client / Loan" for new money-in entries. Writing the ledger
  // category needs Admin or View finances, so everyone else only ever records
  // client payments (no category is sent for them).
  final bool canChooseSource = editingTx == null && RoleManager.canViewFinances;
  String fromKind = 'client';
  bool saved = false;
  // Sheet state lives OUT here, not inside the sheet builder: the modal
  // route re-runs its builder whenever MediaQuery changes (e.g. the keyboard
  // opening), which used to reset `requestEsign` to false and recreate the
  // email controller — so tapping the client email box made it vanish.
  bool isSaving = false;
  bool isEsignPolling = false;
  bool isEsignCompleted = false;
  String esignStatusText = '';
  bool requestEsign = false;
  final clientEmailCtrl = TextEditingController();
  String? newReceiptDataUri;
  bool sheetOpen = true;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Bt.ground,
    barrierColor: Bt.scrim,
    sheetAnimationStyle: btSheetStyle(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
    ),
    builder: (ctx) {
      Future<void> startEsignFlow(StateSetter setSheet) async {
        // No setState on a closed sheet (polling can outlive it).
        void ss(VoidCallback f) => sheetOpen ? setSheet(f) : f();
        final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
        if (amt <= 0) {
          btToast(context, 'Please enter a valid amount before requesting an E-Signature', error: true);
          return;
        }
        if (clientEmailCtrl.text.isEmpty) {
          btToast(context, 'Please enter client email', error: true);
          return;
        }
        ss(() {
          isEsignPolling = true;
          esignStatusText = 'Sending request...';
        });
        final meta = {
          'projectName': 'BuildTrack Revenue',
          'type': titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Revenue',
          'amount': amt,
          'paymentMethod': selectedMode,
          'notes': notesCtrl.text.trim(),
          'date': selectedDate.toIso8601String(),
        };
        final res = await ApiService.requestEsignature(clientEmailCtrl.text.trim(), meta);
        if (res == null || res['requestId'] == null) {
          ss(() {
            isEsignPolling = false;
            esignStatusText = 'Failed to send request';
          });
          return;
        }
        ss(() {
          esignStatusText = 'Waiting for client to sign...';
        });
        final reqId = res['requestId'];
        while (isEsignPolling && sheetOpen) {
          await Future.delayed(const Duration(seconds: 3));
          if (!isEsignPolling || !sheetOpen) break;
          final statusRes = await ApiService.checkEsignatureStatus(reqId);
          if (statusRes != null && statusRes['status'] == 'signed') {
            ss(() {
              isEsignPolling = false;
              isEsignCompleted = true;
              newReceiptDataUri = statusRes['signatureData'];
              esignStatusText = 'Signature captured!';
            });
            break;
          }
        }
      }
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          Widget preview(Widget child) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 80,
                    width: 120,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Bt.fill),
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
                  ),
                ),
              );
          const brokenImage = Center(child: Icon(Icons.broken_image_outlined, color: Bt.ink3));
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BtSheetHeader(
                  title: editingTx != null
                      ? (isInflow ? 'Edit Revenue Inflow' : 'Edit Revenue Outflow')
                      : (isInflow ? 'Record Revenue Inflow' : 'Record Revenue Outflow'),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MoneyDirectionToggle(
                          isInflow: isInflow,
                          onChanged: (v) => setModalState(() {
                            isInflow = v;
                          }),
                        ),
                        const SizedBox(height: 16),
                        if (askProject) ...[
                          BtField(
                            label: 'Project',
                            child: BtPickerField(
                              leading: Icons.apartment_rounded,
                              text: pickedProjectId == null
                                  ? 'Choose a project'
                                  : context.read<ProjectProvider>().projects.firstWhere((p) => p.id == pickedProjectId).name,
                              placeholder: pickedProjectId == null,
                              onTap: () async {
                                final id = await _pickPaymentProject(ctx, pickedProjectId);
                                if (id != null) setModalState(() => pickedProjectId = id);
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (canChooseSource && isInflow) ...[
                          BtField(
                            label: 'From',
                            child: BtSegmented<String>(
                              segments: const {'client': 'Client', 'loan': 'Loan'},
                              value: fromKind,
                              onChanged: (v) => setModalState(() => fromKind = v),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        BtField(
                          label: 'Payment title / milestone',
                          child: TextField(
                            controller: titleCtrl,
                            textCapitalization: TextCapitalization.sentences,
                            style: BtText.body(context),
                            decoration: btInput(context, hint: 'e.g. Milestone 1 Payment, Advance Payment'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        BtField(
                          label: isInflow ? 'Amount received (₹)' : 'Amount sent (₹)',
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: TextInputType.number,
                            style: BtText.amount(context, size: 24),
                            decoration: btInput(context, hint: 'e.g. 500000', prefixText: '₹  '),
                          ),
                        ),
                        const SizedBox(height: 14),
                        BtField(
                          label: 'Payment mode',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final mode in const ['UPI', 'Bank Transfer', 'Cash', 'Cheque'])
                                BtChip(
                                  label: mode,
                                  selected: selectedMode == mode,
                                  onTap: () => setModalState(() {
                                    selectedMode = mode;
                                  }),
                                ),
                            ],
                          ),
                        ),
                        if (selectedMode == 'Cash') ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                            decoration: BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(Bt.rInput), border: Border.all(color: Bt.inputBorder)),
                            child: Row(children: [
                              const Icon(Icons.draw_outlined, size: 20, color: Bt.ink2),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Request E-Signature for Cash Receipt', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
                              BtSwitch(value: requestEsign, onChanged: (val) => setModalState(() => requestEsign = val)),
                            ]),
                          ),
                          if (requestEsign) ...[
                            const SizedBox(height: 10),
                            BtField(
                              label: 'Client email address',
                              child: TextField(
                                controller: clientEmailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                textInputAction: TextInputAction.done,
                                scrollPadding: const EdgeInsets.only(bottom: 120),
                                style: BtText.body(context),
                                decoration: btInput(context, hint: 'client@email.com', prefix: const Icon(Icons.email_outlined, color: Bt.ink3)),
                              ),
                            ),
                          ],
                          if (requestEsign && !isEsignCompleted) ...[
                            const SizedBox(height: 10),
                            BtButton(
                              label: isEsignPolling ? 'Cancel Polling' : 'Send for E-Signature',
                              icon: isEsignPolling ? Icons.close_rounded : Icons.send_rounded,
                              small: true,
                              variant: isEsignPolling ? BtButtonVariant.destructive : BtButtonVariant.secondary,
                              onPressed: isEsignPolling
                                  ? () {
                                      setModalState(() => isEsignPolling = false);
                                    }
                                  : () => startEsignFlow(setModalState),
                            ),
                            if (esignStatusText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(children: [
                                  if (isEsignPolling) ...[
                                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Bt.amber)),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      esignStatusText,
                                      style: BtText.subhead(context, weight: FontWeight.w600, color: isEsignPolling ? Bt.amber : (isEsignCompleted ? Bt.green : Bt.red)),
                                    ),
                                  ),
                                ]),
                              ),
                          ],
                          if (isEsignCompleted) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Bt.greenSoft, borderRadius: BorderRadius.circular(Bt.rTile)),
                              child: Row(children: [
                                const Icon(Icons.check_circle, color: Bt.green),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Signature successfully captured!', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.green))),
                              ]),
                            ),
                          ],
                        ],
                        const SizedBox(height: 14),
                        BtField(
                          label: 'Date received',
                          child: BtPickerField(
                            leading: Icons.calendar_today_outlined,
                            icon: Icons.chevron_right_rounded,
                            text: '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                final now = DateTime.now();
                                setModalState(() {
                                  selectedDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    now.hour,
                                    now.minute,
                                    now.second,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        BtField(
                          label: 'Notes / remarks',
                          optional: true,
                          child: TextField(
                            controller: notesCtrl,
                            textCapitalization: TextCapitalization.sentences,
                            style: BtText.body(context),
                            decoration: btInput(
                              context,
                              hint: isInflow
                                  ? 'e.g. Initial payment received for start of work'
                                  : 'e.g. Refund sent for milestone delay',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Semantics(
                          button: true,
                          label: 'Upload receipt proof',
                          child: BtPressable(
                            onTap: () async {
                              final img = await pickImageFromGallery(context);
                              if (img != null) {
                                setModalState(() {
                                  pickedImage = img;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                              decoration: BoxDecoration(
                                color: Bt.card,
                                borderRadius: BorderRadius.circular(Bt.rInput),
                                border: Border.all(color: Bt.inputBorder, width: 1.2),
                              ),
                              child: Row(children: [
                                const BtTile(icon: Icons.image_outlined, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Upload receipt proof', style: BtText.body(context, weight: FontWeight.w600)),
                                    Text('Optional', style: BtText.caption(context)),
                                  ]),
                                ),
                                if (pickedImage != null) ...[
                                  Text('Selected', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.green)),
                                  _ClearButton(onTap: () => setModalState(() {
                                        pickedImage = null;
                                      })),
                                ] else if (newReceiptDataUri != null) ...[
                                  Text('E-Signature', style: BtText.subhead(context, weight: FontWeight.w600, color: context.bt.accentInk)),
                                  _ClearButton(onTap: () => setModalState(() {
                                        newReceiptDataUri = null;
                                      })),
                                ] else if (existingImageUrl != null) ...[
                                  Text('Current image', style: BtText.subhead(context, weight: FontWeight.w600, color: context.bt.accentInk)),
                                  _ClearButton(onTap: () => setModalState(() {
                                        existingImageUrl = null;
                                      })),
                                ] else if (existingSignatureUrl != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text('E-Signature', style: BtText.subhead(context, weight: FontWeight.w600, color: context.bt.accentInk)),
                                  ),
                                ] else
                                  const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.chevron_right_rounded, color: Bt.placeholder)),
                              ]),
                            ),
                          ),
                        ),
                        if (pickedImage != null)
                          preview(
                            FutureBuilder<Uint8List>(
                              future: pickedImage!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                }
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              },
                            ),
                          )
                        else if (newReceiptDataUri != null)
                          preview(
                            Image.memory(
                              base64Decode(newReceiptDataUri!.split(',').last),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => brokenImage,
                            ),
                          )
                        else if ((existingImageUrl ?? existingSignatureUrl) != null && proofImageProvider(existingImageUrl ?? existingSignatureUrl) != null)
                          preview(
                            Image(
                              image: proofImageProvider(existingImageUrl ?? existingSignatureUrl)!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                              },
                              errorBuilder: (context, error, stackTrace) => brokenImage,
                            ),
                          ),
                        const SizedBox(height: 22),
                        BtButton(
                          label: editingTx != null ? 'Save Changes' : 'Save',
                          loading: isSaving,
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final isLoan = canChooseSource && isInflow && fromKind == 'loan';
                                  var title = titleCtrl.text.trim();
                                  if (title.isEmpty && isLoan) title = 'Loan received';
                                  if (pickedProjectId == null || pickedProjectId!.isEmpty) {
                                    btToast(context, 'Please choose a project', error: true);
                                    return;
                                  }
                                  var amount =
                                      double.tryParse(amountCtrl.text.trim()) ??
                                      0.0;
                                  amount = amount.abs();
                                  if (title.isEmpty) {
                                    btToast(context, 'Please enter a payment title', error: true);
                                    return;
                                  }
                                  if (amount <= 0) {
                                    btToast(context, 'Please enter a valid amount', error: true);
                                    return;
                                  }
                                  setModalState(() {
                                    isSaving = true;
                                  });
                                  try {
                                    String? base64Image;
                                    if (pickedImage != null) {
                                      final bytes = await pickedImage!
                                          .readAsBytes();
                                      base64Image =
                                          'data:image/jpeg;base64,${base64Encode(bytes)}';
                                    }
                                    final payload = {
                                      'title': title,
                                      // Always a positive amount (the server rejects
                                      // negatives); money out = a "Money Out" Expense.
                                      'type': isInflow ? 'Income' : 'Expense',
                                      'category': isInflow ? '' : kMoneyOutCategory,
                                      'project': pickedProjectId,
                                      'amount': amount,
                                      'date': selectedDate.toIso8601String(),
                                      'paymentStatus': 'Paid',
                                      'paymentMode': selectedMode,
                                      'paidAmount': amount,
                                      'notes': notesCtrl.text.trim().isEmpty && isLoan ? 'Loan received' : notesCtrl.text.trim(),
                                      if (canChooseSource && isInflow) 'ledgerCategory': isLoan ? 'loan_received' : 'client_payment',
                                      if (newReceiptDataUri != null) 'paymentReceipt': newReceiptDataUri,
                                      if (newReceiptDataUri != null) 'receiptImage': newReceiptDataUri,
                                      if (base64Image != null) 'receiptImage': base64Image,
                                      // Only send `attachments` when we know the real list —
                                      // otherwise the server keeps what it has (never wipe it).
                                      if (base64Image == null && newReceiptDataUri == null && editingTx != null && knowsAttachments)
                                        'attachments': existingImageUrl != null
                                            ? [existingImageUrl]
                                            : [],
                                    };
                                    final bool isEdit = editingTx != null;
                                    final bool success;
                                    Map<String, dynamic>? created;
                                    if (isEdit) {
                                      final txId =
                                          editingTx['_id']?.toString() ??
                                          editingTx['id']?.toString() ??
                                          '';
                                      success = await ApiService.updateTransaction(
                                        txId,
                                        payload,
                                      );
                                    } else {
                                      final result =
                                          await ApiService.addTransaction(payload);
                                      created = result;
                                      success = result != null;
                                    }
                                    if (success) {
                                      saved = true;
                                      // The create route may or may not keep `ledgerCategory`;
                                      // make sure a loan really is one.
                                      final String? loanWarning = (!isEdit && isLoan) ? await _ensureLoanCategory(created) : null;
                                      if (context.mounted) {
                                        Navigator.pop(ctx);
                                        await showBtSuccess(
                                          context,
                                          kind: BtSuccessKind.money,
                                          title: isEdit ? 'Revenue updated' : (isLoan ? 'Loan recorded' : 'Revenue recorded'),
                                          message: isEdit
                                              ? 'Revenue updated successfully'
                                              : (isLoan ? 'Loan recorded successfully' : 'Revenue recorded successfully'),
                                          label: '${isLoan ? 'Loan received' : (isInflow ? 'Money in' : 'Money out')} · ${formatInr(amount.abs())}',
                                        );
                                        if (!context.mounted) return;
                                        context.read<ProjectProvider>().load();
                                        if (loanWarning != null) btToast(context, loanWarning, error: true);
                                        onSaved?.call();
                                      }
                                    } else {
                                      if (context.mounted) {
                                        btToast(
                                          context,
                                          isEdit
                                              ? 'Failed to update revenue'
                                              : 'Failed to record revenue',
                                          error: true,
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      btToast(context, 'Error: $e', error: true);
                                    }
                                  } finally {
                                    if (ctx.mounted) {
                                      setModalState(() {
                                        isSaving = false;
                                      });
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    sheetOpen = false;
    isEsignPolling = false;
  });
  return saved;
}

/// Money in / Money out switch (Record-Money board).
class _MoneyDirectionToggle extends StatelessWidget {
  const _MoneyDirectionToggle({required this.isInflow, required this.onChanged});
  final bool isInflow;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    Widget seg(bool inflow) {
      final on = inflow == isInflow;
      final bg = on ? (inflow ? Bt.green : Bt.red) : Colors.transparent;
      final fg = on ? Colors.white : Bt.ink2;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: BtPressable(
            onTap: () => onChanged(inflow),
            child: AnimatedContainer(
              duration: Bt.fast,
              curve: Bt.ease,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(inflow ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(inflow ? 'Money In' : 'Money Out', style: BtText.button(context, size: 15, color: fg)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [seg(true), const SizedBox(width: 4), seg(false)]),
    );
  }
}

/// Small "×" used to clear a receipt / signature / image in the money sheet.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Remove',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.cancel, color: Bt.red, size: 20)),
      ),
    );
  }
}
