import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/controller/entry_model.dart';
import 'package:buildtrack_mobile/controller/entry_permissions.dart';
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/controller/inventory_provider.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({super.key});
  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}
class _EntryDetailScreenState extends State<EntryDetailScreen> {
  static primaryBlue = AppColors.primary;
  static const bgColor = AppColors.gradientStart;
  static const textDark = AppColors.textDark;
  static const textGray = AppColors.textLight;
  bool _argsLoaded = false;
  Map _args = {};
  EntryStatus _entryStatus = EntryStatus.pending;
  PaymentStatus _payStatus = PaymentStatus.pending;
  double _billAmount = 0;
  double _paidAmount = 0;
  List<dynamic> _paymentHistory = [];
  String? _paymentReceiptFile;
  bool _viewAllPayments = false;
  String? _customDate;
  String? _floor;
  String? _phase;
  String? _activity;
  String? _projectName;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    _args = args;
    final statusStr = args['status'] as String? ?? 'pending';
    _entryStatus = EntryStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => EntryStatus.pending,
    );
    _payStatus =
        args['paymentStatus'] as PaymentStatus? ?? PaymentStatus.pending;
    _billAmount = (args['billAmount'] as num?)?.toDouble() ?? 0;
    _paidAmount = (args['paidAmount'] as num?)?.toDouble() ?? 0;
    final rawHistory = args['paymentHistory'];
    if (rawHistory is List) {
      _paymentHistory = List.from(rawHistory);
    } else {
      _paymentHistory = [];
    }
    _customDate = args['date'] as String?;
    _floor = args['floor'] as String?;
    _phase = args['phase'] as String?;
    _activity = args['activity'] as String?;
    _projectName = args['projectName'] as String?;
    _paymentReceiptFile =
        args['paymentReceipt'] as String? ??
        (_paymentHistory.isNotEmpty
            ? _paymentHistory.last['receipt'] as String?
            : null);
    _fetchInitialDetails();
  }
  Future<void> _fetchInitialDetails() async {
    final id = _args['id'] ?? _args['_id'] ?? _args['entryId'];
    if (id == null || id.toString().isEmpty) return;
    try {
      final latest = await ApiService.fetchTransactionById(id.toString());
      if (latest != null && mounted) {
        setState(() {
          _args = { ..._args, ...latest };
          final pStatus = latest['paymentStatus']?.toString().toLowerCase() ?? 'pending';
          if (pStatus == 'paid') {
            _payStatus = PaymentStatus.paid;
          } else if (pStatus == 'partial') {
            _payStatus = PaymentStatus.partial;
          } else if (pStatus == 'overdue') {
            _payStatus = PaymentStatus.overdue;
          } else {
            _payStatus = PaymentStatus.pending;
          }
          _billAmount = (latest['amount'] as num?)?.toDouble() ?? _billAmount;
          _paidAmount = (latest['paidAmount'] as num?)?.toDouble() ?? _paidAmount;
          _paymentHistory = latest['paymentHistory'] is List
              ? List.from(latest['paymentHistory'])
              : [];
          _paymentReceiptFile = latest['paymentReceipt'] as String? ??
              (_paymentHistory.isNotEmpty ? _paymentHistory.last['receipt'] as String? : null);
        });
      }
    } catch (e) {
      debugPrint('Error fetching transaction details: $e');
    }
  }
  static Color _typeColor(String type) {
    switch (type) {
      case 'labour':
        return const Color(0xFF2E7D32);
      case 'equipment':
        return const Color(0xFFE65100);
      default:
        return primaryBlue;
    }
  }
  static Color _typeBg(String type) {
    switch (type) {
      case 'labour':
        return const Color(0xFFE8F5E9);
      case 'equipment':
        return const Color(0xFFFFF3E0);
      default:
        return const Color(0xFFEEF0FF);
    }
  }
  static IconData _typeIcon(String type) {
    switch (type) {
      case 'labour':
        return Icons.people_outline;
      case 'equipment':
        return Icons.construction_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
  static String _typeLabel(String type) {
    switch (type) {
      case 'labour':
        return 'LABOUR';
      case 'equipment':
        return 'EQUIPMENT';
      default:
        return 'MATERIAL';
    }
  }
  static String _editRoute(String type) {
    switch (type) {
      case 'labour':
        return '/add-labour';
      case 'equipment':
        return '/add-equipment';
      default:
        return '/add-material';
    }
  }
  Widget _fieldLabel(String t) =>
      Text(t, style: AppTheme.label.copyWith(color: textGray));
  Widget _contextRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textGray),
        const SizedBox(width: 8),
        Text(label, style: AppTheme.caption.copyWith(color: textGray)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
  String _formatDateTimeWithTime(dynamic dateVal) {
    if (dateVal == null) return '';
    final str = dateVal.toString().trim();
    if (str.isEmpty) return '';
    DateTime? dt;
    try {
      dt = DateTime.parse(str).toLocal();
    } catch (_) {
      dt = DateTime.tryParse(str)?.toLocal();
    }
    if (dt == null) {
      return str;
    }
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    final hour = dt.hour;
    final minute = dt.minute;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    final timeStr = '$displayHour:$displayMinute $ampm';
    final now = DateTime.now();
    final diff = now.difference(dt);
    final isFuture = diff.isNegative;
    final absDiff = diff.abs();
    final String relativeStr;
    if (absDiff.inMinutes < 60) {
      relativeStr = isFuture
          ? 'in ${absDiff.inMinutes}m'
          : '${absDiff.inMinutes}m ago';
    } else if (absDiff.inHours < 24) {
      relativeStr = isFuture
          ? 'in ${absDiff.inHours}h'
          : '${absDiff.inHours}h ago';
    } else if (absDiff.inDays == 1) {
      relativeStr = isFuture ? 'Tomorrow' : 'Yesterday';
    } else {
      relativeStr = isFuture
          ? 'in ${absDiff.inDays}d'
          : '${absDiff.inDays}d ago';
    }
    return '$dateStr • $timeStr ($relativeStr)';
  }
  @override
  Widget build(BuildContext context) {
    final args = _args;
    final String title = args['title']?.toString() ?? 'Stock Entry';
    final String ref = args['ref']?.toString() ?? '#INV-0000';
    final String amount = args['amount']?.toString() ?? '+0';
    final String date =
        _customDate ?? args['date']?.toString() ?? 'Unknown date';
    final String displayDate = _formatDateTimeWithTime(date);
    final String type = args['type']?.toString() ?? 'material';
    final String name = args['name']?.toString() ?? 'Item';
    final bool isPositive = args['isPositive'] as bool? ?? true;
    final Set<String> allInvoices = {};
    if (args['receipt'] != null && args['receipt'].toString().isNotEmpty) {
      allInvoices.add(args['receipt'].toString());
    }
    if (args['attachments'] is List) {
      for (var a in args['attachments']) {
        if (a != null && a.toString().isNotEmpty) {
          allInvoices.add(a.toString());
        }
      }
    }
    final List<String> invoiceList = allInvoices.toList();
    final Set<String> allPaymentReceipts = {};
    if (args['paymentReceipt'] != null && args['paymentReceipt'].toString().isNotEmpty) {
      allPaymentReceipts.add(args['paymentReceipt'].toString());
    }
    if (_paymentReceiptFile != null && _paymentReceiptFile!.isNotEmpty) {
      allPaymentReceipts.add(_paymentReceiptFile!);
    }
    for (var ph in _paymentHistory) {
      final pr = ph['receipt'] ?? ph['paymentReceipt'];
      if (pr != null && pr.toString().isNotEmpty) {
        allPaymentReceipts.add(pr.toString());
      }
    }
    final List<String> receiptList = allPaymentReceipts.toList();
    final String createdBy = args['createdBy']?.toString() ?? '';
    final String projectId = args['projectId']?.toString() ?? '';
    final String supplier = args['supplier']?.toString() ?? '';
    final String initialMethod = args['paymentMethod']?.toString() ?? '';
    final String method = (_paymentHistory.isNotEmpty && _paidAmount > 0)
        ? (_paymentHistory.last['method'] ??
              _paymentHistory.last['paymentMode'] ??
              initialMethod)
        : (_paidAmount > 0 ? initialMethod : '');
    final String rawLastUpdated = _paymentHistory.isNotEmpty
        ? (_paymentHistory.last['date']?.toString() ?? date)
        : date;
    final String lastUpdated = _formatDateTimeWithTime(rawLastUpdated);
    final bool canEdit = EntryPermissions.canEdit(
      status: _entryStatus.name,
      createdBy: createdBy,
      projectId: projectId,
    );
    final bool canDelete = EntryPermissions.canDelete(
      status: _entryStatus.name,
      createdBy: createdBy,
      projectId: projectId,
    );
    final double due = (_billAmount - _paidAmount).clamp(0.0, double.infinity);
    final bool canSettle =
        _payStatus == PaymentStatus.pending ||
        _payStatus == PaymentStatus.partial ||
        _payStatus == PaymentStatus.overdue;
    final bool isSettled = _payStatus == PaymentStatus.paid;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, type, args, canEdit, canDelete),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEF0F8)),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildTypeBadge(type),
                        const SizedBox(width: 8),
                        PaymentStatusChip(status: _payStatus),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('ITEM'),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: AppTheme.heading2.copyWith(
                              fontSize: 20,
                              color: textDark,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: AppTheme.body.copyWith(color: textGray),
                          ),
                          if (supplier.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.storefront_outlined,
                                  color: textGray,
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  supplier,
                                  style: AppTheme.caption.copyWith(
                                    color: textGray,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('EXECUTION CONTEXT'),
                          const SizedBox(height: 10),
                          _contextRow(
                            Icons.business_outlined,
                            'Project',
                            _projectName ?? projectId,
                          ),
                          const SizedBox(height: 8),
                          _contextRow(
                            Icons.layers_outlined,
                            'Floor / Zone',
                            _floor ?? '—',
                          ),
                          const SizedBox(height: 8),
                          _contextRow(
                            Icons.flag_outlined,
                            'Phase',
                            _phase ?? '—',
                          ),
                          const SizedBox(height: 8),
                          _contextRow(
                            Icons.task_alt_outlined,
                            'Activity',
                            _activity ?? '—',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _fieldLabel('QUANTITY / VALUE'),
                                    const SizedBox(height: 6),
                                    Text(
                                      amount,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 26,
                                        color: isPositive
                                            ? _typeColor(type)
                                            : const Color(0xFFE040FB),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _fieldLabel('REFERENCE'),
                                    const SizedBox(height: 6),
                                    Text(
                                      ref,
                                      style: AppTheme.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const AppDivider(verticalPadding: 12),
                          _fieldLabel('PURCHASE DATE'),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                color: _typeColor(type),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  displayDate,
                                  style: AppTheme.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_billAmount > 0) ...[
                      _buildSettlementCard(
                        due: due,
                        method: method,
                        lastUpdated: lastUpdated,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildPaymentHistoryCard(),
                    if (_paymentHistory.isNotEmpty) const SizedBox(height: 14),
                    AppCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('INVOICE / BILL'),
                          const SizedBox(height: 12),
                          if (invoiceList.isEmpty)
                            const InvoiceAttachmentCard(
                              attachment: null,
                              fileName: null,
                            )
                          else
                            ...invoiceList.map((url) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: InvoiceAttachmentCard(
                                    attachment: null,
                                    fileName: url,
                                  ),
                                )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('PAYMENT RECEIPT'),
                          const SizedBox(height: 12),
                          if (receiptList.isEmpty)
                            const PaymentReceiptCard(fileName: null)
                          else
                            ...receiptList.map((url) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: PaymentReceiptCard(fileName: url),
                                )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (canSettle && RoleManager.canApprovePayments)
                      _buildRecordPaymentCTA(
                        context,
                        id: args['id']?.toString() ?? '',
                        title: title,
                        ref: ref,
                        supplier: supplier,
                        type: type,
                      ),
                    if (isSettled) _buildSettledBadge(),
                    if (canDelete) ...[
                      const SizedBox(height: 16),
                      _buildDeleteAction(
                        context,
                        id: args['id']?.toString() ?? '',
                        projectId: projectId,
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildTopBar(
    BuildContext context,
    String type,
    Map args,
    bool canEdit,
    bool canDelete,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.arrow_back, color: textDark, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Entry Detail',
              style: AppTheme.heading3.copyWith(color: textDark),
            ),
          ),
          if (canEdit)
            TextButton(
              onPressed: () => Navigator.pushNamed(
                context,
                _editRoute(type),
                arguments: {
                  ...args,
                  'isEditing': true,
                  'status': _entryStatus.name,
                },
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                backgroundColor: const Color(0xFFEEF0FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _typeBg(type),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_typeIcon(type), color: _typeColor(type), size: 13),
          const SizedBox(width: 6),
          Text(
            _typeLabel(type),
            style: TextStyle(
              color: _typeColor(type),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSettlementCard({
    required double due,
    required String method,
    required String lastUpdated,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SETTLEMENT SUMMARY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textGray,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          _settlementRow(
            'Bill Amount',
            formatCurrency(_billAmount),
            color: textDark,
          ),
          const SizedBox(height: 10),
          _settlementRow(
            'Paid Amount',
            formatCurrency(_paidAmount),
            color: const Color(0xFF15803D),
          ),
          const SizedBox(height: 10),
          _settlementRow(
            'Due Amount',
            formatCurrency(due),
            color: due > 0 ? const Color(0xFFD97706) : const Color(0xFF15803D),
            bold: true,
          ),
          if (method.isNotEmpty || lastUpdated.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF0F0F8)),
            ),
            if (method.isNotEmpty)
              _settlementRow('Payment Method', method, color: textDark),
            if (lastUpdated.isNotEmpty) ...[
              const SizedBox(height: 10),
              _settlementRow('Last Updated', lastUpdated, color: textGray),
            ],
          ],
        ],
      ),
    );
  }
  Widget _settlementRow(
    String label,
    String value, {
    Color color = textDark,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textGray,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildRecordPaymentCTA(
    BuildContext context, {
    required String id,
    required String title,
    required String ref,
    required String supplier,
    required String type,
  }) {
    final label = _payStatus == PaymentStatus.partial
        ? 'Settle Remaining Payment'
        : 'Record Payment';
    return GestureDetector(
      onTap: () {
        final projectProvider = context.read<ProjectProvider>();
        String pName = 'Unknown Project';
        String pId = _args['projectId'] ?? _args['project'] ?? '';
        final matchedProj = projectProvider.projects.where((p) => p.id == pId);
        if (matchedProj.isNotEmpty) {
          pName = matchedProj.first.name;
        }
        final payArgs = {
          'id': id,
          'projectId': pId,
          'projectName': pName,
          'itemId': _args['itemId'] ?? '',
          'itemName': _args['name'] ?? _args['title'] ?? title,
          'itemType': type,
          'quantity': (_args['quantity'] as num?)?.toDouble() ?? 0.0,
          'rate': (_args['rate'] as num?)?.toDouble() ?? 0.0,
          'totalAmount': _billAmount,
          'paidAmount': _paidAmount,
          'outstandingAmount': (_billAmount - _paidAmount).clamp(
            0.0,
            double.infinity,
          ),
          'paymentStatus': _payStatus,
          'receipt': _paymentReceiptFile ?? '',
          'transactionDetails': _args,
        };
        Navigator.pushNamed(
          context,
          '/fulfillment-payment',
          arguments: payArgs,
        ).then((updated) async {
          if (updated == true && mounted) {
            final latest = await ApiService.fetchTransactionById(id);
            if (latest != null && mounted) {
              setState(() {
                _paidAmount = (latest['paidAmount'] as num?)?.toDouble() ?? 0.0;
                final pStatus =
                    latest['paymentStatus']?.toString().toLowerCase() ??
                    'pending';
                if (pStatus == 'paid') {
                  _payStatus = PaymentStatus.paid;
                } else if (pStatus == 'partial') {
                  _payStatus = PaymentStatus.partial;
                } else if (pStatus == 'overdue') {
                  _payStatus = PaymentStatus.overdue;
                } else {
                  _payStatus = PaymentStatus.pending;
                }
                _paymentHistory = latest['paymentHistory'] is List
                    ? List.from(latest['paymentHistory'])
                    : [];
                final dynamic freshPaymentReceipt =
                    latest['paymentReceipt'] ??
                    (_paymentHistory.isNotEmpty
                        ? _paymentHistory.last['receipt']
                        : null);
                if (freshPaymentReceipt != null &&
                    freshPaymentReceipt.toString().isNotEmpty) {
                  _paymentReceiptFile = freshPaymentReceipt.toString();
                }
              });
            }
          }
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B5CF6), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payments_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildSettledBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFF6EE7B7), width: 1.5),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 20),
          SizedBox(width: 8),
          Text(
            'Payment Settled',
            style: TextStyle(
              color: Color(0xFF15803D),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPaymentHistoryCard() {
    if (_paymentHistory.isEmpty) return const SizedBox.shrink();
    final reversedHistory = List.from(_paymentHistory.reversed);
    final displayedHistory = _viewAllPayments
        ? reversedHistory
        : [reversedHistory.first];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded, color: textGray, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'PAYMENT HISTORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: textGray,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              if (_paymentHistory.length > 1)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _viewAllPayments = !_viewAllPayments;
                    });
                  },
                  child: Text(
                    _viewAllPayments
                        ? 'View Less'
                        : 'View All (${_paymentHistory.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedHistory.length,
            separatorBuilder: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFF0F0F8)),
            ),
            itemBuilder: (context, index) {
              final item = displayedHistory[index] ?? {};
              final rawDate = item['date'] ?? item['paymentDate'];
              final String formattedDate = _formatDateTimeWithTime(rawDate);
              final double amt = (item['amount'] as num?)?.toDouble() ?? 0;
              final String method = item['method'] as String? ?? 'Cash';
              final String note = item['note'] as String? ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF0FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                method.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: primaryBlue,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatCurrency(amt),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Note: $note',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: textGray,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  Widget _buildDeleteAction(
    BuildContext context, {
    required String id,
    required String projectId,
  }) {
    return GestureDetector(
      onTap: () => _showDeleteDialog(context, id: id, projectId: projectId),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: Colors.red.withValues(alpha: 0.65),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Delete Entry',
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.65),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showDeleteDialog(
    BuildContext context, {
    required String id,
    required String projectId,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Entry?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This action cannot be undone. The entry will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: textGray, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (id.isNotEmpty) {
                final success = await ApiService.deleteTransaction(id);
                if (success && context.mounted) {
                  if (projectId.isNotEmpty) {
                    context.read<InventoryProvider>().loadInventory(projectId);
                  }
                  context.read<ProjectProvider>().load();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Entry deleted successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.pop(context);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete entry'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
