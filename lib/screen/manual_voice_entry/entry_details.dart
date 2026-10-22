import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/controller/entry_model.dart';
import 'package:buildtrack_mobile/controller/entry_permissions.dart';
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
    _floor = args['floor']?.toString();
    _phase = args['phase']?.toString();
    _activity = args['activity']?.toString();
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
          String? str(dynamic v) => (v == null || v.toString().trim().isEmpty) ? null : v.toString();
          _phase = str(latest['phase']) ?? _phase;
          _activity = str(latest['activity']) ?? _activity;
          _floor = str(latest['floor']) ?? _floor;
        });
      }
    } catch (e) {
      debugPrint('Error fetching transaction details: $e');
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
    final double progress = _billAmount > 0 ? (_paidAmount / _billAmount).clamp(0.0, 1.0) : 0.0;
    final bool showPay = canSettle && RoleManager.canApprovePayments;
    final String payLabel = _payStatus == PaymentStatus.partial
        ? 'Settle remaining'
        : 'Record payment';
    final String projectLabel = _projectName ??
        context.read<ProjectProvider>().projects.where((p) => p.id == projectId).firstOrNull?.name ??
        projectId;
    final whereParts = [_phase, _activity, _floor].where((v) => v != null && v.trim().isNotEmpty).join(' · ');
    String statusLabel;
    BtTone statusTone;
    switch (_payStatus) {
      case PaymentStatus.paid:
        statusLabel = 'Paid';
        statusTone = BtTone.green;
        break;
      case PaymentStatus.partial:
        statusLabel = 'Part paid';
        statusTone = BtTone.amber;
        break;
      case PaymentStatus.overdue:
        statusLabel = 'Overdue';
        statusTone = BtTone.red;
        break;
      default:
        statusLabel = 'Not paid';
        statusTone = BtTone.amber;
    }
    final typeWord = _typeLabel(type);
    final bt = context.bt;
    void openPay() => _openRecordPayment(
          context,
          id: args['id']?.toString() ?? '',
          title: title,
          type: type,
        );
    final hero = BtHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BtIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Bt.bone,
                background: Colors.white.withValues(alpha: .09),
                semantic: 'Back',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              if (canDelete)
                BtIconButton(
                  icon: Icons.more_horiz_rounded,
                  color: Bt.bone,
                  background: Colors.white.withValues(alpha: .09),
                  semantic: 'More actions',
                  onTap: () => showBtSheet(
                    context,
                    title: 'Entry',
                    builder: (sheetCtx) => BtGroup(children: [
                      BtRow(
                        leading: BtTile(icon: Icons.delete_outline_rounded, bg: Bt.redSoft, fg: Bt.red),
                        title: 'Delete entry…',
                        titleColor: Bt.red,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _showDeleteDialog(context, id: args['id']?.toString() ?? '', projectId: projectId);
                        },
                      ),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          BtReveal(
            child: Row(
              children: [
                Text(typeWord, style: BtText.mono(context, color: bt.accent)),
                const SizedBox(width: 10),
                BtBadge(label: statusLabel, tone: statusTone),
              ],
            ),
          ),
          const SizedBox(height: 10),
          BtReveal(
            index: 1,
            child: Text(name, style: BtText.d2(context, color: Bt.bone)),
          ),
          if (title.isNotEmpty && title != name) ...[
            const SizedBox(height: 4),
            BtReveal(
              index: 1,
              child: Text(title, style: BtText.subhead(context, color: Bt.onNoir2)),
            ),
          ],
          const SizedBox(height: 16),
          BtReveal(
            index: 2,
            child: _billAmount > 0
                ? BtCountUp(
                    value: _billAmount,
                    format: (v) => formatInr(v),
                    style: BtText.d0(context, color: Bt.bone),
                  )
                : Text(
                    amount,
                    style: BtText.d1(context, color: isPositive ? Bt.bone : Bt.redBright),
                  ),
          ),
          if (_billAmount > 0) ...[
            const SizedBox(height: 16),
            BtReveal(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BtProgress(value: progress, color: Bt.greenBright, onDark: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(text: formatInr(_paidAmount), style: BtText.num(BtText.subhead(context, color: Bt.greenBright, weight: FontWeight.w600))),
                        TextSpan(text: ' paid', style: BtText.subhead(context, color: Bt.onNoir2)),
                      ])),
                      const Spacer(),
                      if (isSettled)
                        Row(children: [
                          const Icon(Icons.check_circle_rounded, color: Bt.greenBright, size: 16),
                          const SizedBox(width: 6),
                          Text('Payment settled', style: BtText.subhead(context, color: Bt.greenBright, weight: FontWeight.w600)),
                        ])
                      else
                        Text.rich(TextSpan(children: [
                          TextSpan(text: formatInr(due), style: BtText.num(BtText.subhead(context, color: due > 0 ? Bt.amberBright : Bt.greenBright, weight: FontWeight.w600))),
                          TextSpan(text: ' to go', style: BtText.subhead(context, color: Bt.onNoir2)),
                        ])),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (isSettled) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.check_circle_rounded, color: Bt.greenBright, size: 16),
              const SizedBox(width: 6),
              Text('Payment settled', style: BtText.subhead(context, color: Bt.greenBright, weight: FontWeight.w600)),
            ]),
          ],
        ],
      ),
    );
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Bt.ground,
      body: BtHeroScroll(
        hero: hero,
        children: [
          if (canEdit || showPay) ...[
            BtReveal(
              index: 4,
              child: Row(
                children: [
                  if (showPay)
                    Expanded(
                      flex: 2,
                      child: BtButton(
                        label: payLabel,
                        icon: Icons.add_rounded,
                        variant: BtButtonVariant.accent,
                        onPressed: openPay,
                      ),
                    ),
                  if (canEdit && showPay) const SizedBox(width: 10),
                  if (canEdit)
                    Expanded(
                      child: BtButton(
                        label: 'Edit',
                        variant: BtButtonVariant.secondary,
                        onPressed: () => Navigator.pushNamed(
                          context,
                          _editRoute(type),
                          arguments: {
                            ...args,
                            'isEditing': true,
                            'status': _entryStatus.name,
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_paymentHistory.isNotEmpty) ...[
            BtReveal(index: 5, child: _buildPaymentHistoryCard()),
            const SizedBox(height: 24),
          ],
          BtReveal(
            index: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BtSectionHeader(title: 'Invoice / bill'),
                if (invoiceList.isEmpty)
                  const InvoiceAttachmentCard(attachment: null, fileName: null)
                else
                  ...invoiceList.map((url) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: InvoiceAttachmentCard(attachment: null, fileName: url),
                      )),
                const SizedBox(height: 24),
                const BtSectionHeader(title: 'Payment receipt'),
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
          const SizedBox(height: 24),
          BtReveal(
            index: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BtSectionHeader(title: 'Details'),
                BtGroup(
                  children: [
                    BtValueRow(label: 'Project', value: projectLabel),
                    if (whereParts.isNotEmpty) BtValueRow(label: 'Used in', value: whereParts),
                    BtValueRow(label: 'Date', value: displayDate),
                    BtValueRow(label: 'Quantity / value', value: amount, valueColor: isPositive ? null : Bt.red),
                    BtValueRow(label: 'Reference', value: ref),
                    if (supplier.isNotEmpty) BtValueRow(label: 'Supplier', value: supplier),
                    if (method.isNotEmpty) BtValueRow(label: 'Payment method', value: method),
                    if (_billAmount > 0 && lastUpdated.isNotEmpty) BtValueRow(label: 'Last updated', value: lastUpdated),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  void _openRecordPayment(
    BuildContext context, {
    required String id,
    required String title,
    required String type,
  }) {
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
  }
  Widget _buildPaymentHistoryCard() {
    if (_paymentHistory.isEmpty) return const SizedBox.shrink();
    final reversedHistory = List.from(_paymentHistory.reversed);
    final displayedHistory = _viewAllPayments
        ? reversedHistory
        : [reversedHistory.first];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtSectionHeader(
          title: 'Payments',
          action: _paymentHistory.length > 1
              ? (_viewAllPayments ? 'View less' : 'View all (${_paymentHistory.length})')
              : null,
          onAction: () => setState(() => _viewAllPayments = !_viewAllPayments),
        ),
        BtGroup(
          children: [
            for (final raw in displayedHistory)
              Builder(builder: (context) {
                final item = raw ?? {};
                final rawDate = item['date'] ?? item['paymentDate'];
                final String formattedDate = _formatDateTimeWithTime(rawDate);
                final double amt = (item['amount'] as num?)?.toDouble() ?? 0;
                final String method = item['method'] as String? ?? 'Cash';
                final String note = item['note'] as String? ?? '';
                return BtRow(
                  leading: BtTile(icon: Icons.payments_outlined, bg: Bt.greenSoft, fg: Bt.green),
                  title: method,
                  subtitle: note.isNotEmpty ? '$formattedDate · $note' : formattedDate,
                  subtitleMaxLines: 2,
                  minHeight: 64,
                  trailing: Text(formatInr(amt), style: BtText.num(BtText.title(context, size: 16))),
                );
              }),
          ],
        ),
      ],
    );
  }
  Future<void> _showDeleteDialog(
    BuildContext context, {
    required String id,
    required String projectId,
  }) async {
    final confirmed = await btConfirm(
      context,
      title: 'Delete entry?',
      message: 'This action cannot be undone. The entry will be permanently removed.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    if (id.isNotEmpty) {
      final success = await ApiService.deleteTransaction(id);
      if (success && context.mounted) {
        if (projectId.isNotEmpty) {
          context.read<InventoryProvider>().loadInventory(projectId);
        }
        context.read<ProjectProvider>().load();
        btToast(context, 'Entry deleted successfully');
        Navigator.pop(context);
      } else if (context.mounted) {
        btToast(context, 'Failed to delete entry', error: true);
      }
    } else {
      Navigator.pop(context);
    }
  }
}
