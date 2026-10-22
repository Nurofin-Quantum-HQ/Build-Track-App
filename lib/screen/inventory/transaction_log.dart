import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/controller/entry_permissions.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
class TransactionLogsScreen extends StatefulWidget {
  const TransactionLogsScreen({super.key});
  @override
  State<TransactionLogsScreen> createState() => _TransactionLogsScreenState();
}
class _TransactionLogsScreenState extends State<TransactionLogsScreen> {
  int _filterIndex = 0;
  String _itemName = 'Item';
  String _itemType = 'material';
  bool _argsLoaded = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allLogs = [];
  bool _isGeneral = false;
  String? _filterProjectId;
  bool _hasPassedProject = false;
  final Map<String, bool> _collapsedGroups = {};
  List<Map<String, dynamic>> get _filteredLogs {
    final visible = EntryPermissions.filterMaps(_allLogs);
    switch (_filterIndex) {
      case 1:
        return visible.where((l) => l['isPositive'] == true).toList();
      case 2:
        return visible.where((l) => l['isPositive'] == false).toList();
      default:
        return List.from(visible);
    }
  }
  String _formatQty(double val) {
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
  double get _totalAdded {
    return _allLogs.where((l) => l['isPositive'] == true).fold(0.0, (sum, l) {
      final v =
          double.tryParse(
            l['amount']
                .toString()
                .replaceAll('+', '')
                .replaceAll('-', '')
                .trim(),
          ) ??
          0.0;
      return sum + v;
    });
  }
  double get _totalUsed {
    return _allLogs.where((l) => l['isPositive'] == false).fold(0.0, (sum, l) {
      final v =
          double.tryParse(
            l['amount']
                .toString()
                .replaceAll('+', '')
                .replaceAll('-', '')
                .trim(),
          ) ??
          0.0;
      return sum + v;
    });
  }
  String get _unitLabel {
    if (_allLogs.isNotEmpty) {
      final String rawUnit = (_allLogs.first['unit'] ?? '')
          .toString()
          .toLowerCase();
      if (rawUnit.isNotEmpty) {
        if (rawUnit == 'hour' || rawUnit == 'hours') return 'hours';
        if (rawUnit == 'day' || rawUnit == 'days') return 'days';
        if (rawUnit == 'worker' || rawUnit == 'workers') return 'workers';
        return rawUnit;
      }
    }
    switch (_itemType) {
      case 'labour':
        return 'workers';
      case 'equipment':
        return 'hrs';
      default:
        return 'units';
    }
  }
  PaymentStatus _mapPaymentStatus(String? statusStr) {
    if (statusStr == null) return PaymentStatus.pending;
    final lower = statusStr.trim().toLowerCase();
    if (lower == 'paid') return PaymentStatus.paid;
    if (lower == 'partial') return PaymentStatus.partial;
    if (lower == 'overdue') return PaymentStatus.overdue;
    return PaymentStatus.pending;
  }
  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
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
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return dateStr.toString();
    }
  }
  DateTime? _parseFormattedDate(String s) {
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final parts = s.trim().split(RegExp(r'[,\s]+'));
    if (parts.length >= 3) {
      final m = months[parts[0]];
      final d = int.tryParse(parts[1].replaceAll(',', ''));
      final y = int.tryParse(parts[2]);
      if (m != null && d != null && y != null) return DateTime(y, m, d);
    }
    return DateTime.tryParse(s)?.toLocal();
  }
  String _smartLabel(String dateStr) {
    if (dateStr.isEmpty) return 'Older';
    final dt = _parseFormattedDate(dateStr);
    if (dt == null) return 'Older';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    if (day.isAfter(weekAgo)) return 'This Week';
    return 'Older';
  }
  String _formatRelativeTime(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else {
        return '${diff.inDays}d ago';
      }
    } catch (_) {
      return dateStr.toString();
    }
  }
  Map<String, List<Map<String, dynamic>>> _groupByDate(
    List<Map<String, dynamic>> logs,
  ) {
    const order = ['Today', 'Yesterday', 'This Week', 'Older'];
    final Map<String, List<Map<String, dynamic>>> groups = {
      for (final o in order) o: [],
    };
    for (final log in logs) {
      final label = _smartLabel(log['date'] as String? ?? '');
      groups[label]!.add(log);
    }
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }
  String get _addRoute {
    switch (_itemType) {
      case 'labour':
        return '/add-labour';
      case 'equipment':
        return '/add-equipment';
      default:
        return '/add-material';
    }
  }
  String get _primaryActionLabel {
    switch (_itemType) {
      case 'labour':
        return 'Add Attendance';
      case 'equipment':
        return 'Add Usage';
      default:
        return 'Add More';
    }
  }
  Future<void> _fetchRealLogs() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await ApiService.get('/transactions?limit=10000');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> raw = [];
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          raw =
              (decoded['transactions'] ??
                      decoded['data'] ??
                      decoded['items'] ??
                      [])
                  as List<dynamic>;
        }
        final projectProvider = context.read<ProjectProvider>();
        final String? selectedProjId = _hasPassedProject
            ? _filterProjectId
            : projectProvider.selectedProject?.id;
        final List<Map<String, dynamic>> mappedList = [];
        for (final t in raw) {
          final String title = (t['title'] ?? t['materialName'] ?? 'Unknown')
              .toString();
          final String rawCat = (t['category'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final String rawType = (t['type'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (rawType == 'income' || rawType == 'revenue') {
            continue;
          }
          String category = 'material';
          if (rawCat == 'labour' ||
              rawCat == 'wages' ||
              rawCat == 'labor' ||
              rawCat.contains('labour') ||
              rawType == 'wages' ||
              rawType == 'labour') {
            category = 'labour';
          } else if (rawCat == 'equipment' ||
              rawCat == 'machinery' ||
              rawCat == 'expense' ||
              rawType == 'expense' ||
              rawType == 'equipment') {
            category = 'equipment';
          }
          String pId = '';
          if (t['project'] is Map) {
            pId = t['project']['_id']?.toString() ?? '';
          } else if (t['project'] != null) {
            pId = t['project'].toString();
          }
          if (pId.isEmpty && t['projectId'] != null) {
            if (t['projectId'] is Map) {
              pId = t['projectId']['_id']?.toString() ?? '';
            } else {
              pId = t['projectId'].toString();
            }
          }
          pId = pId.trim();
          if (selectedProjId != null && selectedProjId.isNotEmpty) {
            if (pId.isNotEmpty && pId != selectedProjId) continue;
          }
          if (!_isGeneral) {
            if (category != _itemType) continue;
            final String transactionItemName =
                (t['title'] ?? t['materialName'] ?? t['name'] ?? 'Unknown')
                    .toString()
                    .trim()
                    .toLowerCase();
            if (transactionItemName != _itemName.trim().toLowerCase()) {
              continue;
            }
          }
          bool isPositive = true;
          if (t['subType']?.toString().toLowerCase() == 'consumption') {
            isPositive = false;
          }
          IconData icon = Icons.inventory_2_outlined;
          if (category == 'labour') {
            icon = Icons.people_outline;
          } else if (category == 'equipment') {
            icon = Icons.precision_manufacturing_outlined;
          }
          final String tId = t['_id']?.toString() ?? '';
          final String ref = tId.length > 4
              ? '#${tId.substring(tId.length - 4)}'
              : '#${tId.isNotEmpty ? tId : DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
          mappedList.add({
            'title': title,
            'ref': ref,
            'amount': '${isPositive ? "+" : "-"}${t['quantity'] ?? 0}',
            'date': _formatDate(t['date']),
            'rawDate': t['date'],
            'isPositive': isPositive,
            'icon': icon,
            'receipt': (t['attachments'] is List && t['attachments'].isNotEmpty)
                ? t['attachments'].first?.toString()
                : null,
            'attachment':
                (t['attachments'] is List && t['attachments'].isNotEmpty)
                ? t['attachments'].first
                : null,
            'paymentStatus': _mapPaymentStatus(t['paymentStatus']),
            'billAmount': (t['amount'] ?? 0).toDouble(),
            'paidAmount': (t['paidAmount'] ?? 0).toDouble(),
            'supplier': t['supplier'] ?? '',
            'method': t['paymentMode'] ?? '',
            'lastUpdated': t['updatedAt'] != null
                ? _formatDate(t['updatedAt'])
                : _formatDate(t['date']),
            'rawLastUpdated': t['updatedAt'] ?? t['date'],
            'projectId': pId,
            'createdBy': t['createdBy'] ?? '',
            'id': tId,
            'category': category,
            'unit': t['unit']?.toString(),
            'paymentHistory': t['paymentHistory'],
            'rate': (t['rate'] ?? 0).toDouble(),
            'brand': t['brand'] ?? '',
            'notes': t['notes'] ?? '',
            'remarks': t['remarks'] ?? '',
            'categoryName': t['category'] ?? '',
            'quantity': (t['quantity'] ?? 0).toDouble(),
            'overtime': (t['overtime'] ?? 0).toDouble(),
            'subType': t['subType'] ?? '',
            'materialType': t['materialType'] ?? '',
            'floor': t['floor'],
            'phase': t['phase'],
            'activity': t['activity'],
            'gst': t['gst'],
            'isWithGst': t['isWithGst'],
          });
        }
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map) {
          final newEntry = args['newEntry'] as Map<String, dynamic>?;
          if (newEntry != null) {
            final alreadyExists = mappedList.any(
              (l) => l['ref'] == newEntry['ref'] || l['id'] == newEntry['id'],
            );
            if (!alreadyExists) {
              mappedList.insert(0, newEntry);
            }
          }
        }
        setState(() {
          _allLogs = mappedList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      dev.log('Error fetching logs', error: e, stackTrace: stack);
      setState(() {
        _isLoading = false;
      });
    }
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final name = args['name'] as String?;
      final type = args['type'] as String?;
      if (name != null && name.isNotEmpty) {
        _itemName = name;
        _isGeneral = false;
      } else {
        _itemName = 'Project Logs';
        _isGeneral = true;
      }
      if (type != null && type.isNotEmpty) {
        _itemType = type;
      }
      if (args.containsKey('projectId')) {
        _filterProjectId = args['projectId'] as String?;
        _hasPassedProject = true;
      }
    } else {
      _itemName = 'Project Logs';
      _isGeneral = true;
    }
    _fetchRealLogs();
  }
  @override
  Widget build(BuildContext context) {
    final title = _itemName.isNotEmpty
        ? '${_itemName[0].toUpperCase()}${_itemName.substring(1)}'
        : 'Project Logs';
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(title: title, subtitle: 'Movement logs'),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isGeneral) ...[
                      BtReveal(child: _buildSummaryCard()),
                      const SizedBox(height: 12),
                      BtReveal(index: 1, child: _buildPaymentStatusStrip()),
                      const SizedBox(height: 24),
                    ],
                    BtReveal(index: 2, child: _buildLogsHeader()),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const BtSkeletonList(count: 4)
                    else if (_filteredLogs.isEmpty)
                      _buildEmptyState()
                    else
                      _buildDateGroupedLogs(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  static const _groupLabels = {
    'Today': 'TODAY',
    'Yesterday': 'YESTERDAY',
    'This Week': 'THIS WEEK',
    'Older': 'OLDER',
  };
  Widget _buildDateGroupedLogs(BuildContext context) {
    final groups = _groupByDate(_filteredLogs);
    final widgets = <Widget>[];
    var revealIndex = 3;
    for (final entry in groups.entries) {
      final groupLabel = entry.key;
      final logs = entry.value;
      final collapsed = _collapsedGroups[groupLabel] ?? (groupLabel != 'Today');
      widgets.add(
        Semantics(
          button: true,
          expanded: !collapsed,
          child: BtPressable(
            scale: .99,
            onTap: () => setState(() => _collapsedGroups[groupLabel] = !collapsed),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
              child: Row(
                children: [
                  Text(_groupLabels[groupLabel] ?? groupLabel.toUpperCase(), style: BtText.mono(context, color: Bt.ink2)),
                  const SizedBox(width: 8),
                  Text('${logs.length} ${logs.length == 1 ? "entry" : "entries"}', style: BtText.caption(context)),
                  const Spacer(),
                  AnimatedRotation(
                    duration: Bt.fast,
                    curve: Bt.ease,
                    turns: collapsed ? 0 : 0.5,
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: Bt.ink3, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (!collapsed) {
        for (var i = 0; i < logs.length; i++) {
          final item = _TimelineRow(
            dotColor: _statusColor(logs[i]['paymentStatus'] as PaymentStatus? ?? PaymentStatus.pending),
            isLast: i == logs.length - 1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _logItem(context, logs[i]),
            ),
          );
          widgets.add(revealIndex < 10 ? BtReveal(index: revealIndex++, child: item) : item);
        }
        widgets.add(const SizedBox(height: 6));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }
  Color _statusColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:
        return Bt.greenBright;
      case PaymentStatus.partial:
        return Bt.amberBright;
      case PaymentStatus.overdue:
        return Bt.redBright;
      default:
        return Bt.redBright;
    }
  }
  Widget _buildSummaryCard() {
    final net = _totalAdded - _totalUsed;
    final bt = context.bt;
    Widget stat(String label, String value, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: BtText.caption(context, color: Bt.onNoir2)),
              const SizedBox(height: 2),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.num(BtText.headline(context).copyWith(color: color))),
            ],
          ),
        );
    return BtCard(
      variant: BtCardVariant.ink,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL ${_itemType.toUpperCase()} STOCK', style: BtText.mono(context, color: bt.accent)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              BtCountUp(
                value: net,
                format: (v) => _formatQty(net % 1 == 0 ? v.roundToDouble() : double.parse(v.toStringAsFixed(2))),
                style: BtText.d0(context, color: Bt.bone),
              ),
              const SizedBox(width: 8),
              Text(_unitLabel, style: BtText.body(context, color: Bt.onNoir2)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat('Added', '+${_formatQty(_totalAdded)}', Bt.greenBright),
              stat('Used', _totalUsed > 0 ? '-${_formatQty(_totalUsed)}' : '0', Bt.amberBright),
              stat('Net', _formatQty(net), Bt.bone),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildPaymentStatusStrip() {
    int fullyPaid = 0, partial = 0, notPaid = 0;
    double fullyPaidTotal = 0, partialTotal = 0, notPaidTotal = 0;
    for (final l in _allLogs) {
      final ps = l['paymentStatus'] as PaymentStatus?;
      final bill = l['billAmount'] as double? ?? 0;
      if (ps == PaymentStatus.paid) {
        fullyPaid++;
        fullyPaidTotal += bill;
      } else if (ps == PaymentStatus.partial) {
        partial++;
        partialTotal += bill;
      } else {
        notPaid++;
        notPaidTotal += bill;
      }
    }
    Widget card(String label, int count, double total, Color dot, Color text) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Bt.card,
            borderRadius: BorderRadius.circular(Bt.rTile + 2),
            boxShadow: Bt.shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: text, weight: FontWeight.w600))),
                ],
              ),
              const SizedBox(height: 10),
              Text('$count item${count == 1 ? '' : 's'}', style: BtText.num(BtText.title(context, size: 17))),
              const SizedBox(height: 1),
              Text(formatCurrency(total), maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.num(BtText.caption(context, color: text, weight: FontWeight.w600))),
            ],
          ),
        ),
      );
    }
    return Row(
      children: [
        card('Fully Paid', fullyPaid, fullyPaidTotal, Bt.greenBright, Bt.green),
        const SizedBox(width: 8),
        card('Partial', partial, partialTotal, Bt.amberBright, Bt.amber),
        const SizedBox(width: 8),
        card('Not Paid', notPaid, notPaidTotal, Bt.redBright, Bt.red),
      ],
    );
  }
  Widget _buildLogsHeader() {
    const filters = ['All', '+ Added', '- Used'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MOVEMENT LOGS', style: BtText.mono(context)),
        const SizedBox(height: 4),
        Text('Tracking historical distribution', style: BtText.title(context, size: 19)),
        const SizedBox(height: 12),
        BtSegmented<int>(
          segments: {for (var i = 0; i < filters.length; i++) i: filters[i]},
          value: _filterIndex,
          onChanged: (i) => setState(() => _filterIndex = i),
        ),
      ],
    );
  }
  Widget _buildEmptyState() {
    String title, subtitle;
    IconData icon;
    switch (_itemType) {
      case 'labour':
        title = 'No Labour Records Yet';
        subtitle = 'Add attendance or wage entries to see them here.';
        icon = Icons.people_outline;
        break;
      case 'equipment':
        title = 'No Equipment Entries Yet';
        subtitle = 'Add usage or payment entries to see them here.';
        icon = Icons.construction_outlined;
        break;
      default:
        title = 'No Material Transactions Yet';
        subtitle = 'Add material entries to start tracking transactions.';
        icon = Icons.inventory_2_outlined;
    }
    return BtEmpty(
      icon: icon,
      title: title,
      message: subtitle,
      action: _primaryActionLabel,
      onAction: () => Navigator.pushNamed(
        context,
        _addRoute,
        arguments: {'type': _itemType, 'prefill': _itemName},
      ).then((_) => _fetchRealLogs()),
    );
  }
  String _formatLogAmount(Map<String, dynamic> log) {
    final String amountStr = log['amount'] as String? ?? '';
    if (amountStr.isEmpty) return '';
    final String sign = amountStr.startsWith('+')
        ? '+'
        : (amountStr.startsWith('-') ? '-' : '');
    final String numStr = amountStr
        .replaceAll('+', '')
        .replaceAll('-', '')
        .trim();
    final double qty = double.tryParse(numStr) ?? 0;
    final String qtyFormatted = qty % 1 == 0
        ? qty.toInt().toString()
        : qty.toString();
    final String rawUnit = (log['unit'] ?? '').toString().trim().toLowerCase();
    final String logCategory = log['category'] as String? ?? _itemType;
    final bool isInvalidUnit = const [
      'kg',
      'bag',
      'ton',
      'mt',
      'truck',
    ].contains(rawUnit);
    final String parsedUnit =
        (isInvalidUnit &&
            (logCategory == 'labour' || logCategory == 'equipment'))
        ? ''
        : rawUnit;
    if (logCategory == 'labour') {
      String unitLabel = 'workers';
      if (parsedUnit == 'hour' || parsedUnit == 'hours') {
        unitLabel = qty == 1 ? 'hour' : 'hours';
      } else if (parsedUnit == 'day' || parsedUnit == 'days') {
        unitLabel = qty == 1 ? 'day' : 'days';
      } else if (parsedUnit == 'worker' ||
          parsedUnit == 'workers' ||
          parsedUnit.isEmpty) {
        unitLabel = qty == 1 ? 'worker' : 'workers';
      } else {
        unitLabel = parsedUnit;
      }
      return '$sign$qtyFormatted $unitLabel';
    } else if (logCategory == 'equipment') {
      String unitLabel = 'units';
      if (parsedUnit == 'hour' || parsedUnit == 'hours') {
        unitLabel = qty == 1 ? 'hour' : 'hours';
      } else if (parsedUnit == 'day' || parsedUnit == 'days') {
        unitLabel = qty == 1 ? 'day' : 'days';
      } else if (parsedUnit.isNotEmpty) {
        unitLabel = parsedUnit;
      }
      return '$sign$qtyFormatted $unitLabel';
    } else {
      if (parsedUnit.isEmpty || parsedUnit == 'unit' || parsedUnit == 'units') {
        return '$sign$qtyFormatted units';
      }
      String unitLabel = parsedUnit;
      if (qty > 1) {
        if (parsedUnit == 'bag') {
          unitLabel = 'bags';
        } else if (parsedUnit == 'ton') {
          unitLabel = 'tons';
        } else if (parsedUnit == 'truck') {
          unitLabel = 'trucks';
        } else if (parsedUnit == 'block') {
          unitLabel = 'blocks';
        }
      }
      return '$sign$qtyFormatted $unitLabel';
    }
  }
  Widget _logItem(BuildContext context, Map<String, dynamic> log) {
    final isPositive = log['isPositive'] as bool? ?? true;
    final receipt = log['receipt'] as String?;
    final payStatus =
        log['paymentStatus'] as PaymentStatus? ?? PaymentStatus.pending;
    final billAmt = log['billAmount'] as double? ?? 0;
    final paidAmt = log['paidAmount'] as double? ?? 0;
    final canSettle =
        payStatus == PaymentStatus.pending ||
        payStatus == PaymentStatus.partial ||
        payStatus == PaymentStatus.overdue;
    final logCategory = log['category'] as String? ?? _itemType;
    final String statusLabel;
    final BtTone statusTone;
    switch (payStatus) {
      case PaymentStatus.paid:
        statusLabel = 'Paid';
        statusTone = BtTone.green;
        break;
      case PaymentStatus.partial:
        statusLabel = 'Partial';
        statusTone = BtTone.amber;
        break;
      case PaymentStatus.overdue:
        statusLabel = 'Overdue';
        statusTone = BtTone.red;
        break;
      default:
        statusLabel = 'Pending';
        statusTone = BtTone.red;
    }
    final VoidCallback? onRecordPayment = canSettle
        ? () {
                            final projectProvider = context
                                .read<ProjectProvider>();
                            String pName = 'Unknown Project';
                            String pId = log['projectId'] ?? '';
                            final matchedProj = projectProvider.projects.where(
                              (p) => p.id == pId,
                            );
                            if (matchedProj.isNotEmpty) {
                              pName = matchedProj.first.name;
                            }
                            final payArgs = {
                              'id': log['id'] ?? '',
                              'projectId': pId,
                              'projectName': pName,
                              'itemId': log['itemId'] ?? '',
                              'itemName': log['title'] ?? _itemName,
                              'itemType': logCategory,
                              'quantity': log['quantity'] ?? 0.0,
                              'rate': log['rate'] ?? 0.0,
                              'totalAmount': billAmt,
                              'paidAmount': paidAmt,
                              'outstandingAmount': (billAmt - paidAmt).clamp(
                                0.0,
                                double.infinity,
                              ),
                              'paymentStatus': log['paymentStatus'],
                              'receipt': log['receipt'],
                              'transactionDetails': log,
                            };
                            Navigator.pushNamed(
                              context,
                              '/fulfillment-payment',
                              arguments: payArgs,
                            ).then((updated) {
                              if (updated == true && mounted) {
                                _fetchRealLogs();
                              }
                            });
                          }
        : null;
    return BtCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      onTap: () =>
            Navigator.pushNamed(
              context,
              '/entry-detail',
              arguments: {
                ...log,
                'id': log['id'],
                'title': log['title'],
                'ref': log['ref'],
                'amount': log['amount'],
                'date': log['rawDate'] ?? log['date'],
                'isPositive': isPositive,
                'type': logCategory,
                'name': log['title'] ?? _itemName,
                'receipt': receipt,
                'attachment': log['attachment'],
                'createdBy': log['createdBy'] ?? '',
                'projectId': log['projectId'] ?? '',
                'status': log['status'] ?? 'pending',
                'paymentStatus': payStatus,
                'billAmount': billAmt,
                'paidAmount': paidAmt,
                'supplier': log['supplier'] ?? '',
                'paymentMethod': log['method'] ?? '',
                'lastUpdated':
                    log['rawLastUpdated'] ??
                    log['lastUpdated'] ??
                    log['date'] ??
                    '',
                'paymentHistory': log['paymentHistory'],
              },
            ).then((_) {
              _fetchRealLogs();
            }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BtTile(icon: (log['icon'] as IconData?) ?? BtTypeTile.iconFor(logCategory), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log['title'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BtText.headline(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '$_itemName • ${log['ref'] ?? ''}',
                        if ((log['supplier'] as String? ?? '').isNotEmpty) log['supplier'] as String,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BtText.caption(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatLogAmount(log),
                    style: BtText.num(BtText.headline(context).copyWith(color: isPositive ? Bt.ink : Bt.red)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (receipt != null && receipt.isNotEmpty) ...[
                        const Icon(Icons.attach_file_rounded, color: Bt.ink3, size: 13),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        _formatRelativeTime(log['rawDate'] ?? log['date']),
                        style: BtText.caption(context),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BtBadge(label: statusLabel, tone: statusTone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  billAmt > 0
                      ? '${formatCurrency(paidAmt)} / ${formatCurrency(billAmt)}'
                      : formatCurrency(paidAmt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BtText.num(BtText.caption(context, weight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              if (canSettle)
                BtButton(
                  label: 'Record Payment',
                  icon: Icons.receipt_long_outlined,
                  variant: BtButtonVariant.secondary,
                  small: true,
                  expand: false,
                  onPressed: onRecordPayment,
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Bt.ink3, size: 15),
                    const SizedBox(width: 5),
                    Text('Settled', style: BtText.caption(context, weight: FontWeight.w600)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Timeline rail (Transaction-Logs board): a status dot + a hairline joining the events.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.child, required this.dotColor, required this.isLast});
  final Widget child;
  final Color dotColor;
  final bool isLast;
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Bt.ground, width: 2),
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 1.5, color: Bt.line)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
