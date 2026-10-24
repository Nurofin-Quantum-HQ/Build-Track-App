import 'package:buildtrack_mobile/design/design.dart';
import 'dart:async';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/controller/inventory_provider.dart';
import 'package:buildtrack_mobile/models/inventory_model.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/controller/entry_permissions.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';
import 'package:provider/provider.dart';

class InventoryScreen extends StatelessWidget {
  InventoryScreen({super.key});
  final GlobalKey<ShowCaseWidgetState> _showcaseKey = GlobalKey<ShowCaseWidgetState>();

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      key: _showcaseKey,
      globalTooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.skip, 
          backgroundColor: Colors.transparent, 
          textStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          onTap: () {
            UserSession.skipTour();
            _showcaseKey.currentState?.dismiss();
          }
        ), 
        TooltipActionButton(
          type: TooltipDefaultActionType.next, 
          backgroundColor: Bt.ink,
          textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        )
      ], 
      enableAutoScroll: true,
      // Inventory is no longer part of the guided app tour (NavController.tourOrder),
      // so finishing its own tour only marks it visited — it must not chain to
      // another tab (that used to pull an active app tour through Inventory).
      onFinish: () => UserSession.markModuleVisited('InventoryScreen'),
      builder: (context) => const _InventoryScreenContent(),
    );
  }
}

class _InventoryScreenContent extends StatefulWidget {
  const _InventoryScreenContent();
  @override
  State<_InventoryScreenContent> createState() => _InventoryScreenContentState();
}

class _InventoryScreenContentState extends State<_InventoryScreenContent> {
  final GlobalKey _helpKey = GlobalKey();
  static final Color _blue = AppColors.primary;
  final _pageController = PageController();
  int _tabIndex = 0;
  final _searchCtrl = TextEditingController();
  String? _selectedProjectId;
  Timer? _debounce;
  String _matCategory = 'All';
  String _labCategory = 'All';
  String _eqpCategory = 'All';
  String _matDateFilter = 'All';
  String _labDateFilter = 'All';
  String _eqpDateFilter = 'All';
  DateTimeRange? _matCustomRange;
  DateTimeRange? _labCustomRange;
  DateTimeRange? _eqpCustomRange;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadInventory(_selectedProjectId ?? '');
      if (!UserSession.hasSkippedTour && !UserSession.visitedModules.contains('InventoryScreen')) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            ShowCaseWidget.of(context).startShowCase([
              ShowcaseKeys.inventoryProjectContext,
              ShowcaseKeys.inventoryFilters,
              ShowcaseKeys.inventoryAdd,
              ShowcaseKeys.inventoryMaterials,
              ShowcaseKeys.inventoryTools,
              ShowcaseKeys.inventoryStats,
              _helpKey,
            ]);
          }
        });
      }
    });
  }
  @override
  void dispose() {
    _debounce?.cancel();
    _pageController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
  List<_PurchaseRecord> _flatten(List<InventoryItem> items) {
    final records = <_PurchaseRecord>[];
    for (final item in items) {
      for (final raw in item.transactions) {
        final tx = raw is Map ? Map<String, dynamic>.from(raw) : null;
        if (tx == null) {
          continue;
        }
        final approvalStatus = (tx['approvalStatus'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        if (approvalStatus != 'approved') {
          continue;
        }
        DateTime date = DateTime.now();
        for (final key in ['date', 'createdAt', 'purchaseDate', 'updatedAt']) {
          final val = tx[key];
          if (val is String && val.isNotEmpty) {
            try {
              date = DateTime.parse(val).toLocal();
              break;
            } catch (_) {}
          }
        }
        String vendor;
        if (item.category == 'labour') {
          vendor =
              (tx['workerName'] ??
                      tx['worker'] ??
                      tx['contractor'] ??
                      tx['supplier'] ??
                      '')
                  .toString()
                  .trim();
        } else if (item.category == 'equipment') {
          vendor =
              (tx['operatorName'] ??
                      tx['operator'] ??
                      tx['rentalSupplier'] ??
                      tx['supplier'] ??
                      '')
                  .toString()
                  .trim();
        } else {
          vendor = (tx['supplier'] ?? tx['vendor'] ?? '').toString().trim();
        }
        final qty =
            (tx['quantity'] as num?)?.toDouble() ??
            (tx['days'] as num?)?.toDouble() ??
            (tx['hours'] as num?)?.toDouble() ??
            0.0;
        final rate =
            (tx['rate'] as num?)?.toDouble() ??
            (tx['dailyWage'] as num?)?.toDouble() ??
            (tx['hourlyRate'] as num?)?.toDouble() ??
            0.0;
        double bill = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        if (bill == 0 && qty > 0 && rate > 0) {
          bill = qty * rate;
        }
        final paid = (tx['paidAmount'] as num?)?.toDouble() ?? 0.0;
        final sStr = (tx['paymentStatus'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        PaymentStatus payStatus;
        if (sStr == 'paid') {
          payStatus = PaymentStatus.paid;
        } else if (sStr == 'partial') {
          payStatus = PaymentStatus.partial;
        } else if (sStr == 'overdue') {
          payStatus = PaymentStatus.overdue;
        } else {
          payStatus = PaymentStatus.pending;
        }
        const skipCats = {
          'unknown',
          'material',
          'labour',
          'equipment',
          'materials',
          'purchase',
          'general',
          'others',
          'na',
          'n/a',
        };
        String catName = '';
        for (final key in [
          'categoryName',
          'materialType',
          'workType',
          'equipmentType',
        ]) {
          final val = (tx[key] ?? '').toString().trim();
          if (val.isNotEmpty && !skipCats.contains(val.toLowerCase())) {
            catName = val;
            break;
          }
        }
        debugPrint('FLATTEN TX');
        debugPrint(tx.toString());
        records.add(
          _PurchaseRecord(
            itemId: item.id,
            itemName: item.name,
            txId: tx['_id']?.toString() ?? '',
            date: date,
            brand: (tx['brand'] ?? '').toString().trim(),
            vendor: vendor,
            quantity: qty,
            unit: (tx['unit'] ?? item.unit).toString().trim(),
            rate: rate,
            billAmount: bill,
            paidAmount: paid,
            payStatus: payStatus,
            categoryName: catName,
            type: item.category,
            rawTx: tx,
          ),
        );
      }
    }
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }
  List<_PurchaseRecord> _filterDate(
    List<_PurchaseRecord> records,
    String filter,
    DateTimeRange? custom,
  ) {
    if (filter == 'All') {
      return records;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return records.where((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      switch (filter) {
        case 'Today':
          return d == today;
        case 'Yesterday':
          return d == today.subtract(const Duration(days: 1));
        case 'This Week':
          final wStart = today.subtract(Duration(days: today.weekday - 1));
          return !d.isBefore(wStart);
        case 'This Month':
          return d.year == now.year && d.month == now.month;
        case 'Last Month':
          final lm = DateTime(now.year, now.month - 1);
          return d.year == lm.year && d.month == lm.month;
        case 'Last 3 Months':
          return !d.isBefore(today.subtract(const Duration(days: 90)));
        case 'This Year':
          return d.year == now.year;
        case 'Custom':
          if (custom == null) {
            return true;
          }
          final endDay = DateTime(
            custom.end.year,
            custom.end.month,
            custom.end.day,
          );
          return !d.isBefore(custom.start) && !d.isAfter(endDay);
        default:
          return true;
      }
    }).toList();
  }
  List<_PurchaseRecord> _filterCat(List<_PurchaseRecord> records, String cat) {
    if (cat == 'All') {
      return records;
    }
    return records.where((r) => r.categoryName == cat).toList();
  }
  List<_PurchaseRecord> _filterSearch(
    List<_PurchaseRecord> records,
    String query,
  ) {
    final q = query.trim();
    if (q.isEmpty) {
      return records;
    }
    final lower = q.toLowerCase();
    return records
        .where(
          (r) =>
              r.itemName.toLowerCase().contains(lower) ||
              r.brand.toLowerCase().contains(lower) ||
              r.vendor.toLowerCase().contains(lower) ||
              r.categoryName.toLowerCase().contains(lower),
        )
        .toList();
  }
  List<_DateGroup> _groupByDate(List<_PurchaseRecord> records) {
    final map = <String, List<_PurchaseRecord>>{};
    for (final r in records) {
      final key =
          '${r.date.year}-'
          '${r.date.month.toString().padLeft(2, '0')}-'
          '${r.date.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(r);
    }
    final groups = map.entries.map((entry) {
      final parts = entry.key.split('-');
      final d = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return _DateGroup(
        label: _formatGroupDate(d),
        date: d,
        records: entry.value,
      );
    }).toList();
    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }
  static String _formatGroupDate(DateTime d) {
    const months = [
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
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
  List<String> _buildChips(List<_PurchaseRecord> records) {
    const skipSet = {
      'unknown',
      'material',
      'labour',
      'equipment',
      'materials',
      'purchase',
      'general',
      'others',
      'na',
      'n/a',
    };
    final cats = <String>{};
    for (final r in records) {
      if (r.categoryName.isNotEmpty &&
          !skipSet.contains(r.categoryName.toLowerCase())) {
        cats.add(r.categoryName);
      }
    }
    return ['All', ...(cats.toList()..sort())];
  }
  List<_KpiData> _buildKpis(List<_PurchaseRecord> records, String type) {
    double totalQty = 0;
    double totalCost = 0;
    double totalPend = 0;
    final vendors = <String>{};
    for (final r in records) {
      totalQty += r.quantity;
      totalCost += r.billAmount;
      if (r.payStatus != PaymentStatus.paid) {
        totalPend += (r.billAmount - r.paidAmount).clamp(0.0, double.infinity);
      }
      if (r.vendor.isNotEmpty) {
        vendors.add(r.vendor.toLowerCase());
      }
    }
    const alertRed = Color(0xFFC01048);
    const green = Color(0xFF067647);
    if (type == 'labour') {
      return [
        _KpiData('Total Days', _fmtNum(totalQty), Icons.groups_outlined, _blue),
        _KpiData(
          'Labour Cost',
          formatCurrency(totalCost),
          Icons.payments_outlined,
          AppColors.primaryPurple,
        ),
        _KpiData(
          'Pending Wages',
          formatCurrency(totalPend),
          Icons.pending_actions_outlined,
          alertRed,
          isAlert: totalPend > 0,
        ),
        _KpiData(
          'Contractors',
          '${vendors.length}',
          Icons.business_center_outlined,
          green,
        ),
      ];
    } else if (type == 'equipment') {
      return [
        _KpiData(
          'Total Hours',
          _fmtNum(totalQty),
          Icons.precision_manufacturing_outlined,
          _blue,
        ),
        _KpiData(
          'Rental Cost',
          formatCurrency(totalCost),
          Icons.account_balance_wallet_outlined,
          AppColors.primaryPurple,
        ),
        _KpiData(
          'Pending Pay',
          formatCurrency(totalPend),
          Icons.pending_actions_outlined,
          alertRed,
          isAlert: totalPend > 0,
        ),
        _KpiData(
          'Operators',
          '${vendors.length}',
          Icons.engineering_outlined,
          green,
        ),
      ];
    } else {
      return [
        _KpiData(
          'Total Units',
          _fmtNum(totalQty),
          Icons.inventory_2_outlined,
          _blue,
        ),
        _KpiData(
          'Purchase Value',
          formatCurrency(totalCost),
          Icons.account_balance_wallet_outlined,
          AppColors.primaryPurple,
        ),
        _KpiData(
          'Pending Pay',
          formatCurrency(totalPend),
          Icons.pending_actions_outlined,
          alertRed,
          isAlert: totalPend > 0,
        ),
        _KpiData('Vendors', '${vendors.length}', Icons.store_outlined, green),
      ];
    }
  }
  static String _fmtNum(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(1);
  void _showProjectSelector(BuildContext ctx) {
    final projects = ctx.read<ProjectProvider>().projects;
    final allItems = ['All Active Projects', ...projects.map((p) => p.name)];
    final idMap = <String, String?>{for (final p in projects) p.name: p.id};
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ProjectSelectorSheet(
        allItems: allItems,
        idMap: idMap,
        selectedId: _selectedProjectId,
        onSelect: (id) {
          setState(() => _selectedProjectId = id);
          ctx.read<InventoryProvider>().loadInventory(id ?? '');
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Bt.ground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BtHero(
            padding: EdgeInsets.fromLTRB(Bt.gutter, top + 10, Bt.gutter, 22 + 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('STOCK & PURCHASES', style: BtText.mono(context, color: Bt.onNoir2)),
                          const SizedBox(height: 4),
                          BtReveal(child: Text('Inventory', style: BtText.d1(context, color: Bt.bone))),
                        ],
                      ),
                    ),
                    Showcase(
                      key: _helpKey,
                      description: 'Tap here anytime to replay this tour and get help.',
                      tooltipBackgroundColor: Bt.ink,
                      textColor: Colors.white,
                      tooltipBorderRadius: BorderRadius.circular(16),
                      tooltipPadding: const EdgeInsets.all(16),
                      child: BtIconButton(
                        icon: Icons.help_outline_rounded,
                        semantic: 'App guidelines',
                        color: Bt.bone,
                        background: Colors.white.withValues(alpha: .09),
                        onTap: () {
                          ShowCaseWidget.of(context).startShowCase([
                            ShowcaseKeys.inventoryProjectContext,
                            ShowcaseKeys.inventoryFilters,
                            ShowcaseKeys.inventoryAdd,
                            _helpKey,
                          ]);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Semantics(
                      button: true,
                      label: 'Account',
                      child: BtPressable(
                        scale: .92,
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                        child: const Padding(padding: EdgeInsets.all(4), child: ProfileAvatar(radius: 18)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                BtReveal(
                  index: 1,
                  child: Showcase(
                    key: ShowcaseKeys.inventoryProjectContext,
                    description: 'Select a project to view its specific materials, equipment, and updates.',
                    tooltipBackgroundColor: Bt.ink,
                    textColor: Colors.white,
                    tooltipBorderRadius: BorderRadius.circular(16),
                    tooltipPadding: const EdgeInsets.all(16),
                    child: _buildProjectSelector(),
                  ),
                ),
                const SizedBox(height: 14),
                BtReveal(index: 2, child: _buildTabBar()),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -26),
              child: Container(
                decoration: const BoxDecoration(
                  color: Bt.ground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: BtReveal(index: 3, child: _buildSearchBar()),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _tabIndex = i),
                        children: [
                          _buildMaterialsTab(context),
                          _buildLabourTab(context),
                          _buildEquipmentTab(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(),
    );
  }
  Widget _buildProjectSelector() {
    final projects = context.watch<ProjectProvider>().projects;
    final sel = _selectedProjectId == null
        ? null
        : projects.cast<ProjectModel?>().firstWhere(
            (p) => p?.id == _selectedProjectId,
            orElse: () => null,
          );
    final label = sel?.name ?? 'All Active Projects';
    return BtPressable(
      onTap: () => _showProjectSelector(context),
      semanticLabel: 'Project context: $label',
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.bt.accent.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.folder_outlined, color: context.bt.accent, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PROJECT CONTEXT', style: BtText.mono(context, color: Bt.onNoir2, size: 9.5)),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: BtText.headline(context).copyWith(color: Bt.bone, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Bt.onNoir2, size: 22),
          ],
        ),
      ),
    );
  }
  String get _searchHint {
    switch (_tabIndex) {
      case 1:
        return 'Search by worker or contractor…';
      case 2:
        return 'Search by equipment or supplier…';
      default:
        return 'Search by name, vendor, brand…';
    }
  }
  Widget _buildSearchBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.circular(Bt.rInput),
        boxShadow: Bt.shadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Bt.ink3, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) {
                if (_debounce?.isActive ?? false) {
                  _debounce!.cancel();
                }
                _debounce = Timer(
                  const Duration(milliseconds: 400),
                  () => setState(() {}),
                );
              },
              cursorColor: Bt.ink,
              decoration: InputDecoration(
                hintText: _searchHint,
                hintStyle: BtText.subhead(context, color: Bt.placeholder),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              style: BtText.body(context).copyWith(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTabBar() {
    const icons = [
      Icons.architecture,
      Icons.people_outline,
      Icons.construction_outlined,
    ];
    const labels = ['Materials', 'Labour', 'Equipment'];
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: Bt.medium,
            curve: Bt.ease,
            alignment: Alignment(-1 + _tabIndex.toDouble(), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Bt.bone,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(3, (i) {
              final active = i == _tabIndex;
              final color = active ? Bt.ink : Bt.onNoir2;
              Widget tabChild = Semantics(
                button: true,
                selected: active,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _tabIndex = i);
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icons[i], color: color, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: AnimatedDefaultTextStyle(
                            duration: Bt.fast,
                            style: BtText.subhead(context, color: color, weight: active ? FontWeight.w600 : FontWeight.w500),
                            child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              if (i == 0) {
                tabChild = Showcase(
                  key: ShowcaseKeys.inventoryMaterials,
                  description: 'View your materials inventory here',
                  tooltipBackgroundColor: Bt.ink,
                  textColor: Colors.white,
                  tooltipBorderRadius: BorderRadius.circular(16),
                  tooltipPadding: const EdgeInsets.all(16),
                  child: tabChild,
                );
              } else if (i == 2) {
                tabChild = Showcase(
                  key: ShowcaseKeys.inventoryTools,
                  description: 'View your equipment and tools inventory here',
                  tooltipBackgroundColor: Bt.ink,
                  textColor: Colors.white,
                  tooltipBorderRadius: BorderRadius.circular(16),
                  tooltipPadding: const EdgeInsets.all(16),
                  child: tabChild,
                );
              }
              return Expanded(child: tabChild);
            }),
          ),
        ],
      ),
    );
  }
  Widget _buildMaterialsTab(BuildContext ctx) {
    final provider = ctx.watch<InventoryProvider>();
    if (provider.isLoading) {
      return const BtPageLoader(label: 'Loading inventory…');
    }
    final all = provider.materialInventory;
    // Load failed and nothing to show: say so instead of an empty "no entries" list.
    if (provider.hasError && all.isEmpty) return _InventoryLoadError(provider: provider);
    final flat = _flatten(all);
    final chips = _buildChips(flat);
    final filtered = _filterDate(
      _filterCat(_filterSearch(flat, _searchCtrl.text), _matCategory),
      _matDateFilter,
      _matCustomRange,
    );
    final groups = _groupByDate(filtered);
    final kpis = _buildKpis(filtered, 'material');
    return _withLoadErrorBanner(provider, _TimelineTabContent(
      groups: groups,
      kpis: kpis,
      chips: chips,
      activeChip: _matCategory,
      dateFilter: _matDateFilter,
      type: 'material',
      emptyTitle: 'No Material Purchases',
      emptySubtitle: 'Add your first material purchase to get started.',
      emptyRoute: '/add-entry',
      selectedProjectId: _selectedProjectId,
      onChipChange: (c) => setState(() => _matCategory = c),
      onDateFilter: (f, cr) => setState(() {
        _matDateFilter = f;
        _matCustomRange = cr;
      }),
      onNavigate: (route, args) => _openAndReload(ctx, route, args),
    ));
  }
  /// A failed refresh keeps the previous items; say they may be out of date.
  Widget _withLoadErrorBanner(InventoryProvider provider, Widget content) {
    if (!provider.hasError) return content;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: BtCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(children: [
              const Icon(Icons.cloud_off_rounded, size: 18, color: Bt.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Couldn't refresh — showing the last loaded items.",
                  style: BtText.caption(context, color: Bt.ink2),
                ),
              ),
              BtButton(
                label: 'Retry',
                variant: BtButtonVariant.quiet,
                small: true,
                expand: false,
                onPressed: provider.retry,
              ),
            ]),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
  /// Add More / Edit open an entry form; it pops with `true` after saving.
  Future<void> _openAndReload(
    BuildContext ctx,
    String route,
    Map<String, dynamic> args,
  ) async {
    final result = await Navigator.pushNamed(ctx, route, arguments: args);
    if (!mounted) return;
    if ((result == true || result == 'deleted') &&
        _selectedProjectId != null &&
        _selectedProjectId!.isNotEmpty) {
      context.read<InventoryProvider>().loadInventory(_selectedProjectId!);
    }
  }
  Widget _buildLabourTab(BuildContext ctx) {
    final provider = ctx.watch<InventoryProvider>();
    if (provider.isLoading) {
      return const BtPageLoader(label: 'Loading inventory…');
    }
    final all = provider.labourInventory;
    // Load failed and nothing to show: say so instead of an empty "no entries" list.
    if (provider.hasError && all.isEmpty) return _InventoryLoadError(provider: provider);
    final flat = _flatten(all);
    final chips = _buildChips(flat);
    final filtered = _filterDate(
      _filterCat(_filterSearch(flat, _searchCtrl.text), _labCategory),
      _labDateFilter,
      _labCustomRange,
    );
    final groups = _groupByDate(filtered);
    final kpis = _buildKpis(filtered, 'labour');
    return _withLoadErrorBanner(provider, _TimelineTabContent(
      groups: groups,
      kpis: kpis,
      chips: chips,
      activeChip: _labCategory,
      dateFilter: _labDateFilter,
      type: 'labour',
      emptyTitle: 'No Labour Entries',
      emptySubtitle: 'Add your first labour entry to track workforce costs.',
      emptyRoute: '/add-entry',
      selectedProjectId: _selectedProjectId,
      onChipChange: (c) => setState(() => _labCategory = c),
      onDateFilter: (f, cr) => setState(() {
        _labDateFilter = f;
        _labCustomRange = cr;
      }),
      onNavigate: (route, args) => _openAndReload(ctx, route, args),
    ));
  }
  Widget _buildEquipmentTab(BuildContext ctx) {
    final provider = ctx.watch<InventoryProvider>();
    if (provider.isLoading) {
      return const BtPageLoader(label: 'Loading inventory…');
    }
    final all = provider.equipmentInventory;
    // Load failed and nothing to show: say so instead of an empty "no entries" list.
    if (provider.hasError && all.isEmpty) return _InventoryLoadError(provider: provider);
    final flat = _flatten(all);
    final chips = _buildChips(flat);
    final filtered = _filterDate(
      _filterCat(_filterSearch(flat, _searchCtrl.text), _eqpCategory),
      _eqpDateFilter,
      _eqpCustomRange,
    );
    final groups = _groupByDate(filtered);
    final kpis = _buildKpis(filtered, 'equipment');
    return _withLoadErrorBanner(provider, _TimelineTabContent(
      groups: groups,
      kpis: kpis,
      chips: chips,
      activeChip: _eqpCategory,
      dateFilter: _eqpDateFilter,
      type: 'equipment',
      emptyTitle: 'No Equipment Entries',
      emptySubtitle: 'Add your first equipment entry to track asset usage.',
      emptyRoute: '/add-entry',
      selectedProjectId: _selectedProjectId,
      onChipChange: (c) => setState(() => _eqpCategory = c),
      onDateFilter: (f, cr) => setState(() {
        _eqpDateFilter = f;
        _eqpCustomRange = cr;
      }),
      onNavigate: (route, args) => _openAndReload(ctx, route, args),
    ));
  }
}
class _PurchaseRecord {
  final String itemId;
  final String itemName;
  final String txId;
  final DateTime date;
  final String brand;
  final String vendor;
  final double quantity;
  final String unit;
  final double rate;
  final double billAmount;
  final double paidAmount;
  final PaymentStatus payStatus;
  final String categoryName;
  final String type;
  final Map<String, dynamic> rawTx;
  String get approvalStatus =>
      (rawTx['approvalStatus'] ?? 'pending').toString().toLowerCase();
  _PurchaseRecord({
    required this.itemId,
    required this.itemName,
    required this.txId,
    required this.date,
    required this.brand,
    required this.vendor,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.billAmount,
    required this.paidAmount,
    required this.payStatus,
    required this.categoryName,
    required this.type,
    required this.rawTx,
  });
}
class _DateGroup {
  final String label;
  final DateTime date;
  final List<_PurchaseRecord> records;
  _DateGroup({required this.label, required this.date, required this.records});
}
class _KpiData {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isAlert;
  const _KpiData(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.isAlert = false,
  });
}
class _TimelineTabContent extends StatefulWidget {
  final List<_DateGroup> groups;
  final List<_KpiData> kpis;
  final List<String> chips;
  final String activeChip;
  final String dateFilter;
  final String type;
  final String emptyTitle;
  final String emptySubtitle;
  final String emptyRoute;
  final String? selectedProjectId;
  final ValueChanged<String> onChipChange;
  final void Function(String filter, DateTimeRange? custom) onDateFilter;
  final void Function(String route, Map<String, dynamic> args) onNavigate;
  const _TimelineTabContent({
    required this.groups,
    required this.kpis,
    required this.chips,
    required this.activeChip,
    required this.dateFilter,
    required this.type,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyRoute,
    required this.selectedProjectId,
    required this.onChipChange,
    required this.onDateFilter,
    required this.onNavigate,
  });
  @override
  State<_TimelineTabContent> createState() => _TimelineTabContentState();
}
class _TimelineTabContentState extends State<_TimelineTabContent> {
  final Map<String, bool> _collapsed = {};
  IconData get _typeIcon {
    switch (widget.type) {
      case 'labour':
        return Icons.people_outline;
      case 'equipment':
        return Icons.construction_outlined;
      default:
        return Icons.architecture;
    }
  }
  List<Widget> _buildSlivers() {
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: widget.type == 'material'
              ? Showcase(
                  key: ShowcaseKeys.inventoryStats,
                  description: 'Track total loads, equipment count, and overall inventory metrics for this project.',
                  tooltipBackgroundColor: Bt.ink,
                  textColor: Colors.white,
                  tooltipBorderRadius: BorderRadius.circular(16),
                  tooltipPadding: const EdgeInsets.all(16),
                  child: _KpiStrip(kpis: widget.kpis),
                )
              : _KpiStrip(kpis: widget.kpis),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Showcase(
            key: ShowcaseKeys.inventoryFilters,
            description: 'Filter your inventory by categories or dates to quickly find what you need.',
            tooltipBackgroundColor: Bt.ink,
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: _FiltersRow(
              chips: widget.chips,
              activeChip: widget.activeChip,
              dateFilter: widget.dateFilter,
              onChip: widget.onChipChange,
              onDate: widget.onDateFilter,
            ),
          ),
        ),
      ),
    ];
    if (widget.groups.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            title: widget.emptyTitle,
            subtitle: widget.emptySubtitle,
            icon: _typeIcon,
            onAdd: RoleManager.canAddTransactions
                ? () => widget.onNavigate(widget.emptyRoute, {})
                : null,
          ),
        ),
      );
    } else {
      for (final group in widget.groups) {
        final isCollapsed = _collapsed[group.label] ?? false;
        slivers.add(
          SliverPersistentHeader(
            pinned: true,
            delegate: _DateGroupHeaderDelegate(
              label: group.label,
              count: group.records.length,
              collapsed: isCollapsed,
              onToggle: () => setState(() {
                _collapsed[group.label] = !(_collapsed[group.label] ?? false);
              }),
            ),
          ),
        );
        if (!isCollapsed) {
          slivers.add(
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PurchaseCard(
                      record: group.records[i],
                      selectedProjectId: widget.selectedProjectId,
                      onNavigate: widget.onNavigate,
                    ),
                  ),
                  childCount: group.records.length,
                ),
              ),
            ),
          );
        }
      }
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 120)));
    }
    return slivers;
  }
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: _buildSlivers(),
    );
  }
}
class _DateGroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;
  _DateGroupHeaderDelegate({
    required this.label,
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });
  @override
  double get minExtent => 46;
  @override
  double get maxExtent => 46;
  @override
  bool shouldRebuild(_DateGroupHeaderDelegate old) =>
      old.label != label || old.count != count || old.collapsed != collapsed;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Semantics(
      button: true,
      expanded: !collapsed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: AnimatedContainer(
          duration: Bt.fast,
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Bt.ground,
            boxShadow: overlapsContent ? const [BoxShadow(color: Color(0x140C0E12), blurRadius: 10, offset: Offset(0, 4))] : null,
          ),
          child: Row(
            children: [
              Text(label.toUpperCase(), style: BtText.mono(context, color: Bt.ink2)),
              const SizedBox(width: 8),
              Text(
                '$count ${count == 1 ? "Item" : "Items"}',
                style: BtText.caption(context),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: collapsed ? 0.5 : 0,
                duration: Bt.fast,
                curve: Bt.ease,
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 20,
                  color: Bt.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _PurchaseCard extends StatelessWidget {
  final _PurchaseRecord record;
  final String? selectedProjectId;
  final void Function(String route, Map<String, dynamic> args) onNavigate;
  const _PurchaseCard({
    required this.record,
    required this.selectedProjectId,
    required this.onNavigate,
  });
  String get _qtyLabel {
    switch (record.type) {
      case 'labour':
        return 'Days';
      case 'equipment':
        return 'Hours';
      default:
        return 'Qty';
    }
  }
  /// Inventory only lists approved entries; editing follows the same rules as
  /// everywhere else (approved entries are not editable).
  bool get _canEdit {
    final createdBy = record.rawTx['createdBy'];
    final project = record.rawTx['project'] ?? record.rawTx['projectId'];
    return EntryPermissions.canEdit(
      status: record.approvalStatus,
      createdBy: createdBy is Map
          ? (createdBy['_id'] ?? '').toString()
          : (createdBy ?? '').toString(),
      projectId: project is Map
          ? (project['_id'] ?? '').toString()
          : (project ?? selectedProjectId ?? '').toString(),
    );
  }
  String get _vendorLabel {
    switch (record.type) {
      case 'labour':
        return 'Worker';
      case 'equipment':
        return 'Operator';
      default:
        return 'Vendor';
    }
  }
  String get _addRoute {
    switch (record.type) {
      case 'labour':
        return '/add-labour';
      case 'equipment':
        return '/add-equipment';
      default:
        return '/add-material';
    }
  }
  IconData get _icon {
    if (record.type == 'labour') {
      return Icons.person_outline;
    }
    if (record.type == 'equipment') {
      return Icons.construction_outlined;
    }
    final cat = record.categoryName.toLowerCase();
    if (cat.contains('cement')) {
      return Icons.architecture;
    }
    if (cat.contains('steel') || cat.contains('iron')) {
      return Icons.straighten;
    }
    if (cat.contains('sand') || cat.contains('aggregate')) {
      return Icons.terrain;
    }
    if (cat.contains('brick') || cat.contains('block')) {
      return Icons.view_module_outlined;
    }
    if (cat.contains('electric')) {
      return Icons.electrical_services;
    }
    if (cat.contains('plumb') || cat.contains('pipe')) {
      return Icons.plumbing;
    }
    if (cat.contains('tile') || cat.contains('floor')) {
      return Icons.grid_view_outlined;
    }
    if (cat.contains('wood') || cat.contains('timber')) {
      return Icons.cabin_outlined;
    }
    return Icons.inventory_2_outlined;
  }
  String _formatQty() {
    final q = record.quantity;
    final s = q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(1);
    final u = record.unit.toLowerCase();
    if (u.isEmpty || u == 'units' || u == 'unit') {
      return s;
    }
    return '$s ${record.unit}';
  }
  @override
  Widget build(BuildContext context) {
    final pending = (record.billAmount - record.paidAmount).clamp(
      0.0,
      double.infinity,
    );
    final String statusLabel;
    final BtTone statusTone;
    switch (record.payStatus) {
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
    return BtCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      onTap: () => Navigator.pushNamed(
        context,
        '/logs',
        arguments: {
          'type': record.type,
          'name': record.itemName,
          'projectId': selectedProjectId,
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StackBars(icon: _icon, type: record.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.itemName,
                      style: BtText.headline(context).copyWith(fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.vendor.isNotEmpty
                          ? '$_vendorLabel: ${record.vendor}'
                          : '$_vendorLabel: —',
                      style: BtText.caption(context, color: record.vendor.isNotEmpty ? Bt.ink3 : Bt.placeholder),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: BtBadge(label: statusLabel, tone: statusTone),
              ),
              SizedBox(
                width: 32,
                height: 28,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  tooltip: 'More actions',
                  color: Bt.card,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Bt.ink3,
                    size: 18,
                  ),
                          onSelected: (val) {
                            if (val == 'edit') {
                              final editArgs = Map<String, dynamic>.from(
                                record.rawTx,
                              );
                              editArgs['isEditing'] = true;
                              editArgs['id'] = record.txId;
                              editArgs['status'] = record.approvalStatus;
                              debugPrint('EDIT PAYLOAD');
                              debugPrint(editArgs.toString());
                              onNavigate(_addRoute, editArgs);
                            } else if (val == 'history') {
                              Navigator.pushNamed(
                                context,
                                '/logs',
                                arguments: {
                                  'type': record.type,
                                  'name': record.itemName,
                                  'projectId': selectedProjectId,
                                },
                              );
                            }
                          },
                  itemBuilder: (_) => [
                    if (_canEdit)
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Entry', style: BtText.body(context)),
                      ),
                    PopupMenuItem(
                      value: 'history',
                      child: Text('View History', style: BtText.body(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (record.payStatus == PaymentStatus.partial) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: Bt.green),
                const SizedBox(width: 5),
                Text(
                  '${formatCurrency(record.paidAmount)} Paid',
                  style: BtText.num(BtText.caption(context, color: Bt.green, weight: FontWeight.w600)),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.schedule_rounded, size: 14, color: Bt.red),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '${formatCurrency(pending)} Pending',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BtText.num(BtText.caption(context, color: Bt.red, weight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              color: Bt.fill,
              borderRadius: BorderRadius.circular(Bt.rTile),
            ),
            child: Row(
              children: [
                Expanded(child: _MetricCell(_qtyLabel, _formatQty())),
                _vertDivider(),
                Expanded(
                  child: _MetricCell(
                    'Rate',
                    record.rate > 0 ? formatCurrency(record.rate) : '—',
                  ),
                ),
                _vertDivider(),
                Expanded(
                  child: _MetricCell(
                    'Total',
                    formatCurrency(record.billAmount),
                    highlight: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (RoleManager.canAddTransactions) Expanded(
                child: _PurchaseActionBtn(
                  label: 'Add More',
                  icon: Icons.add_rounded,
                  style: _ActionStyle.primary,
                  onTap: () {
                          debugPrint('ADD MORE PAYLOAD');
                          debugPrint(record.rawTx.toString());
                          final dupArgs = Map<String, dynamic>.from(
                            record.rawTx,
                          );
                          dupArgs['isDuplicate'] = true;
                          dupArgs['sourceTransactionId'] = record.txId;
                          onNavigate(_addRoute, dupArgs);
                        },
                ),
              ),
              if (RoleManager.canAddTransactions && RoleManager.canRecordPayments)
                const SizedBox(width: 8),
              // Recording a payment needs approve_payments / mark_paid on the backend.
              if (RoleManager.canRecordPayments) Expanded(
                child: _PurchaseActionBtn(
                  label: 'Record Payment',
                  icon: Icons.credit_card_outlined,
                  style: _ActionStyle.secondary,
                  onTap: () {
                          final projectProvider = context
                              .read<ProjectProvider>();
                          String pName = 'Unknown Project';
                          String pId = '';
                          final matchedProj = projectProvider.projects.where(
                            (p) =>
                                p.id == record.rawTx['project']?.toString() ||
                                p.id == record.rawTx['projectId']?.toString() ||
                                p.id == selectedProjectId,
                          );
                          if (matchedProj.isNotEmpty) {
                            pName = matchedProj.first.name;
                            pId = matchedProj.first.id;
                          } else {
                            final rawProj = record.rawTx['project'];
                            if (rawProj is Map) {
                              pName =
                                  (rawProj['projectName'] ??
                                          rawProj['name'] ??
                                          'Unknown Project')
                                      .toString();
                              pId = (rawProj['_id'] ?? '').toString();
                            }
                          }
                          if (pId.isEmpty) {
                            pId =
                                record.rawTx['project']?.toString() ??
                                record.rawTx['projectId']?.toString() ??
                                selectedProjectId ??
                                '';
                          }
                          final payArgs = {
                            'id': record.txId,
                            'projectId': pId,
                            'projectName': pName,
                            'itemId': record.itemId,
                            'itemName': record.itemName,
                            'itemType': record.type,
                            'quantity': record.quantity,
                            'rate': record.rate,
                            'totalAmount': record.billAmount,
                            'paidAmount': record.paidAmount,
                            'outstandingAmount':
                                (record.billAmount - record.paidAmount).clamp(
                                  0.0,
                                  double.infinity,
                                ),
                            'paymentStatus': record.payStatus,
                            'receipt':
                                (record.rawTx['attachments'] is List &&
                                    record.rawTx['attachments'].isNotEmpty)
                                ? record.rawTx['attachments'].first?.toString()
                                : null,
                            'transactionDetails': record.rawTx,
                          };
                          Navigator.pushNamed(
                            context,
                            '/fulfillment-payment',
                            arguments: payArgs,
                          ).then((updated) {
                            if (updated == true && context.mounted) {
                              context.read<InventoryProvider>().loadInventory(
                                selectedProjectId ?? '',
                              );
                            }
                          });
                        },
                ),
              ),
              if (RoleManager.canAddTransactions || RoleManager.canRecordPayments)
                const SizedBox(width: 4)
              else
                const Spacer(),
              _PurchaseActionBtn(
                label: 'History',
                icon: Icons.history_rounded,
                style: _ActionStyle.tertiary,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/logs',
                  arguments: {
                    'type': record.type,
                    'name': record.itemName,
                    'projectId': selectedProjectId,
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _vertDivider() => Container(
    width: 1,
    height: 28,
    color: Bt.line,
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );
}
/// Three little bars that rise once (Inventory board "stack3") with the item icon.
class _StackBars extends StatelessWidget {
  const _StackBars({required this.icon, required this.type});
  final IconData icon;
  final String type;
  @override
  Widget build(BuildContext context) {
    final series = context.bt.series;
    final color = type == 'labour'
        ? (series.length > 1 ? series[1] : Bt.steel)
        : type == 'equipment'
            ? (series.length > 2 ? series[2] : Bt.slate)
            : (series.isNotEmpty ? series[0] : context.bt.accent);
    final reduce = Bt.reduceMotion(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(Bt.rTile),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 9,
            right: 9,
            bottom: 8,
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, h) in const [(0, .55), (1, 1.0), (2, .75)])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: reduce ? h : 0, end: h),
                        duration: Duration(milliseconds: reduce ? 0 : 700 + i * 100),
                        curve: Bt.ease,
                        builder: (_, v, _) => FractionallySizedBox(
                          heightFactor: v,
                          alignment: Alignment.bottomCenter,
                          child: DecoratedBox(decoration: BoxDecoration(color: color.withValues(alpha: .55), borderRadius: BorderRadius.circular(1.5))),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(top: 7, child: Icon(icon, size: 17, color: Bt.ink)),
        ],
      ),
    );
  }
}
class _MetricCell extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _MetricCell(this.label, this.value, {this.highlight = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: BtText.num(highlight ? BtText.title(context, size: 15) : BtText.subhead(context, color: Bt.ink, weight: FontWeight.w600)),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          label.toUpperCase(),
          style: BtText.mono(context, size: 9.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
enum _ActionStyle { primary, secondary, tertiary }
class _PurchaseActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final _ActionStyle style;
  final VoidCallback onTap;
  const _PurchaseActionBtn({
    required this.label,
    required this.icon,
    required this.style,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    BoxDecoration deco;
    Color color;
    bool showIcon = false;
    switch (style) {
      case _ActionStyle.primary:
        deco = BoxDecoration(color: Bt.ink, borderRadius: BorderRadius.circular(12));
        color = Bt.bone;
        break;
      case _ActionStyle.secondary:
        deco = BoxDecoration(
          color: Bt.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Bt.inputBorder),
        );
        color = Bt.ink;
        break;
      case _ActionStyle.tertiary:
        deco = const BoxDecoration();
        color = Bt.ink2;
        showIcon = true;
        break;
    }
    return BtPressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: deco,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: BtText.caption(context, color: color, weight: FontWeight.w600).copyWith(fontSize: 13.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _FiltersRow extends StatelessWidget {
  final List<String> chips;
  final String activeChip;
  final String dateFilter;
  final ValueChanged<String> onChip;
  final void Function(String filter, DateTimeRange? custom) onDate;
  const _FiltersRow({
    required this.chips,
    required this.activeChip,
    required this.dateFilter,
    required this.onChip,
    required this.onDate,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chips.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: chips.map((cat) {
                final isActive = cat == activeChip;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: BtChip(
                    label: cat,
                    selected: isActive,
                    onTap: () => onChip(cat),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            BtChip(
              label: dateFilter == 'All' ? 'All Time' : dateFilter,
              icon: Icons.calendar_today_rounded,
              trailingIcon: Icons.keyboard_arrow_down_rounded,
              selected: dateFilter != 'All',
              onTap: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => _DateRangeSheet(
                    activeFilter: dateFilter,
                    onSelect: (f, cr) {
                      onDate(f, cr);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
/// Bone sheet chrome shared by the two pickers below.
class _PickerSheetFrame extends StatelessWidget {
  const _PickerSheetFrame({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.circular(Bt.rSheet),
        boxShadow: Bt.shadowLg,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Bt.inputBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: BtText.d3(context)),
              const SizedBox(height: 8),
              Flexible(child: child),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
class _PickerOption extends StatelessWidget {
  const _PickerOption({required this.label, required this.icon, required this.selected, required this.onTap});
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
        scale: .98,
        child: AnimatedContainer(
          duration: Bt.fast,
          curve: Bt.ease,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Bt.fill : Colors.transparent,
            borderRadius: BorderRadius.circular(Bt.rTile),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? Bt.ink : Bt.ink3),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: BtText.body(context, weight: selected ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: context.bt.accentInk, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
class _DateRangeSheet extends StatelessWidget {
  final String activeFilter;
  final void Function(String filter, DateTimeRange? custom) onSelect;
  const _DateRangeSheet({required this.activeFilter, required this.onSelect});
  static const List<(String, IconData)> _options = [
    ('All', Icons.all_inclusive),
    ('Today', Icons.today),
    ('Yesterday', Icons.timelapse),
    ('This Week', Icons.date_range),
    ('This Month', Icons.calendar_month),
    ('Last Month', Icons.history),
    ('Last 3 Months', Icons.date_range_outlined),
    ('This Year', Icons.calendar_today),
  ];
  @override
  Widget build(BuildContext context) {
    return _PickerSheetFrame(
      title: 'Filter by Date',
      child: SingleChildScrollView(
        child: Column(
          children: [
            ..._options.map(((String, IconData) opt) {
              final (label, icon) = opt;
              return _PickerOption(
                label: label,
                icon: icon,
                selected: activeFilter == label,
                onTap: () => onSelect(label, null),
              );
            }),
            _PickerOption(
              label: 'Custom Range',
              icon: Icons.date_range_outlined,
              selected: activeFilter == 'Custom',
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(
                    const Duration(days: 365),
                  ),
                  initialDateRange: DateTimeRange(
                    start: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    end: DateTime.now(),
                  ),
                );
                if (range != null) {
                  onSelect('Custom', range);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
class _KpiStrip extends StatelessWidget {
  final List<_KpiData> kpis;
  const _KpiStrip({required this.kpis});
  @override
  Widget build(BuildContext context) {
    if (kpis.length < 4) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _KpiCard(data: kpis[0])),
              const SizedBox(width: 8),
              Expanded(child: _KpiCard(data: kpis[1])),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _KpiCard(data: kpis[2])),
              const SizedBox(width: 8),
              Expanded(child: _KpiCard(data: kpis[3])),
            ],
          ),
        ),
      ],
    );
  }
}
class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final alert = data.isAlert;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: alert ? Bt.redSoft : Bt.card,
        borderRadius: BorderRadius.circular(Bt.rTile + 4),
        boxShadow: alert ? null : Bt.shadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: alert ? Bt.red : Bt.ink3, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label.toUpperCase(),
                  style: BtText.mono(context, color: alert ? Bt.red : Bt.ink3, size: 9.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: BtText.num(BtText.title(context, size: 17).copyWith(color: alert ? Bt.red : Bt.ink)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _EmptyState extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onAdd;
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onAdd,
  });
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BtTile(icon: icon, size: 64, bg: bt.accentSoft, fg: bt.accentInk),
            const SizedBox(height: 18),
            Text(title, style: BtText.title(context, size: 19), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle, style: BtText.subhead(context), textAlign: TextAlign.center),
            const SizedBox(height: 22),
            Showcase(
              key: ShowcaseKeys.inventoryAdd,
              description: 'Tap here to add your first inventory entry.',
              tooltipBackgroundColor: Bt.ink,
              textColor: Colors.white,
              tooltipBorderRadius: BorderRadius.circular(16),
              tooltipPadding: const EdgeInsets.all(16),
              child: onAdd == null ? const SizedBox.shrink() : BtButton(
                label: 'Add First Entry',
                icon: Icons.add_rounded,
                small: true,
                expand: false,
                onPressed: onAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ProjectSelectorSheet extends StatelessWidget {
  final List<String> allItems;
  final Map<String, String?> idMap;
  final String? selectedId;
  final void Function(String?) onSelect;
  const _ProjectSelectorSheet({
    required this.allItems,
    required this.idMap,
    required this.selectedId,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    return _PickerSheetFrame(
      title: 'Select Project',
      child: ListView(
        shrinkWrap: true,
        children: allItems.map((label) {
          final id = label == 'All Active Projects'
              ? null
              : idMap[label];
          final isSel = selectedId == id;
          return _PickerOption(
            label: label,
            icon: id == null ? Icons.layers_outlined : Icons.folder_outlined,
            selected: isSel,
            onTap: () => onSelect(id),
          );
        }).toList(),
      ),
    );
  }
}

/// Shown when the inventory could not be loaded (instead of a misleading empty list).
class _InventoryLoadError extends StatelessWidget {
  const _InventoryLoadError({required this.provider});
  final InventoryProvider provider;
  @override
  Widget build(BuildContext context) {
    return BtEmpty(
      icon: Icons.cloud_off_rounded,
      title: "Couldn't load inventory",
      message: provider.error,
      action: 'Retry',
      onAction: provider.retry,
    );
  }
}
