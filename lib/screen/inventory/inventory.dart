import 'dart:async';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/common/themes/app_gradients.dart';
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
        const TooltipActionButton(
          type: TooltipDefaultActionType.next, 
          backgroundColor: AppColors.primary, 
          textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        )
      ], 
      enableAutoScroll: true,
      onFinish: () {
        UserSession.markModuleVisited('InventoryScreen');
        if (UserSession.globalTourActive) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) {
              final nav = Provider.of<NavController>(context, listen: false);
              nav.setRoute('/reports', context);
            }
          });
        }
      },
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
  static const Color _blue = AppColors.primary;
  static const Color _bg = AppColors.gradientStart;
  static const Color _dark = AppColors.textDark;
  static const Color _gray = AppColors.textLight;
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
              date = DateTime.parse(val);
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
    const alertRed = Color(0xFFEF4444);
    const green = Color(0xFF10B981);
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
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: 'Inventory',
              rightWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Showcase(
                    key: _helpKey,
                    description: 'Tap here anytime to replay this tour and get help.',
                    tooltipBackgroundColor: const Color(0xFF1E1E2C),
                    textColor: Colors.white,
                    tooltipBorderRadius: BorderRadius.circular(16),
                    tooltipPadding: const EdgeInsets.all(16),
                    child: IconButton(
                      icon: const Icon(Icons.help_outline, color: AppColors.primary),
                      onPressed: () {
                        ShowCaseWidget.of(context).startShowCase([
                          ShowcaseKeys.inventoryProjectContext,
                          ShowcaseKeys.inventoryFilters,
                          ShowcaseKeys.inventoryAdd,
                          _helpKey,
                        ]);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: const ProfileAvatar(radius: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Column(
                      children: [
                        Showcase(
                          key: ShowcaseKeys.inventoryProjectContext,
                          description: 'Select a project to view its specific materials, equipment, and updates.',
                          tooltipBackgroundColor: const Color(0xFF1E1E2C),
                          textColor: Colors.white,
                          tooltipBorderRadius: BorderRadius.circular(16),
                          tooltipPadding: const EdgeInsets.all(16),
                          child: _buildProjectSelector(),
                        ),
                        const SizedBox(height: 10),
                        _buildSearchBar(),
                        const SizedBox(height: 10),
                        _buildTabBar(),
                        const SizedBox(height: 4),
                      ],
                    ),
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
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
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
    return GestureDetector(
      onTap: () => _showProjectSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E5FF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.folder_outlined, color: _blue, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROJECT CONTEXT',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: _gray,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _gray,
              size: 22,
            ),
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
    return SizedBox(
      height: 48,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E5F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: _gray, size: 20),
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
                decoration: InputDecoration(
                  hintText: _searchHint,
                  hintStyle: const TextStyle(color: _gray, fontSize: 13.5),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(color: _dark, fontSize: 14),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E5F6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8),
        ],
      ),
      child: Row(
        children: List.generate(3, (i) {
          final active = i == _tabIndex;
          final textColor = active ? Colors.white : const Color(0xFF4B4966);
          final iconColor = active ? Colors.white : const Color(0xFF757299);
          Widget tabChild = InkWell(
            onTap: () {
              setState(() => _tabIndex = i);
              _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                gradient: active ? AppGradients.primaryButton : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icons[i], color: iconColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      color: textColor,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          );
          if (i == 0) {
            tabChild = Showcase(
              key: ShowcaseKeys.inventoryMaterials,
              description: 'View your materials inventory here',
              tooltipBackgroundColor: const Color(0xFF1E1E2C),
              textColor: Colors.white,
              tooltipBorderRadius: BorderRadius.circular(16),
              tooltipPadding: const EdgeInsets.all(16),
              child: tabChild,
            );
          } else if (i == 2) {
            tabChild = Showcase(
              key: ShowcaseKeys.inventoryTools,
              description: 'View your equipment and tools inventory here',
              tooltipBackgroundColor: const Color(0xFF1E1E2C),
              textColor: Colors.white,
              tooltipBorderRadius: BorderRadius.circular(16),
              tooltipPadding: const EdgeInsets.all(16),
              child: tabChild,
            );
          }
          return Expanded(child: tabChild);
        }),
      ),
    );
  }
  Widget _buildMaterialsTab(BuildContext ctx) {
    final provider = ctx.watch<InventoryProvider>();
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    final all = provider.materialInventory;
    final flat = _flatten(all);
    final chips = _buildChips(flat);
    final filtered = _filterDate(
      _filterCat(_filterSearch(flat, _searchCtrl.text), _matCategory),
      _matDateFilter,
      _matCustomRange,
    );
    final groups = _groupByDate(filtered);
    final kpis = _buildKpis(filtered, 'material');
    return _TimelineTabContent(
      groups: groups,
      kpis: kpis,
      chips: chips,
      activeChip: _matCategory,
      dateFilter: _matDateFilter,
      type: 'material',
      emptyTitle: 'No Material Purchases',
      emptySubtitle: 'Add your first material purchase to get started.',
      emptyRoute: '/add-material',
      selectedProjectId: _selectedProjectId,
      onChipChange: (c) => setState(() => _matCategory = c),
      onDateFilter: (f, cr) => setState(() {
        _matDateFilter = f;
        _matCustomRange = cr;
      }),
      onNavigate: (route, args) =>
          Navigator.pushNamed(ctx, route, arguments: args),
    );
  }
  Widget _buildLabourTab(BuildContext ctx) {
    final provider = ctx.watch<InventoryProvider>();
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    final all = provider.labourInventory;
    final flat = _flatten(all);
    final chips = _buildChips(flat);
    final filtered = _filterDate(
      _filterCat(_filterSearch(flat, _searchCtrl.text), _labCategory),
      _labDateFilter,
      _labCustomRange,
    );
    final groups = _groupByDate(filtered);
    final kpis = _buildKpis(filtered, 'labour');
    return _TimelineTabContent(
      groups: groups,
      kpis: kpis,
      chips: chips,
      activeChip: _labCategory,
      dateFilter: _labDateFilter,
      type: 'labour',
      emptyTitle: 'No Labour Entries',
      emptySubtitle: 'Add your first labour entry to track workforce costs.',
      emptyRoute: '/add-labour',
      selectedProjectId: _selectedProjectId,
      onChipChange: (c) => setState(() => _labCategory = c),
      onDateFilter: (f, cr) => setState(() {
        _labDateFilter = f;
        _labCustomRange = cr;
      }),
      onNavigate: (route, args) =>
          Navigator.pushNamed(ctx, route, arguments: args),
    );
  }
  Widget _buildEquipmentTab(BuildContext ctx) {
    final provider = ctx.watch<InventoryProvider>();
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    final all = provider.equipmentInventory;
    final flat = _flatten(all);
    final chips = _buildChips(flat);
    final filtered = _filterDate(
      _filterCat(_filterSearch(flat, _searchCtrl.text), _eqpCategory),
      _eqpDateFilter,
      _eqpCustomRange,
    );
    final groups = _groupByDate(filtered);
    final kpis = _buildKpis(filtered, 'equipment');
    return _TimelineTabContent(
      groups: groups,
      kpis: kpis,
      chips: chips,
      activeChip: _eqpCategory,
      dateFilter: _eqpDateFilter,
      type: 'equipment',
      emptyTitle: 'No Equipment Entries',
      emptySubtitle: 'Add your first equipment entry to track asset usage.',
      emptyRoute: '/add-equipment',
      selectedProjectId: _selectedProjectId,
      onChipChange: (c) => setState(() => _eqpCategory = c),
      onDateFilter: (f, cr) => setState(() {
        _eqpDateFilter = f;
        _eqpCustomRange = cr;
      }),
      onNavigate: (route, args) =>
          Navigator.pushNamed(ctx, route, arguments: args),
    );
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
                  tooltipBackgroundColor: const Color(0xFF1E1E2C),
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
            tooltipBackgroundColor: const Color(0xFF1E1E2C),
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
            onAdd: () => widget.onNavigate(widget.emptyRoute, {}),
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
    return Material(
      color: overlapsContent ? Colors.white : const Color(0xFFF2F0FB),
      elevation: overlapsContent ? 2 : 0,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count ${count == 1 ? "Item" : "Items"}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: collapsed ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 20,
                  color: AppColors.textLight,
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
  Color get _iconBg {
    if (record.type == 'labour') {
      return const Color(0xFFEEF2FF);
    }
    if (record.type == 'equipment') {
      return const Color(0xFFECFDF5);
    }
    final cat = record.categoryName.toLowerCase();
    if (cat.contains('cement')) {
      return const Color(0xFFE8F5E9);
    }
    if (cat.contains('steel') || cat.contains('iron')) {
      return const Color(0xFFE3F2FD);
    }
    if (cat.contains('sand') || cat.contains('aggregate')) {
      return const Color(0xFFFFF8E1);
    }
    if (cat.contains('brick') || cat.contains('block')) {
      return const Color(0xFFFBE9E7);
    }
    if (cat.contains('electric')) {
      return const Color(0xFFF3E5F5);
    }
    if (cat.contains('plumb') || cat.contains('pipe')) {
      return const Color(0xFFE8EAF6);
    }
    return const Color(0xFFEEF2FF);
  }
  Color get _iconColor {
    if (record.type == 'labour') {
      return AppColors.primaryBlue;
    }
    if (record.type == 'equipment') {
      return const Color(0xFF16A34A);
    }
    final cat = record.categoryName.toLowerCase();
    if (cat.contains('cement')) {
      return const Color(0xFF4CAF50);
    }
    if (cat.contains('steel') || cat.contains('iron')) {
      return const Color(0xFF1565C0);
    }
    if (cat.contains('sand') || cat.contains('aggregate')) {
      return const Color(0xFFF59E0B);
    }
    if (cat.contains('brick') || cat.contains('block')) {
      return const Color(0xFFE64A19);
    }
    if (cat.contains('electric')) {
      return const Color(0xFF7B1FA2);
    }
    if (cat.contains('plumb') || cat.contains('pipe')) {
      return const Color(0xFF3949AB);
    }
    return AppColors.primaryBlue;
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
  Icon _vendorIcon() {
    if (record.type == 'labour') {
      return const Icon(
        Icons.person_outline,
        size: 11,
        color: AppColors.textLight,
      );
    }
    if (record.type == 'equipment') {
      return const Icon(
        Icons.engineering_outlined,
        size: 11,
        color: AppColors.textLight,
      );
    }
    return const Icon(
      Icons.store_outlined,
      size: 11,
      color: AppColors.textLight,
    );
  }
  @override
  Widget build(BuildContext context) {
    final pending = (record.billAmount - record.paidAmount).clamp(
      0.0,
      double.infinity,
    );
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/logs',
          arguments: {
            'type': record.type,
            'name': record.itemName,
            'projectId': selectedProjectId,
          },
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_icon, color: _iconColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.itemName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              _vendorIcon(),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  record.vendor.isNotEmpty
                                      ? '$_vendorLabel: ${record.vendor}'
                                      : '$_vendorLabel: —',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: record.vendor.isNotEmpty
                                        ? AppColors.textLight
                                        : AppColors.textLight.withValues(
                                            alpha: 0.5,
                                          ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        PaymentStatusChip(status: record.payStatus),
                        const SizedBox(height: 8),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          icon: const Icon(
                            Icons.more_vert,
                            color: AppColors.textLight,
                            size: 18,
                          ),
                          onSelected: (val) {
                            if (val == 'edit') {
                              final editArgs = Map<String, dynamic>.from(
                                record.rawTx,
                              );
                              editArgs['isEditing'] = true;
                              editArgs['id'] = record.txId;
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
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit Entry'),
                            ),
                            PopupMenuItem(
                              value: 'history',
                              child: Text('View History'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                if (record.payStatus == PaymentStatus.partial) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 13,
                          color: Color(0xFF15803D),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${formatCurrency(record.paidAmount)} Paid',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.schedule,
                          size: 13,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${formatCurrency(pending)} Pending',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F7FF),
                    borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF0EEF8)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PurchaseActionBtn(
                        label: 'Add More',
                        icon: Icons.add_circle_outline,
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
                    const SizedBox(width: 8),
                    Expanded(
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
                    const SizedBox(width: 8),
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
          ),
        ),
      ),
    );
  }
  Widget _vertDivider() => Container(
    width: 1,
    height: 28,
    color: const Color(0xFFE5E7EB),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );
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
          style: TextStyle(
            fontSize: highlight ? 14 : 12.5,
            fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            color: highlight ? AppColors.primaryBlue : const Color(0xFF1A1A2E),
            letterSpacing: -0.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: AppColors.textLight,
            fontWeight: FontWeight.w600,
          ),
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
    switch (style) {
      case _ActionStyle.primary:
        deco = BoxDecoration(
          gradient: AppGradients.primaryButton,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        );
        color = Colors.white;
        break;
      case _ActionStyle.secondary:
        deco = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primaryBlue, width: 1.2),
        );
        color = AppColors.primaryBlue;
        break;
      case _ActionStyle.tertiary:
        deco = const BoxDecoration();
        color = AppColors.textLight;
        break;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: deco,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chips.map((cat) {
                final isActive = cat == activeChip;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onChip(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: isActive ? AppGradients.primaryButton : null,
                        color: isActive ? null : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? Colors.transparent
                              : const Color(0xFFDDE0F0),
                          width: 1.2,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isActive ? Colors.white : AppColors.textLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
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
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFDDE0F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateFilter == 'All' ? 'All Time' : dateFilter,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.textLight,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE0F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Filter by Date',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ..._options.map(((String, IconData) opt) {
                        final (label, icon) = opt;
                        final isActive = activeFilter == label;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          leading: Icon(
                            icon,
                            color: isActive
                                ? AppColors.primaryBlue
                                : AppColors.textLight,
                            size: 20,
                          ),
                          title: Text(
                            label,
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.primaryBlue
                                  : AppColors.textDark,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          trailing: isActive
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primaryBlue,
                                  size: 18,
                                )
                              : null,
                          onTap: () => onSelect(label, null),
                        );
                      }),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        leading: Icon(
                          Icons.date_range_outlined,
                          color: activeFilter == 'Custom'
                              ? AppColors.primaryBlue
                              : AppColors.textLight,
                          size: 20,
                        ),
                        title: Text(
                          'Custom Range',
                          style: TextStyle(
                            color: activeFilter == 'Custom'
                                ? AppColors.primaryBlue
                                : AppColors.textDark,
                            fontWeight: activeFilter == 'Custom'
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        trailing: activeFilter == 'Custom'
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primaryBlue,
                                size: 18,
                              )
                            : null,
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
              ),
              const SizedBox(height: 8),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.isAlert
              ? data.color.withValues(alpha: 0.35)
              : const Color(0xFFEEEBF8),
          width: data.isAlert ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(data.icon, color: data.color, size: 15),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: data.isAlert ? data.color : const Color(0xFF1A1A2E),
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class _EmptyState extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onAdd;
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onAdd,
  });
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textLight,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Showcase(
              key: ShowcaseKeys.inventoryAdd,
              description: 'Tap here to add your first inventory entry.',
              tooltipBackgroundColor: const Color(0xFF1E1E2C),
              textColor: Colors.white,
              tooltipBorderRadius: BorderRadius.circular(16),
              tooltipPadding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppGradients.primaryButton,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 17),
                      SizedBox(width: 8),
                      Text(
                        'Add First Entry',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE0F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Project',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: allItems.map((label) {
                    final id = label == 'All Active Projects'
                        ? null
                        : idMap[label];
                    final isSel = selectedId == id;
                    return InkWell(
                      onTap: () => onSelect(id),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.primaryBlue.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel
                                ? AppColors.primaryBlue
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSel
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 18,
                              color: isSel
                                  ? AppColors.primaryBlue
                                  : AppColors.textLight,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isSel
                                      ? AppColors.primaryBlue
                                      : AppColors.textDark,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

