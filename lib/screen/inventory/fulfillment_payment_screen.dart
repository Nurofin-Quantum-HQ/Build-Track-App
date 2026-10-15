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
  late String? _existingReceipt;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter client email')));
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
  static const Color _kDark = Color(0xFF101828);
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
    _existingReceipt = (args['receipt'] ?? args['screenshotUrl']) as String?;
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
    _noteCtrl.text = (args['notes'] ?? args['remarks'] ?? '').toString();
    _uploadedReceipt = _existingReceipt;
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
        'notes': _noteCtrl.text.trim(),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  amount > 0
                      ? '${formatCurrency(amount)} recorded via $_selectedMethod'
                      : 'Payment details updated successfully',
                ),
                backgroundColor: const Color(0xFF067647),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            Navigator.pop(context, true);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Server updated payment, but client failed to parse response: $e'),
                backgroundColor: Colors.orange.withValues(alpha: 0.8),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errMsg),
              backgroundColor: Colors.red.withValues(alpha: 0.8),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString() == 'Exception: Unauthorized') {
          // Handled by global interceptor, do not show another snackbar
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network or processing error: $e'),
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: const BtNavBar(title: 'Record payment'),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          BtCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BtTypeTile(type: _itemType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_itemName, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.headline(context)),
                      Text(
                        [
                          _projectName.isNotEmpty ? _projectName : 'Project',
                          if (_quantity > 0 && _rate > 0)
                            '${_quantity % 1 == 0 ? _quantity.toInt() : _quantity} × ₹${_rate % 1 == 0 ? _rate.toInt() : _rate}',
                        ].join(' · '),
                        style: BtText.caption(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Still due', style: BtText.caption(context)),
                    Text(formatInr(_outstanding), style: BtText.num(BtText.headline(context).copyWith(color: _outstanding > 0 ? Bt.amber : Bt.green))),
                    Text('${formatInr(_alreadyPaid)} paid', style: BtText.caption(context)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          EntryLabeled(
            label: 'Payment status',
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
          EntryLabeled(
            label: 'Amount paid',
            child: AnimatedOpacity(
              opacity: amountDisabled ? 0.45 : 1.0,
              duration: const Duration(milliseconds: 180),
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
                style: BtText.num(BtText.amount(context, size: 28)),
                decoration: btInput(context, hint: '0', prefixText: '₹ ', errorText: _amountError).copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
          ),
          if (_amountError == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(helperText, style: BtText.caption(context)),
            ),
          const SizedBox(height: 24),
          EntryLabeled(
            label: 'Method',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _pMethods)
                  BtChip(
                    label: m['label'] as String,
                    icon: m['icon'] as IconData,
                    selected: _selectedMethod == m['label'],
                    onTap: () => setState(() => _selectedMethod = m['label'] as String),
                  ),
              ],
            ),
          ),
          if (_selectedMethod == 'Cash') ...[
            const SizedBox(height: 16),
            BtCard(
              padding: const EdgeInsets.fromLTRB(12, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    title: Text('Request e-signature for cash receipt', style: BtText.body(context)),
                    value: _requestEsign,
                    onChanged: (val) => setState(() => _requestEsign = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: bt.brand,
                  ),
                  if (_requestEsign)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: TextField(
                        controller: _clientEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: BtText.body(context),
                        decoration: btInput(context, hint: 'Client email address', prefix: const Icon(Icons.email_outlined, color: Bt.ink3, size: 20)),
                      ),
                    ),
                  if (_requestEsign && !_isEsignCompleted) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: BtButton(
                        label: _isEsignPolling ? 'Cancel Polling' : 'Send for E-Signature',
                        variant: _isEsignPolling ? BtButtonVariant.destructive : BtButtonVariant.secondary,
                        small: true,
                        onPressed: _isEsignPolling ? () => setState(() => _isEsignPolling = false) : _startEsignFlow,
                      ),
                    ),
                    if (_esignStatusText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 0, 0),
                        child: Row(children: [
                          if (_isEsignPolling) ...[
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Bt.amber)),
                            const SizedBox(width: 8),
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
                  if (_isEsignCompleted)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded, color: Bt.green, size: 18),
                        const SizedBox(width: 8),
                        Text('Signature successfully captured!', style: BtText.subhead(context, color: Bt.green, weight: FontWeight.w600)),
                      ]),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: EntryLabeled(
                  label: 'Payment date',
                  child: BtPickerField(
                    text: formatDate(_selectedPaymentDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedPaymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (c, child) => Theme(
                            data: Theme.of(c).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF0B63CE),
                                onPrimary: Colors.white,
                                onSurface: _kDark,
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
                      },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          EntryLabeled(
            label: 'Payment proof',
            child: (_uploadedReceipt != null && _uploadedReceipt!.isNotEmpty)
                ? BtGroup(children: [
                    BtRow(
                      leading: BtTile(icon: Icons.check_rounded, bg: Bt.greenSoft, fg: Bt.green),
                      title: _uploadedReceipt!,
                      trailing: BtIconButton(
                        icon: Icons.close_rounded,
                        semantic: 'Remove receipt',
                        color: Bt.ink3,
                        onTap: () => setState(() {
                          _uploadedReceipt = null;
                          _newReceiptDataUri = null;
                        }),
                      ),
                    ),
                  ])
                : Material(
                    color: Bt.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Bt.rInput),
                      side: const BorderSide(color: Bt.inputBorder),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Bt.rInput),
                      onTap: () async {
                        final attachment = await pickAttachmentDirect(context);
                        if (attachment != null) {
                          setState(() {
                            _uploadedReceipt = attachment.name;
                            _newReceiptDataUri = attachment.dataUri;
                          });
                        }
                      },
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.upload_rounded, color: Bt.ink2, size: 20),
                            const SizedBox(width: 8),
                            Text('Upload payment receipt', style: BtText.body(context, weight: FontWeight.w500)),
                            Text('  · PNG, JPG, PDF', style: BtText.caption(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          EntryLabeled(
            label: 'Remarks / reference number',
            child: EntryNotesField(
              controller: _noteCtrl,
              hint: 'Transaction ID, cheque number, or remarks…',
            ),
          ),
        ],
      ),
      bottomNavigationBar: EntryBottomBar(
        child: Row(
          children: [
            Expanded(
              child: BtButton(
                label: 'Cancel',
                variant: BtButtonVariant.secondary,
                onPressed: _isSaving ? null : () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
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
      ),
    );
  }
}
