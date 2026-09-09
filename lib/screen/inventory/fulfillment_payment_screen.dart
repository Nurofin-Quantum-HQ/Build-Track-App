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
    while (_isEsignPolling) {
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
  }
  static const _pMethods = [
    {'label': 'UPI', 'icon': Icons.phone_android_outlined},
    {'label': 'Cash', 'icon': Icons.money_outlined},
    {'label': 'Bank Transfer', 'icon': Icons.account_balance_outlined},
    {'label': 'Card', 'icon': Icons.credit_card_outlined},
    {'label': 'Cheque', 'icon': Icons.description_outlined},
  ];
  static const Color _kDark = Color(0xFF1E1E2E);
  static const Color _kGray = Color(0xFF6B7280);
  static const Color _kLightBg = Color(0xFFF4F5FF);
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
      if (apiPaymentMode == 'Bank Transfer' || apiPaymentMode == 'Card') {
        apiPaymentMode = 'Bank';
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
      final success = await ApiService.updateTransactionPayment(
        _entryId,
        payload,
      );
      if (success) {
        if (mounted) {
          context.read<ProjectProvider>().load();
          context.read<InventoryProvider>().loadInventory(_projectId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                amount > 0
                    ? '${formatCurrency(amount)} recorded via $_selectedMethod'
                    : 'Payment details updated successfully',
              ),
              backgroundColor: const Color(0xFF15803D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to update payment on server'),
              backgroundColor: Colors.red.shade600,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
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
    final double parentW = MediaQuery.of(context).size.width;
    final double chipW = (parentW - 40) / 2;
    final double fullW = parentW - 32;
    return Scaffold(
      backgroundColor: _kLightBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E4F6)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF173EEA),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Fulfillment & Payment',
                      style: TextStyle(
                        color: _kDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF173EEA), Color(0xFF6B2FD9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'INVENTORY ITEM DETAILS',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _itemName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${_itemType.toUpperCase()} · ${_projectName.isNotEmpty ? _projectName : "Project"}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_quantity > 0 && _rate > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Qty: ${_quantity % 1 == 0 ? _quantity.toInt() : _quantity} @ ₹${_rate % 1 == 0 ? _rate.toInt() : _rate}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'OUTSTANDING',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatCurrency(_outstanding),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${formatCurrency(_alreadyPaid)} paid',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'PAYMENT STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _kGray,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatusCard(
                          PaymentStatus.paid,
                          'Fully Paid',
                          const Color(0xFF15803D),
                          const Color(0xFFDCFCE7),
                          (v) => setState(() {
                            _selectedStatus = v;
                            _amountError = null;
                            _amountCtrl.text = _outstanding.toStringAsFixed(0);
                          }),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusCard(
                          PaymentStatus.partial,
                          'Partial',
                          const Color(0xFFB45309),
                          const Color(0xFFFEF3C7),
                          (v) => setState(() {
                            _selectedStatus = v;
                            _amountError = null;
                            if (_amountCtrl.text == '0' ||
                                _amountCtrl.text ==
                                    _outstanding.toStringAsFixed(0)) {
                              _amountCtrl.clear();
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusCard(
                          PaymentStatus.pending,
                          'Not Paid',
                          const Color(0xFFDC2626),
                          const Color(0xFFFEE2E2),
                          (v) => setState(() {
                            _selectedStatus = v;
                            _amountError = null;
                            _amountCtrl.text = '0';
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ACTUAL AMOUNT PAID (₹)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _kGray,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedOpacity(
                      opacity: _selectedStatus == PaymentStatus.pending
                          ? 0.4
                          : 1.0,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _amountError != null
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFE2E4F6),
                            width: _amountError != null ? 1.5 : 1.0,
                          ),
                        ),
                        child: TextField(
                          controller: _amountCtrl,
                          enabled: _selectedStatus != PaymentStatus.pending,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
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
                          textAlignVertical: TextAlignVertical.center,
                          decoration: const InputDecoration(
                            prefixText: '₹ ',
                            prefixStyle: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: _kGray,
                            ),
                            hintText: '0.00',
                            hintStyle: TextStyle(color: _kGray),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _kDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'PAYMENT METHOD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _kGray,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._pMethods.take(4).map((m) {
                          final lbl = m['label'] as String;
                          final ico = m['icon'] as IconData;
                          final sel = _selectedMethod == lbl;
                          return _buildMethodChip(lbl, ico, sel, chipW, () {
                            setState(() => _selectedMethod = lbl);
                          });
                        }),
                        Builder(
                          builder: (_) {
                            const lbl = 'Cheque';
                            const ico = Icons.description_outlined;
                            final sel = _selectedMethod == lbl;
                            return _buildMethodChip(lbl, ico, sel, fullW, () {
                              setState(() => _selectedMethod = lbl);
                            });
                          },
                        ),
                      ],
                    ),
                    if (_selectedMethod == 'Cash') ...[
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text(
                          'Request E-Signature for Cash Receipt',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark),
                        ),
                        value: _requestEsign,
                        onChanged: (val) => setState(() => _requestEsign = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF173EEA),
                      ),
                      if (_requestEsign)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: TextField(
                            controller: _clientEmailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Client Email Address',
                              labelStyle: const TextStyle(color: _kGray, fontSize: 13),
                              prefixIcon: const Icon(Icons.email_outlined, color: _kGray, size: 20),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E4F6)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF173EEA), width: 1.5),
                              ),
                            ),
                            style: const TextStyle(fontSize: 14, color: _kDark, fontWeight: FontWeight.w500),
                          ),
                        ),
                      if (_requestEsign && !_isEsignCompleted) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isEsignPolling ? () {
                              setState(() => _isEsignPolling = false);
                            } : _startEsignFlow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEsignPolling ? Colors.red : const Color(0xFF173EEA),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(_isEsignPolling ? 'Cancel Polling' : 'Send for E-Signature', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        if (_esignStatusText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_esignStatusText, style: TextStyle(color: _isEsignPolling ? Colors.orange : (_isEsignCompleted ? Colors.green : Colors.red), fontWeight: FontWeight.bold)),
                          )
                      ],
                      if (_isEsignCompleted) ...[
                         const SizedBox(height: 8),
                         Container(
                           padding: const EdgeInsets.all(12),
                           decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                           child: const Row(
                             children: [
                               Icon(Icons.check_circle, color: Colors.green),
                               SizedBox(width: 8),
                               Text('Signature successfully captured!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                             ]
                           )
                         )
                      ],
                    ],
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(top: 5, left: 2),
                      child: Text(
                        _amountError ?? helperText,
                        style: TextStyle(
                          color: _amountError != null
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF6B7280),
                          fontSize: 11,
                          fontStyle: _amountError != null
                              ? FontStyle.italic
                              : FontStyle.normal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'PAYMENT RECEIPT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _kGray,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final attachment = await pickAttachmentDirect(context);
                        if (attachment != null) {
                          setState(() {
                            _uploadedReceipt = attachment.name;
                            _newReceiptDataUri = attachment.dataUri;
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: _uploadedReceipt != null
                              ? const Color(0xFFF0FDF4)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _uploadedReceipt != null
                                ? const Color(0xFF15803D)
                                : const Color(0xFFCCCFE8),
                            width: 1.5,
                          ),
                        ),
                        child: _uploadedReceipt != null
                            ? Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Color(0xFF15803D),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _uploadedReceipt!,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF15803D),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _uploadedReceipt = null;
                                      _newReceiptDataUri = null;
                                    }),
                                    child: const Icon(
                                      Icons.close,
                                      color: Color(0xFF6B7280),
                                      size: 16,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEEFFF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.upload_outlined,
                                      color: Color(0xFF173EEA),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Upload Payment Receipt',
                                        style: TextStyle(
                                          color: _kDark,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 1),
                                      Text(
                                        'PNG, JPG, PDF — UPI / Bank / Cheque proof',
                                        style: TextStyle(
                                          color: _kGray,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'PAYMENT DATE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _kGray,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedPaymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (c, child) => Theme(
                            data: Theme.of(c).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF173EEA),
                                onPrimary: Colors.white,
                                onSurface: _kDark,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setState(() => _selectedPaymentDate = picked);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFCCCFE8),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: Color(0xFF173EEA),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedPaymentDate.day}/${_selectedPaymentDate.month}/${_selectedPaymentDate.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _kDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'REMARKS / REFERENCE NUMBER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _kGray,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EntryNotesField(
                      controller: _noteCtrl,
                      hint: 'Transaction ID, cheque number, or remarks…',
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE8EAFF), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _isSaving ? null : () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFDDE0F0),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: _kGray,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: GestureDetector(
                      onTap: _isSaving ? null : _handleConfirmPayment,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF173EEA), Color(0xFF6B2FD9)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF173EEA,
                              ).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Confirm Payment & Update Inventory',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildStatusCard(
    PaymentStatus status,
    String label,
    Color activeColor,
    Color activeBg,
    void Function(PaymentStatus) onSelect,
  ) {
    final bool isSelected = _selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E4F6),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : _kGray,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildMethodChip(
    String label,
    IconData icon,
    bool isSelected,
    double width,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF1FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF173EEA)
                : const Color(0xFFE2E4F6),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF173EEA) : _kGray,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF173EEA) : _kDark,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
