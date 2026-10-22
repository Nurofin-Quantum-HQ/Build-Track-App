import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/inventory_provider.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
class FulfillmentPaymentScreen extends StatefulWidget {
  const FulfillmentPaymentScreen({super.key});
  @override
  State<FulfillmentPaymentScreen> createState() =>
      _FulfillmentPaymentScreenState();
}
class _FulfillmentPaymentScreenState extends State<FulfillmentPaymentScreen> {
  bool _argsLoaded = false;
  late String _entryId;
  late String _projectId;
  late String _projectName;
  late String _itemName;
  late String _itemType;
  late double _quantity;
  late double _rate;
  late double _totalAmount;
  late double _alreadyPaid;
  late double _outstanding;
  late String? _phase;
  late String? _activity;
  late PaymentStatus _selectedStatus;
  String _selectedMethod = 'UPI';
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _amountError;
  String? _uploadedReceipt;
  String? _newReceiptDataUri;
  DateTime _selectedPaymentDate = DateTime.now();
  bool _isSaving = false;
  bool _requestEsign = false;
  final _clientEmailCtrl = TextEditingController();
  bool _isEsignPolling = false;
  bool _isEsignCompleted = false;
  String _esignStatusText = '';
  Future<void> _startEsignFlow() async {
    final amt = _parseAmount(_amountCtrl.text);
    if (amt == null || amt <= 0) {
      setState(() => _amountError = 'Please enter a valid amount before requesting an E-Signature.');
      return;
    }
    if (_clientEmailCtrl.text.isEmpty) {
      btToast(context, 'Please enter client email', error: true);
      return;
    }
    setState(() {
      _isEsignPolling = true;
      _esignStatusText = 'Sending request...';
    });
    final meta = {
      'projectName': _projectName,
      'itemName': _itemName,
      if (_phase != null && _phase!.isNotEmpty) 'phase': _phase,
      if (_activity != null && _activity!.isNotEmpty) 'activity': _activity,
      'type': _itemType,
      'totalAmount': _totalAmount,
      'alreadyPaid': _alreadyPaid,
      'amount': _parseAmount(_amountCtrl.text) ?? 0.0,
      'paymentMethod': _selectedMethod,
      'notes': _noteCtrl.text.trim(),
      'date': _selectedPaymentDate.toUtc().toIso8601String(),
    };
    final res = await ApiService.requestEsignature(_clientEmailCtrl.text.trim(), meta);
    if (res == null || res['requestId'] == null) {
      setState(() {
        _isEsignPolling = false;
        _esignStatusText = 'Failed to send request';
      });
      return;
    }
    setState(() {
      _esignStatusText = 'Waiting for client to sign...';
    });
    final reqId = res['requestId'];
    int attempts = 0;
    const maxAttempts = 60; // 3 minutes timeout (60 * 3s)
    while (_isEsignPolling && attempts < maxAttempts) {
      attempts++;
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || !_isEsignPolling) break;
      final statusRes = await ApiService.checkEsignatureStatus(reqId);
      if (statusRes != null && statusRes['status'] == 'signed') {
        if (mounted) {
          setState(() {
            _isEsignPolling = false;
            _isEsignCompleted = true;
            _newReceiptDataUri = statusRes['signatureData'];
            _uploadedReceipt = 'Signed_Receipt.jpg';
            _esignStatusText = 'Signature captured!';
          });
        }
        break;
      }
    }
    if (mounted && _isEsignPolling) {
      setState(() {
        _isEsignPolling = false;
        _esignStatusText = 'Signing timed out. You can retry or proceed.';
      });
    }
  }
  static const _pMethods = [
    {'label': 'UPI', 'icon': Icons.phone_android_outlined},
    {'label': 'Cash', 'icon': Icons.money_outlined},
    {'label': 'Bank Transfer', 'icon': Icons.account_balance_outlined},
    {'label': 'Card', 'icon': Icons.credit_card_outlined},
    {'label': 'Cheque', 'icon': Icons.description_outlined},
  ];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    _entryId = (args['id'] ?? args['entryId'] ?? args['_id'] ?? '').toString();
    _projectId = (args['projectId'] ?? args['project'] ?? '').toString();
    _projectName = (args['projectName'] ?? '').toString();
    _itemName =
        (args['itemName'] ?? args['name'] ?? args['title'] ?? 'Unknown Item')
            .toString();
    _itemType =
        (args['itemType'] ?? args['category'] ?? args['type'] ?? 'material')
            .toString();
    _quantity = (args['quantity'] as num?)?.toDouble() ?? 0.0;
    _rate = (args['rate'] as num?)?.toDouble() ?? 0.0;
    _totalAmount =
        (args['totalAmount'] as num?)?.toDouble() ??
        (args['billAmount'] as num?)?.toDouble() ??
        0.0;
    _alreadyPaid =
        (args['paidAmount'] as num?)?.toDouble() ??
        (args['alreadyPaid'] as num?)?.toDouble() ??
        0.0;
    _outstanding =
        (args['outstandingAmount'] as num?)?.toDouble() ??
        (_totalAmount - _alreadyPaid).clamp(0.0, double.infinity);
    _selectedStatus = _outstanding > 0
        ? (_alreadyPaid > 0 ? PaymentStatus.partial : PaymentStatus.pending)
        : PaymentStatus.paid;
    if (_selectedStatus == PaymentStatus.paid) {
      _amountCtrl.text = _outstanding.toStringAsFixed(0);
    } else if (_selectedStatus == PaymentStatus.pending) {
      _amountCtrl.text = '0';
    }
    _selectedMethod =
        args['paymentMethod']?.toString() ??
        args['paymentMode']?.toString() ??
        'UPI';
    if (!_pMethods.any((m) => m['label'] == _selectedMethod)) {
      if (_selectedMethod == 'Bank') {
        _selectedMethod = 'Bank Transfer';
      } else {
        _selectedMethod = 'UPI';
      }
    }
    // Every visit records a NEW payment, so it starts clean: callers pass the entry's
    // invoice attachment / the previous payment's receipt as args['receipt'], and that
    // used to show up here as this payment's proof.
    _noteCtrl.clear();
    _uploadedReceipt = null;
    _newReceiptDataUri = null;
    final txDetails = args['transactionDetails'] as Map?;
    _phase = (txDetails?['phase'] ?? txDetails?['phaseName'])?.toString();
    _activity = (txDetails?['activity'] ?? txDetails?['activityName'])?.toString();
  }
  @override
  void dispose() {
    _clientEmailCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }
  double? _parseAmount(String val) {
    if (val.isEmpty) return null;
    return double.tryParse(val);
  }
  Future<void> _handleConfirmPayment() async {
    setState(() {
      _amountError = null;
    });
    if (_selectedStatus != PaymentStatus.pending) {
      final raw = _amountCtrl.text.trim();
      final amt = _parseAmount(raw);
      if (raw.isEmpty || amt == null || amt <= 0) {
        setState(() {
          _amountError = 'Enter a valid amount paid';
        });
        return;
      }
      if (_outstanding > 0 && amt > _outstanding) {
        setState(() {
          _amountError = 'Payment amount cannot exceed the outstanding amount.';
        });
        return;
      }
      if (_outstanding <= 0) {
        setState(() {
          _amountError = 'No outstanding amount to pay';
        });
        return;
      }
    }
    final amount = _selectedStatus == PaymentStatus.paid
        ? _outstanding
        : _selectedStatus == PaymentStatus.pending
        ? 0.0
        : (_parseAmount(_amountCtrl.text.trim()) ?? 0.0);
    setState(() {
      _isSaving = true;
    });
    try {
      final totalPaid = _alreadyPaid + amount;
      final newStatusVal = _selectedStatus;
      final String newStatusStr = newStatusVal == PaymentStatus.paid
          ? 'Paid'
          : newStatusVal == PaymentStatus.partial
          ? 'Partial'
          : 'Pending';
      String apiPaymentMode = _selectedMethod;
      if (apiPaymentMode == 'Bank Transfer') {
        apiPaymentMode = 'Bank Transfer';
      }
      final payload = {
        'paymentStatus': newStatusStr,
        'paidAmount': totalPaid,
        'paymentMode': apiPaymentMode,
        // Only send remarks when given: an empty 'notes' overwrote the entry's own notes.
        if (_noteCtrl.text.trim().isNotEmpty) 'notes': _noteCtrl.text.trim(),
        'paymentDate': _selectedPaymentDate.toUtc().toIso8601String(),
        if (apiPaymentMode == 'Cash' && _requestEsign) 'requestEsign': true,
        if (apiPaymentMode == 'Cash' && _requestEsign) 'clientEmail': _clientEmailCtrl.text.trim(),
        if (amount > 0)
          'paymentEntry': {
            'amount': amount,
            'method': apiPaymentMode,
            'date': _selectedPaymentDate.toUtc().toIso8601String(),
            'notes': _noteCtrl.text.trim(),
            if (apiPaymentMode == 'Cash' && _requestEsign) 'requestEsign': true,
            if (apiPaymentMode == 'Cash' && _requestEsign) 'clientEmail': _clientEmailCtrl.text.trim(),
          },
        if (_newReceiptDataUri != null) 'paymentReceipt': _newReceiptDataUri,
      };
      final response = await ApiService.updateTransactionPayment(
        _entryId,
        payload,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          try {
            // Test parsing to differentiate flutter-side crashes
            jsonDecode(response.body);
            
            context.read<ProjectProvider>().load();
            context.read<InventoryProvider>().loadInventory(_projectId);
            await showBtSuccess(
              context,
              kind: BtSuccessKind.money,
              label: _itemName,
              title: amount > 0 ? 'Payment recorded' : 'Payment updated',
              message: amount > 0
                  ? '${formatCurrency(amount)} recorded via $_selectedMethod'
                  : 'Payment details updated successfully',
            );
            if (!mounted) return;
            Navigator.pop(context, true);
          } catch (e) {
            btToast(context, 'Server updated payment, but client failed to parse response: $e', error: true);
          }
        }
      } else {
        if (mounted) {
          String errMsg = 'Failed to update payment on server';
          if (response.statusCode == 400) {
            errMsg = 'Invalid payment data (400 Bad Request)';
          } else if (response.statusCode == 403) {
            errMsg = 'Permission denied to update payment (403)';
          } else if (response.statusCode >= 500) {
            errMsg = 'Server error (${response.statusCode}). Please try again later.';
          } else if (response.statusCode == 401) {
            errMsg = 'Session expired. Please log in again.';
          }
          
          try {
            final errorData = jsonDecode(response.body);
            if (errorData['message'] != null) {
               errMsg = errorData['message'];
            }
          } catch (_) {}

          btToast(context, errMsg, error: true);
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString() == 'Exception: Unauthorized') {
          // Handled by global interceptor, do not show another snackbar
          return;
        }
        btToast(context, 'Network or processing error: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedPaymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: Theme.of(c).colorScheme.copyWith(
            primary: Bt.ink,
            onPrimary: Bt.card,
            onSurface: Bt.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final now = DateTime.now();
      setState(() => _selectedPaymentDate = DateTime(
        picked.year, picked.month, picked.day,
        now.hour, now.minute, now.second,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    String helperText;
    if (_selectedStatus == PaymentStatus.paid) {
      helperText = 'Full settlement — ${formatCurrency(_outstanding)}';
    } else if (_selectedStatus == PaymentStatus.pending) {
      helperText = 'No payment recorded';
    } else {
      final entered = _parseAmount(_amountCtrl.text) ?? 0;
      final rem = (_outstanding - entered).clamp(0.0, double.infinity);
      helperText = rem > 0
          ? 'Remaining: ${formatCurrency(rem)}'
          : 'Full settlement via partial recording';
    }
    final bt = context.bt;
    final bool amountDisabled = _selectedStatus == PaymentStatus.pending;
    final bool hasProof = _uploadedReceipt != null && _uploadedReceipt!.isNotEmpty;

    final form = ListView(
      key: const ValueKey('payment-form'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        // ── what is being paid
        BtReveal(
          child: BtCard(
            variant: BtCardVariant.ink,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_itemType.toUpperCase(), style: BtText.mono(context, color: bt.accent)),
                      const SizedBox(height: 6),
                      Text(_itemName, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.d3(context, color: Bt.bone)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          _projectName.isNotEmpty ? _projectName : 'Project',
                          if (_quantity > 0 && _rate > 0)
                            '${_quantity % 1 == 0 ? _quantity.toInt() : _quantity} × ₹${_rate % 1 == 0 ? _rate.toInt() : _rate}',
                        ].join(' · '),
                        style: BtText.caption(context, color: Bt.onNoir2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('STILL DUE', style: BtText.mono(context, color: Bt.onNoir2)),
                    const SizedBox(height: 4),
                    BtCountUp(
                      value: _outstanding,
                      format: (v) => formatInr(v),
                      style: BtText.title(context, size: 20).copyWith(color: _outstanding > 0 ? Bt.amberBright : Bt.greenBright),
                    ),
                    Text('${formatInr(_alreadyPaid)} paid', style: BtText.caption(context, color: Bt.onNoir2)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ── status
        BtReveal(
          index: 1,
          child: BtSegmented<PaymentStatus>(
            segments: const {
              PaymentStatus.paid: 'Fully paid',
              PaymentStatus.partial: 'Partial',
              PaymentStatus.pending: 'Not paid',
            },
            value: _selectedStatus == PaymentStatus.overdue ? PaymentStatus.pending : _selectedStatus,
            onChanged: (v) => setState(() {
              _selectedStatus = v;
              _amountError = null;
              if (v == PaymentStatus.paid) {
                _amountCtrl.text = _outstanding.toStringAsFixed(0);
              } else if (v == PaymentStatus.partial) {
                if (_amountCtrl.text == '0' || _amountCtrl.text == _outstanding.toStringAsFixed(0)) {
                  _amountCtrl.clear();
                }
              } else {
                _amountCtrl.text = '0';
              }
            }),
          ),
        ),
        const SizedBox(height: 20),
        // ── big amount
        BtReveal(
          index: 2,
          child: BtField(
            label: 'Amount paid',
            error: _amountError,
            helper: helperText,
            child: AnimatedOpacity(
              opacity: amountDisabled ? 0.45 : 1.0,
              duration: Bt.fast,
              child: TextField(
                controller: _amountCtrl,
                enabled: !amountDisabled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) {
                  if (val.length > 1 &&
                      val.startsWith('0') &&
                      !val.startsWith('0.')) {
                    final stripped = val.replaceFirst(
                      RegExp(r'^0+'),
                      '',
                    );
                    if (stripped.isNotEmpty && stripped != '.') {
                      _amountCtrl.text = stripped;
                      _amountCtrl.selection = TextSelection.collapsed(
                        offset: stripped.length,
                      );
                      val = stripped;
                    }
                  }
                  setState(() {
                    _amountError = null;
                    final amt = _parseAmount(val);
                    if (amt == null || amt == 0) {
                      _selectedStatus = PaymentStatus.pending;
                    } else if (amt >= _outstanding) {
                      _selectedStatus = PaymentStatus.paid;
                    } else {
                      _selectedStatus = PaymentStatus.partial;
                    }
                  });
                },
                style: BtText.d1(context),
                cursorColor: bt.accent,
                decoration: btInput(context, hint: '0').copyWith(
                  hintStyle: BtText.d1(context, color: Bt.placeholder),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 18, right: 6),
                    child: Text('₹', style: BtText.d2(context, color: Bt.ink3)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  contentPadding: const EdgeInsets.fromLTRB(4, 18, 16, 18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Bt.rCard),
                    borderSide: BorderSide(color: _amountError != null ? Bt.red : Bt.inputBorder),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Bt.rCard),
                    borderSide: const BorderSide(color: Bt.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Bt.rCard),
                    borderSide: BorderSide(color: _amountError != null ? Bt.red : Bt.ink, width: 2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        // ── method tiles
        BtReveal(
          index: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('METHOD', style: BtText.mono(context)),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, c) {
                const gap = 8.0;
                final w = (c.maxWidth - gap * 2) / 3;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final m in _pMethods)
                      SizedBox(
                        width: w,
                        child: _MethodTile(
                          label: m['label'] as String,
                          icon: m['icon'] as IconData,
                          selected: _selectedMethod == m['label'],
                          onTap: () => setState(() => _selectedMethod = m['label'] as String),
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // ── date + remarks
        BtReveal(
          index: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BtGroup(children: [
                BtValueRow(
                  label: 'Payment date',
                  value: formatDate(_selectedPaymentDate),
                  onTap: _pickPaymentDate,
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18, color: Bt.ink3),
                ),
              ]),
              const SizedBox(height: 14),
              BtField(
                label: 'Remarks / reference number',
                optional: true,
                child: EntryNotesField(
                  controller: _noteCtrl,
                  hint: 'Transaction ID, cheque number, or remarks…',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // ── proof + e-sign
        BtReveal(
          index: 5,
          child: BtGroup(children: [
            if (hasProof)
              BtRow(
                leading: BtTile(icon: Icons.check_rounded, bg: Bt.greenSoft, fg: Bt.green),
                title: _uploadedReceipt!,
                subtitle: 'Payment proof attached',
                trailing: BtIconButton(
                  icon: Icons.close_rounded,
                  semantic: 'Remove receipt',
                  color: Bt.ink3,
                  onTap: () => setState(() {
                    _uploadedReceipt = null;
                    _newReceiptDataUri = null;
                  }),
                ),
              )
            else
              BtRow(
                leading: const BtTile(icon: Icons.upload_rounded),
                title: 'Payment proof',
                subtitle: 'Upload payment receipt · PNG, JPG, PDF',
                showChevron: true,
                onTap: () async {
                  final attachment = await pickAttachmentDirect(context);
                  if (attachment != null) {
                    setState(() {
                      _uploadedReceipt = attachment.name;
                      _newReceiptDataUri = attachment.dataUri;
                    });
                  }
                },
              ),
            if (_selectedMethod == 'Cash')
              BtRow(
                leading: BtTile(icon: Icons.draw_outlined, bg: bt.accentSoft, fg: bt.accentInk),
                title: 'E-sign cash receipt',
                subtitle: 'Request e-signature · client signs on their phone',
                subtitleMaxLines: 2,
                trailing: BtSwitch(
                  value: _requestEsign,
                  onChanged: (val) => setState(() => _requestEsign = val),
                ),
              ),
          ]),
        ),
        if (_selectedMethod == 'Cash' && _requestEsign) ...[
          const SizedBox(height: 12),
          AnimatedSize(
            duration: Bt.fast,
            curve: Bt.ease,
            child: BtCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BtField(
                    label: 'Client email',
                    child: TextField(
                      controller: _clientEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: BtText.body(context),
                      decoration: btInput(context, hint: 'Client email address', prefix: const Icon(Icons.email_outlined, color: Bt.ink3, size: 20)),
                    ),
                  ),
                  if (!_isEsignCompleted) ...[
                    const SizedBox(height: 12),
                    BtButton(
                      label: _isEsignPolling ? 'Cancel Polling' : 'Send for E-Signature',
                      icon: _isEsignPolling ? null : Icons.send_rounded,
                      variant: _isEsignPolling ? BtButtonVariant.destructive : BtButtonVariant.secondary,
                      small: true,
                      onPressed: _isEsignPolling ? () => setState(() => _isEsignPolling = false) : _startEsignFlow,
                    ),
                    if (_esignStatusText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(children: [
                          if (_isEsignPolling) ...[
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Bt.amber)),
                            const SizedBox(width: 8),
                          ] else ...[
                            const Icon(Icons.error_outline_rounded, size: 16, color: Bt.red),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              _esignStatusText,
                              style: BtText.subhead(context, weight: FontWeight.w500, color: _isEsignPolling ? Bt.amber : (_isEsignCompleted ? Bt.green : Bt.red)),
                            ),
                          ),
                        ]),
                      ),
                  ],
                  if (_isEsignCompleted) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: Bt.greenSoft, borderRadius: BorderRadius.circular(Bt.rTile)),
                      child: Row(children: [
                        const Icon(Icons.verified_rounded, color: Bt.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Signature successfully captured!', style: BtText.subhead(context, color: Bt.green, weight: FontWeight.w600))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: _isEsignPolling ? Bt.noir : Bt.ground,
      appBar: _isEsignPolling ? null : BtNavBar(title: 'Record payment', subtitle: _itemName),
      body: AnimatedSwitcher(
        duration: Bt.medium,
        switchInCurve: Bt.ease,
        switchOutCurve: Curves.easeIn,
        child: _isEsignPolling
            ? _EsignWaitingView(
                key: const ValueKey('esign-waiting'),
                email: _clientEmailCtrl.text.trim(),
                amount: _parseAmount(_amountCtrl.text) ?? 0,
                statusText: _esignStatusText,
                onStop: () => setState(() => _isEsignPolling = false),
              )
            : form,
      ),
      bottomNavigationBar: _isEsignPolling
          ? null
          : BtCtaBar(
              children: [
                Expanded(
                  child: BtButton(
                    label: 'Cancel',
                    variant: BtButtonVariant.secondary,
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: BtButton(
                    label: 'Confirm Payment',
                    icon: Icons.check_circle_outline,
                    loading: _isSaving,
                    onPressed: _isSaving ? null : _handleConfirmPayment,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Payment-method tile (Record-Payment board): icon over label, ink when selected.
class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: BtPressable(
        onTap: onTap,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: Bt.fast,
          curve: Bt.ease,
          height: 64,
          decoration: BoxDecoration(
            color: selected ? Bt.ink : Bt.card,
            borderRadius: BorderRadius.circular(Bt.rTile),
            border: Border.all(color: selected ? Bt.ink : Bt.inputBorder),
            boxShadow: selected ? Bt.shadow : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: selected ? context.bt.accent : Bt.ink2),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BtText.caption(context, color: selected ? Bt.bone : Bt.ink, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Noir "waiting for the client to sign" screen (Sign-Receipt board).
/// Only presentation: polling lives in the parent; [onStop] = the existing cancel-polling action.
class _EsignWaitingView extends StatelessWidget {
  const _EsignWaitingView({super.key, required this.email, required this.amount, required this.statusText, required this.onStop});
  final String email;
  final double amount;
  final String statusText;
  final VoidCallback onStop;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(builder: (context, c) => SingleChildScrollView(
      child: BtHero(
      overlap: 0,
      minHeight: c.maxHeight,
      padding: EdgeInsets.fromLTRB(Bt.gutter, top + 12, Bt.gutter, bottom + 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: (c.maxHeight - top - bottom - 28).clamp(0, double.infinity)),
        child: IntrinsicHeight(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Text('Cash receipt', style: BtText.navTitle(context).copyWith(color: Bt.bone))),
            const Spacer(),
            // phone mock with the receipt being signed
            BtReveal(
              child: Center(
                child: Container(
                  width: 190,
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                  decoration: BoxDecoration(
                    color: Bt.noir2,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: .12), width: 1.5),
                    boxShadow: [BoxShadow(color: bt.accent.withValues(alpha: .18), blurRadius: 40, spreadRadius: -8)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(widthFactor: .6, child: Container(height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(3)))),
                      const SizedBox(height: 8),
                      FractionallySizedBox(widthFactor: .85, child: Container(height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(3)))),
                      const SizedBox(height: 14),
                      Text(formatInr(amount), style: BtText.num(BtText.d3(context, color: Bt.bone))),
                      const SizedBox(height: 14),
                      Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: bt.accent, borderRadius: BorderRadius.circular(12)),
                        child: Text('Authorize and Sign', style: BtText.caption(context, color: bt.onAccent, weight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            BtReveal(
              index: 2,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const BtBrickLoader(onDark: true, scale: .5),
                      const SizedBox(width: 10),
                      Flexible(child: Text(statusText.toUpperCase(), textAlign: TextAlign.center, style: BtText.mono(context, color: bt.accent))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(email.isEmpty ? 'Sent to client' : 'Sent to $email', textAlign: TextAlign.center, style: BtText.d2(context, color: Bt.bone)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      "Keep this open — we'll pick up the signature the moment it's done.",
                      textAlign: TextAlign.center,
                      style: BtText.body(context, color: Bt.onNoir2),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            BtButton(label: 'Stop waiting', variant: BtButtonVariant.onDark, onPressed: onStop),
          ],
        )),
      ),
    )));
  }
}
