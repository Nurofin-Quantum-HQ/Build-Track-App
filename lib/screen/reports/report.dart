import 'package:buildtrack_mobile/common/tour_targets.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/entry_permissions.dart';
import 'package:buildtrack_mobile/controller/report_provider.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/screen/reports/report_export_helper.dart';
import 'package:buildtrack_mobile/screen/reports/csv_import_helper.dart';
import 'package:buildtrack_mobile/screen/reports/report_widgets.dart' show ReportQuickTile;
import 'package:buildtrack_mobile/screen/reports/report_sheet.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsScreen extends StatelessWidget {
  ReportsScreen({super.key});
  final GlobalKey<ShowCaseWidgetState> _showcaseKey = GlobalKey<ShowCaseWidgetState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChangeNotifierProvider(
        create: (_) => ReportProvider()..refresh(),
        child: ShowCaseWidget(
          key: _showcaseKey,
          enableAutoScroll: true,
          globalTooltipActions: [
            TooltipActionButton(
              type: TooltipDefaultActionType.skip,
              backgroundColor: Colors.transparent,
              textStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              onTap: () {
                UserSession.skipTour();
                _showcaseKey.currentState?.dismiss();
              }
            ),
            TooltipActionButton(
              type: TooltipDefaultActionType.next,
              backgroundColor: AppColors.primary,
              textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            )
          ],
          onFinish: () {
            UserSession.markModuleVisited('ReportsScreen');
            // Reports is the last tab of the app tour: finishing here ends it.
            if (UserSession.globalTourActive) {
              UserSession.setGlobalTourActive(false);
            }
          },
          builder: (context) => _ReportsView(),
        ),
      ),
    );
  }
}

/// Order of two report entries for a sort key:
///  * 'date' — purchase (entry) date, by calendar day, then by when the entry
///    was made, so same-day rows stay in entry order;
///  * 'paymentDate' — date of the latest payment; unpaid entries always last
///    (in either direction), among themselves by purchase date;
///  * 'amount', 'project' — ties broken by purchase date, newest first.
/// Dates are compared as DateTime values (parsed with parseFlexibleDate in
/// EntryModel.fromJson), never as strings.
int compareReportEntries(EntryModel a, EntryModel b, String column, bool ascending, String Function(String) projectName) {
  int dir(int c) => ascending ? c : -c;
  int byPurchase(bool asc) {
    final da = DateTime(a.date.year, a.date.month, a.date.day);
    final db = DateTime(b.date.year, b.date.month, b.date.day);
    var c = da.compareTo(db);
    if (c == 0) c = a.createdAt.compareTo(b.createdAt);
    if (c == 0) c = a.id.compareTo(b.id);
    return asc ? c : -c;
  }

  switch (column) {
    case 'paymentDate':
      final pa = ReportSheet.paymentDateOf(a);
      final pb = ReportSheet.paymentDateOf(b);
      if (pa == null || pb == null) {
        if (pa == null && pb == null) return byPurchase(ascending);
        return pa == null ? 1 : -1;
      }
      final c = pa.compareTo(pb);
      return c != 0 ? dir(c) : byPurchase(ascending);
    case 'amount':
      final c = a.amount.compareTo(b.amount);
      return c != 0 ? dir(c) : byPurchase(false);
    case 'project':
      final c = projectName(a.projectId).toLowerCase().compareTo(projectName(b.projectId).toLowerCase());
      return c != 0 ? dir(c) : byPurchase(false);
    default:
      return byPurchase(ascending);
  }
}

class ReportFilterState {
  static String selectedProjectId = 'all';
  static String? selectedFloor;
  static String? selectedPhaseId;
  static String? selectedActivityName;
  static String searchQuery = '';
  static String? selectedItemName;
  static Set<EntryType> selectedTypes = {
    EntryType.material,
    EntryType.labour,
    EntryType.equipment,
  };
  static String selectedStatus = 'All';
  static DateTime? startDate;
  static DateTime? endDate;
  static String datePreset = 'All Time';
  static String sortColumn = 'date';
  static bool sortAscending = false;
  static int currentPage = 1;
  static String? lastKnownProjectProviderId;
  static bool hasSavedFilters = false;
  /// Entries show as a spreadsheet (true, default) or as the card list (false).
  static bool tableView = true;
  /// "By type" shows the 3-column cost-card grid (true, default) or the list.
  static bool byTypeGrid = true;

  /// Reload what Reports shows, in order: projects (and the global project's
  /// entries), then the entries for the project Reports is filtered to (all
  /// projects when 'all'). Awaited in sequence so a later global-project load
  /// can no longer overwrite the Reports list and leave every total at 0.
  static Future<void> reloadEntries(BuildContext context) async {
    final projectProvider = context.read<ProjectProvider>();
    await projectProvider.load();
    await projectProvider.loadEntriesForProject(
      selectedProjectId == 'all' ? null : selectedProjectId,
    );
  }

  /// Clear every saved Reports filter (call on logout / account switch).
  static void reset() {
    selectedProjectId = 'all';
    selectedFloor = null;
    selectedPhaseId = null;
    selectedActivityName = null;
    searchQuery = '';
    selectedItemName = null;
    selectedTypes = {
      EntryType.material,
      EntryType.labour,
      EntryType.equipment,
    };
    selectedStatus = 'All';
    startDate = null;
    endDate = null;
    datePreset = 'All Time';
    sortColumn = 'date';
    sortAscending = false;
    currentPage = 1;
    lastKnownProjectProviderId = null;
    hasSavedFilters = false;
    tableView = true;
    byTypeGrid = true;
  }
}

class _ReportsView extends StatefulWidget {
  _ReportsView();
  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView> {
  final GlobalKey _chartsKey = GlobalKey();
  // Guided tour: one key per control, walked in visual order (see _tourKeys).
  final _kAccount = GlobalKey();
  final _kHeaderExport = GlobalKey();
  final _kProject = GlobalKey();
  final _kPeriod = GlobalKey();
  final _kWhere = GlobalKey();
  final _kTabs = GlobalKey();
  final _kSearch = GlobalKey();
  final _kItem = GlobalKey();
  final _kEditColumns = GlobalKey();
  final _kSort = GlobalKey();
  final _kExport = GlobalKey();
  final _kFullScreen = GlobalKey();
  final _kViewToggle = GlobalKey();
  final _kSheet = GlobalKey();
  final _kSheetHeader = GlobalKey();
  final _kSheetScroll = GlobalKey();
  final _kList = GlobalKey();
  final _kPager = GlobalKey();
  final _kQuickTiles = GlobalKey();
  final _kByType = GlobalKey();
  final _kByTypeToggle = GlobalKey();
  final _kCsvRevert = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  bool _linked = false;
  String _selectedProjectId = ReportFilterState.selectedProjectId;
  String? _selectedFloor = ReportFilterState.selectedFloor;
  String? _selectedPhaseId = ReportFilterState.selectedPhaseId;
  String? _selectedActivityName = ReportFilterState.selectedActivityName;
  String _searchQuery = ReportFilterState.searchQuery;
  String? _selectedItemName = ReportFilterState.selectedItemName;
  bool _showSuggestions = false;
  /// Search field shown under the toolbar (always shown while a search is active).
  bool _searchOpen = false;
  late final TextEditingController _searchController =
      TextEditingController(text: ReportFilterState.searchQuery);
  Set<EntryType> _selectedTypes = Set.from(ReportFilterState.selectedTypes);
  String _selectedStatus = ReportFilterState.selectedStatus;
  DateTime? _startDate = ReportFilterState.startDate;
  DateTime? _endDate = ReportFilterState.endDate;
  String _datePreset = ReportFilterState.datePreset;
  bool _isImportingCsv = false;
  String _sortColumn = ReportFilterState.sortColumn;
  bool _sortAscending = ReportFilterState.sortAscending;
  int _currentPage = ReportFilterState.currentPage;
  int _rowsPerPage = 10;
  bool _tableView = ReportFilterState.tableView;
  bool _byTypeGrid = ReportFilterState.byTypeGrid;
  List<String> _activeColumnsAll = [
    'Purchased Date',
    'Project',
    'Type',
    'Description',
    'Brand',
    'Floor',
    'Phase',
    'Activity',
    'Unit',
    'Status',
    'Amount',
    'Paid',
    'Remaining',
    'Payment Date',
  ];
  List<String> _activeColumnsMaterials = [
    'Purchased Date',
    'Project',
    'Material',
    'Brand',
    'Rate',
    'Qty',
    'Unit',
    'Status',
    'Amount',
    'Paid',
    'Remaining',
    'Payment Date',
  ];
  List<String> _activeColumnsLabour = [
    'Purchased Date',
    'Project',
    'Worker Type',
    'Rate/Day',
    'Days',
    'Status',
    'Amount',
    'Paid',
    'Remaining',
    'Payment Date',
  ];
  List<String> _activeColumnsEquipment = [
    'Purchased Date',
    'Project',
    'Equipment',
    'Rent Rate',
    'Duration',
    'Status',
    'Amount',
    'Paid',
    'Remaining',
    'Payment Date',
  ];
  @override
  void initState() {
    super.initState();
    _loadActiveColumns();
    // Highlight the Reports tab after the first frame (notifying the nav
    // controller inside build() marks other widgets dirty mid-build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NavController>().markCurrent('/reports');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!UserSession.hasSkippedTour && !UserSession.visitedModules.contains('ReportsScreen')) {
        // Let the first entries arrive so the sheet steps can be shown too.
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        _startTour();
        UserSession.markModuleVisited('ReportsScreen');
      }
    });
  }

  /// Every Reports control in visual order (top to bottom, left to right).
  /// Only keys whose widgets are on screen right now are used.
  List<GlobalKey> _tourKeys() => renderedTourKeys(context, [
        _kProject,
        _kPeriod,
        ShowcaseKeys.reportFilters,
        _kWhere,
        _kHeaderExport,
        _kAccount,
        _kTabs,
        _kSearch,
        _kItem,
        _kEditColumns,
        _kSort,
        _kExport,
        _kFullScreen,
        _kViewToggle,
        _chartsKey,
        _kSheet,
        _kSheetHeader,
        _kSheetScroll,
        _kList,
        _kPager,
        ShowcaseKeys.reportAskAI,
        _kQuickTiles,
        _kByType,
        _kByTypeToggle,
        ShowcaseKeys.reportCSV,
        _kCsvRevert,
        ShowcaseKeys.helpButton,
      ]);

  void _startTour() {
    final keys = _tourKeys();
    if (keys.isNotEmpty) ShowCaseWidget.of(context).startShowCase(keys);
  }

  /// One tour step: a short title and a plain explanation.
  Widget _tour(GlobalKey key, String title, String description, Widget child, {double radius = 14}) {
    return Showcase(
      key: key,
      title: title,
      description: description,
      tooltipBackgroundColor: Bt.ink,
      textColor: Colors.white,
      titleTextStyle: BtText.body(context, color: Colors.white, weight: FontWeight.w700),
      descTextStyle: BtText.subhead(context, color: Colors.white.withValues(alpha: .85)),
      tooltipBorderRadius: BorderRadius.circular(16),
      tooltipPadding: const EdgeInsets.all(16),
      targetBorderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }

  static const _columnTabs = ['All', 'Materials', 'Labour', 'Equipment'];

  /// The user's pinned (frozen, left) column per tab; null = the default
  /// (the item column: Description / Material / Worker Type / Equipment).
  final Map<String, String?> _pinnedColumns = {};

  /// Tabs whose columns were changed before the saved ones finished loading;
  /// the late load must not overwrite them.
  final Set<String> _editedColumnTabs = {};
  bool _columnsLoaded = false;

  static String _columnTab(String tab) => _columnTabs.contains(tab) ? tab : 'All';

  /// A saved column list, minus names this tab doesn't have (older builds /
  /// the web app) and duplicates. Null when nothing usable is left.
  List<String>? _cleanColumns(String tab, dynamic raw) {
    if (raw is! List) return null;
    final allowed = _getAllColumnsForTab(tab).toSet();
    final out = <String>[];
    for (final v in raw) {
      final c = v?.toString();
      if (c != null && allowed.contains(c) && !out.contains(c)) out.add(c);
    }
    return out.isEmpty ? null : out;
  }

  String? _cleanPin(String tab, dynamic raw) {
    final c = raw?.toString();
    return c != null && _getAllColumnsForTab(tab).contains(c) ? c : null;
  }

  /// Saved columns (order + pinned column) per tab: this device first, then
  /// the profile (so they follow the user to another phone).
  Future<void> _loadActiveColumns() async {
    final userId = UserSession.userId;
    final cols = <String, List<String>?>{};
    final pins = <String, String?>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final t in _columnTabs) {
        cols[t] = _cleanColumns(t, prefs.getStringList('activeColumns${t}_$userId'));
        pins[t] = _cleanPin(t, prefs.getString('reportPinnedColumn${t}_$userId'));
      }
    } catch (_) {}

    try {
      final res = await ApiService.get('/users/profile');
      if (res.statusCode == 200) {
        final saved = json.decode(res.body)?['user']?['preferences'];
        if (saved is Map) {
          final rc = saved['reportColumns'];
          final rp = saved['reportPinnedColumns'];
          for (final t in _columnTabs) {
            if (rc is Map) cols[t] = _cleanColumns(t, rc[t]) ?? cols[t];
            if (rp is Map && rp.containsKey(t)) pins[t] = _cleanPin(t, rp[t]);
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      for (final t in _columnTabs) {
        if (_editedColumnTabs.contains(t)) continue;
        final c = cols[t];
        if (c != null) _storeActiveColumns(t, c);
        _pinnedColumns[t] = pins[t];
      }
    });
    _columnsLoaded = true;
    // Columns edited while loading were saved without the other tabs'
    // saved lists; save again now that every tab is known.
    if (_editedColumnTabs.isNotEmpty) _persistColumns();
  }

  void _storeActiveColumns(String tab, List<String> cols) {
    switch (tab) {
      case 'Materials':
        _activeColumnsMaterials = cols;
      case 'Labour':
        _activeColumnsLabour = cols;
      case 'Equipment':
        _activeColumnsEquipment = cols;
      default:
        _activeColumnsAll = cols;
    }
  }

  /// Save every tab's columns + pinned column on this device and to the
  /// profile. The live server merges `preferences` only one level deep, so
  /// all four tabs are sent each time — sending just the edited tab (as
  /// before) replaced `reportColumns` and wiped the other tabs' saved order.
  Future<void> _persistColumns() async {
    final userId = UserSession.userId;
    final cols = {for (final t in _columnTabs) t: List<String>.from(_getActiveColumnsForTab(t))};
    final pins = {for (final t in _columnTabs) t: _pinnedColumns[t]};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final t in _columnTabs) {
        await prefs.setStringList('activeColumns${t}_$userId', cols[t]!);
        final pin = pins[t];
        if (pin == null) {
          await prefs.remove('reportPinnedColumn${t}_$userId');
        } else {
          await prefs.setString('reportPinnedColumn${t}_$userId', pin);
        }
      }
    } catch (_) {}
    if (!_columnsLoaded) return; // the load finishing will send everything
    try {
      await ApiService.put('/users/profile', {
        'preferences': {'reportColumns': cols, 'reportPinnedColumns': pins},
      });
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_linked) {
      _linked = true;
      final projectProvider = context.read<ProjectProvider>();
      final reportProvider = context.read<ReportProvider>();
      reportProvider.linkProjectProvider(projectProvider);
      
      final currentGlobalProjId = projectProvider.selectedProject?.id;
      // Follow the app's selected project only. The floor / phase / activity
      // picked while adding an entry are not Reports filters, so they are not
      // copied (that narrowed Reports to one activity after every save).
      final followGlobal = currentGlobalProjId != null &&
          (!ReportFilterState.hasSavedFilters ||
              (ReportFilterState.lastKnownProjectProviderId != null &&
                  currentGlobalProjId != ReportFilterState.lastKnownProjectProviderId));
      if (followGlobal) {
        if (ReportFilterState.selectedProjectId != currentGlobalProjId) {
          ReportFilterState.selectedFloor = null;
          ReportFilterState.selectedPhaseId = null;
          ReportFilterState.selectedActivityName = null;
          ReportFilterState.currentPage = 1;
        }
        ReportFilterState.selectedProjectId = currentGlobalProjId;
        ReportFilterState.lastKnownProjectProviderId = currentGlobalProjId;
      }

      _selectedProjectId = ReportFilterState.selectedProjectId;
      _selectedFloor = ReportFilterState.selectedFloor;
      _selectedPhaseId = ReportFilterState.selectedPhaseId;
      _selectedActivityName = ReportFilterState.selectedActivityName;
      _searchQuery = ReportFilterState.searchQuery;
      if (_searchController.text != ReportFilterState.searchQuery) {
        _searchController.text = ReportFilterState.searchQuery;
      }
      _selectedItemName = ReportFilterState.selectedItemName;
      _selectedTypes = Set.from(ReportFilterState.selectedTypes);
      _selectedStatus = ReportFilterState.selectedStatus;
      _startDate = ReportFilterState.startDate;
      _endDate = ReportFilterState.endDate;
      _datePreset = ReportFilterState.datePreset;
      _sortColumn = ReportFilterState.sortColumn;
      _sortAscending = ReportFilterState.sortAscending;
      _currentPage = ReportFilterState.currentPage;

      final loadId = _selectedProjectId == 'all' ? null : _selectedProjectId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          reportProvider.selectProject(_selectedProjectId);
          projectProvider.loadEntriesForProject(loadId);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getAllColumnsForTab(String tabName) {
    if (tabName == 'Materials') {
      return [
        'Purchased Date',
        'Project',
        'Material',
        'Brand',
        'Rate',
        'Qty',
        'Unit',
        'Floor',
        'Phase',
        'Activity',
        'Status',
        'Amount',
        'Paid',
        'Remaining',
        'Payment Date',
      ];
    } else if (tabName == 'Labour') {
      return [
        'Purchased Date',
        'Project',
        'Worker Type',
        'Rate/Day',
        'Days',
        'Unit',
        'Floor',
        'Phase',
        'Activity',
        'Status',
        'Amount',
        'Paid',
        'Remaining',
        'Payment Date',
      ];
    } else if (tabName == 'Equipment') {
      return [
        'Purchased Date',
        'Project',
        'Equipment',
        'Rent Rate',
        'Duration',
        'Unit',
        'Floor',
        'Phase',
        'Activity',
        'Status',
        'Amount',
        'Paid',
        'Remaining',
        'Payment Date',
      ];
    } else {
      return [
        'Purchased Date',
        'Project',
        'Type',
        'Description',
        'Brand',
        'Floor',
        'Phase',
        'Activity',
        'Unit',
        'Status',
        'Amount',
        'Paid',
        'Remaining',
        'Payment Date',
      ];
    }
  }

  List<String> _getActiveColumnsForTab(String tabName) {
    if (tabName == 'Materials') {
      return _activeColumnsMaterials;
    } else if (tabName == 'Labour') {
      return _activeColumnsLabour;
    } else if (tabName == 'Equipment') {
      return _activeColumnsEquipment;
    } else {
      return _activeColumnsAll;
    }
  }

  void _setActiveColumnsForTab(String tabName, List<String> cols, String? pinned) {
    final tab = _columnTab(tabName);
    _editedColumnTabs.add(tab);
    setState(() {
      _storeActiveColumns(tab, cols);
      _pinnedColumns[tab] = pinned;
    });
    _persistColumns();
  }

  /// Long-press on a sheet heading: freeze that column on the left.
  void _pinColumn(String tabName, String column) {
    final tab = _columnTab(tabName);
    final cols = List<String>.from(_getActiveColumnsForTab(tab));
    if (!cols.contains(column)) cols.add(column);
    _setActiveColumnsForTab(tab, cols, column);
    btToast(context, '${_columnLabel(column)} is now pinned on the left');
  }

  /// The tab's columns in on-screen order (pinned first) — the sheet and
  /// both exports use this, so files match what the user sees.
  List<String> _displayColumns(String tabName) {
    final tab = _columnTab(tabName);
    return ReportSheet.displayOrder(_getActiveColumnsForTab(tab), _pinnedColumns[tab]);
  }

  static String _columnLabel(String column) => column == 'Purchased Date' ? 'Purchase date' : _sentence(column);

  void _showCustomizeColumnsDialog(BuildContext context, String tabName) {
    final tab = _columnTab(tabName);
    final List<String> allCols = _getAllColumnsForTab(tab);
    List<String> tempActive = List.from(_getActiveColumnsForTab(tab));
    final inactive = allCols.where((c) => !tempActive.contains(c)).toList();
    List<String> tempAll = [...tempActive, ...inactive];
    // The user's own pick; null = default (the item column).
    String? tempPinned = _pinnedColumns[tab];
    // Keep the shown list in the dragged order.
    void syncActive() => tempActive = [for (final c in tempAll) if (tempActive.contains(c)) c];
    showModalBottomSheet(
      context: context,
      sheetAnimationStyle: btSheetStyleDefault(context),
      isScrollControlled: true,
      useSafeArea: true,
      // Dragging a row must not drag the sheet closed.
      enableDrag: false,
      backgroundColor: Bt.card,
      barrierColor: Bt.scrim,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final maxListH = MediaQuery.of(context).size.height * 0.55;
            final pinned = ReportSheet.pinnedOf(tempActive, tempPinned);
            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BtSheetHeader(
                    title: 'Edit columns',
                    subtitle: '${tempActive.length} of ${tempAll.length} shown · drag ≡ to reorder · tap the pin to freeze a column on the left',
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxListH),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Bt.card,
                          borderRadius: BorderRadius.circular(Bt.rCard),
                          border: Border.all(color: Bt.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          buildDefaultDragHandles: false,
                          itemCount: tempAll.length,
                          onReorder: (oldIndex, newIndex) {
                            setDialogState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = tempAll.removeAt(oldIndex);
                              tempAll.insert(newIndex, item);
                              syncActive();
                            });
                          },
                          itemBuilder: (context, index) {
                            final col = tempAll[index];
                            final isChecked = tempActive.contains(col);
                            final isPinned = col == pinned;
                            return Material(
                              key: ValueKey(col),
                              color: Bt.card,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (index > 0) const Divider(height: 1, indent: 16, color: Bt.line),
                                  SizedBox(
                                    height: 56,
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(col, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, color: isChecked ? Bt.ink : Bt.ink3)),
                                              if (isPinned)
                                                Text('Pinned · always first, stays put', maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context).copyWith(fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Semantics(
                                          button: true,
                                          selected: isPinned,
                                          label: isPinned ? '$col is pinned' : 'Pin $col on the left',
                                          excludeSemantics: true,
                                          child: InkResponse(
                                            radius: 22,
                                            onTap: () => setDialogState(() {
                                              tempPinned = col;
                                              if (!tempActive.contains(col)) {
                                                tempActive.add(col);
                                                syncActive();
                                              }
                                            }),
                                            child: SizedBox(
                                              width: 44,
                                              height: 56,
                                              child: Icon(
                                                isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                                size: 19,
                                                color: isPinned ? context.bt.accentInk : Bt.placeholder,
                                              ),
                                            ),
                                          ),
                                        ),
                                        BtSwitch(
                                          value: isChecked,
                                          onChanged: (val) {
                                            setDialogState(() {
                                              if (val == true) {
                                                tempActive.add(col);
                                                syncActive();
                                              } else if (tempActive.length > 1) {
                                                tempActive.remove(col);
                                                // A hidden column can't stay pinned.
                                                if (tempPinned == col) tempPinned = null;
                                              } else {
                                                btToast(context, 'At least one column must be visible.', error: true);
                                              }
                                            });
                                          },
                                        ),
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: const SizedBox(
                                            width: 48,
                                            height: 56,
                                            child: Icon(Icons.drag_handle_rounded, size: 22, color: Bt.ink3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: BtButton(
                            label: 'Reset',
                            variant: BtButtonVariant.secondary,
                            onPressed: () {
                              setDialogState(() {
                                tempActive = List.from(allCols);
                                tempAll = List.from(allCols);
                                tempPinned = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: BtButton(
                            label: 'Save',
                            onPressed: () {
                              _setActiveColumnsForTab(tab, List.of(tempActive), tempPinned);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateShort(DateTime dt) {
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
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year.toString().substring(dt.year.toString().length - 2);
    return '$day $month $year';
  }

  String _formatDateLong(DateTime dt) {
    final isMidnightLocal = dt.hour == 0 && dt.minute == 0 && dt.second == 0;

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

    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;

    if (isMidnightLocal) {
      return '$day $month $year';
    }

    final hour24 = dt.hour;
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    var hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    final hour = hour12.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute $ampm';
  }

  String _formatIndianCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final decimal = parts[1];
    if (whole.length <= 3) {
      return '₹$whole.$decimal';
    }
    final lastThree = whole.substring(whole.length - 3);
    final remaining = whole.substring(0, whole.length - 3);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = remaining.length - 1; i >= 0; i--) {
      if (count > 0 && count % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
      count++;
    }
    final formattedRemaining = buffer.toString().split('').reversed.join('');
    return '₹$formattedRemaining,$lastThree.$decimal';
  }

  void _setDatePreset(String preset) {
    setState(() {
      _datePreset = preset;
      final now = DateTime.now();
      _currentPage = 1;
      switch (preset) {
        case 'All Time':
          _startDate = null;
          _endDate = null;
          break;
        case 'Today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'This Week':
          final weekday = now.weekday;
          final start = now.subtract(Duration(days: weekday - 1));
          _startDate = DateTime(start.year, start.month, start.day);
          _endDate = null;
          break;
        case 'This Month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = null;
          break;
        case 'Last 30 Days':
          _startDate = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: 30));
          _endDate = null;
          break;
        case 'This Year':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = null;
          break;
        case 'Custom':
          break;
      }
      ReportFilterState.datePreset = _datePreset;
      ReportFilterState.startDate = _startDate;
      ReportFilterState.endDate = _endDate;
      ReportFilterState.currentPage = 1;
      ReportFilterState.hasSavedFilters = true;
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _datePreset = 'Custom';
        _currentPage = 1;
        ReportFilterState.startDate = picked;
        ReportFilterState.datePreset = 'Custom';
        ReportFilterState.currentPage = 1;
        ReportFilterState.hasSavedFilters = true;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _datePreset = 'Custom';
        _currentPage = 1;
        ReportFilterState.endDate = picked;
        ReportFilterState.datePreset = 'Custom';
        ReportFilterState.currentPage = 1;
        ReportFilterState.hasSavedFilters = true;
      });
    }
  }

  Future<void> _handleCsvExport(
    List<EntryModel> filtered,
    String Function(String) getProjectName,
    String quickCategoryTab, {
    List<String>? activeColumns,
  }) async {
    if (filtered.isEmpty) {
      btToast(context, 'No report entries to export.', error: true);
      return;
    }
    try {
      await ReportExportHelper.exportToCsv(
        entries: filtered,
        getProjectName: getProjectName,
        quickCategoryTab: quickCategoryTab,
        activeColumns: activeColumns,
      );
    } catch (e) {
      btToast(context, 'CSV Export failed: $e', error: true);
    }
  }

  Future<void> _handlePdfExport(
    List<EntryModel> filtered,
    String Function(String) getProjectName,
    String quickCategoryTab, {
    List<String>? activeColumns,
  }) async {
    if (filtered.isEmpty) {
      btToast(context, 'No report entries to export.', error: true);
      return;
    }
    try {
      final List<String> parts = [];
      if (_selectedProjectId != 'all') {
        parts.add('Project: ${getProjectName(_selectedProjectId)}');
        if (_selectedFloor != null) {
          parts.add('Floor: $_selectedFloor');
        }
        if (_selectedPhaseId != null) {
          final projectProvider = context.read<ProjectProvider>();
          final proj = projectProvider.projects
              .where((p) => p.id == _selectedProjectId)
              .firstOrNull;
          final phaseName = proj?.selectedPhases
              ?.where((ph) => ph.id == _selectedPhaseId)
              .firstOrNull
              ?.phaseName;
          parts.add('Phase: ${phaseName ?? _selectedPhaseId}');
        }
        if (_selectedActivityName != null) {
          parts.add('Activity: $_selectedActivityName');
        }
      } else {
        parts.add('All Projects');
      }
      parts.add(
        'Types: ${_selectedTypes.map((t) => t.name.toUpperCase()).join(", ")}',
      );
      parts.add('Status: $_selectedStatus');
      parts.add('Date Range: $_datePreset');
      await ReportExportHelper.exportToPdf(
        entries: filtered,
        getProjectName: getProjectName,
        title: _selectedProjectId == 'all'
            ? 'All Active Projects Summary Report'
            : '${getProjectName(_selectedProjectId)} Report',
        filterSummary: parts.join(' | '),
        quickCategoryTab: quickCategoryTab,
        activeColumns: activeColumns,
      );
    } catch (e) {
      btToast(context, 'PDF Export failed: $e', error: true);
    }
  }

  /// Same template as Add Entry (shared generator in csv_import_helper.dart).
  Future<void> _handleDownloadImportTemplate() async {
    try {
      await CsvImportHelper.downloadTemplate();
      if (mounted) {
        btToast(context, 'Import template downloaded!');
      }
    } catch (e) {
      if (mounted) {
        btToast(context, 'Template download failed: $e', error: true);
      }
    }
  }

  Future<void> _openTemplateColumns() async {
    final cols = await CsvTemplate.openColumnsSheet(context);
    if (cols != null && mounted) {
      btToast(context, 'Template columns saved · ${cols.length} columns');
    }
  }

  Future<void> _handleRevertCsv() async {
    final confirm = await btConfirm(
      context,
      title: 'Revert Last Upload',
      message: 'Are you sure you want to undo the last CSV import? This will restore the transactions to their previous state.',
      confirmLabel: 'Revert',
    );
    if (confirm != true) return;
    
    setState(() => _isImportingCsv = true);
    final success = await ApiService.revertCsv();
    if (!mounted) return;
    setState(() => _isImportingCsv = false);
    
    if (success) {
      if (mounted) {
        btToast(context, 'Successfully reverted last CSV import');
        ReportFilterState.reloadEntries(context);
      }
    } else {
      if (mounted) {
        btToast(context, 'Failed to revert CSV import', error: true);
      }
    }
  }

  Future<void> _handleUploadCsv() async {
    final projectProvider = context.read<ProjectProvider>();
    if (projectProvider.projects.isEmpty) {
      await projectProvider.load();
    }
    setState(() => _isImportingCsv = true);
    try {
      final result = await CsvImportHelper.importCsv(
        projects: projectProvider.projects,
        defaultProject: _selectedProjectId == 'all'
            ? null
            : projectProvider.projects.where((p) => p.id == _selectedProjectId).firstOrNull,
      );
      if (result == null || !mounted) return; // picker cancelled
      ReportFilterState.reloadEntries(context);
      showDialog(
        context: context,
        barrierColor: Bt.scrim,
        builder: (ctx) => AlertDialog(
          backgroundColor: Bt.card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          title: Text('Import Results', style: BtText.d3(ctx)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Total rows processed: ${result.totalRows}', style: BtText.subhead(ctx)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Bt.greenSoft, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Successfully imported: ${result.successCount}',
                        style: BtText.num(BtText.body(ctx, color: Bt.green, weight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 4),
                      Text('• Materials: ${result.materialCount}', style: BtText.num(BtText.subhead(ctx, color: Bt.ink))),
                      Text('• Labour: ${result.labourCount}', style: BtText.num(BtText.subhead(ctx, color: Bt.ink))),
                      Text('• Equipment: ${result.equipmentCount}', style: BtText.num(BtText.subhead(ctx, color: Bt.ink))),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Failed: ${result.failedCount}',
                  style: BtText.num(BtText.body(ctx, color: result.failedCount > 0 ? Bt.red : Bt.ink3, weight: FontWeight.w600)),
                ),
                if (result.errors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('DETAILS/ERRORS', style: BtText.mono(ctx)),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Bt.redSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: result.errors.map((err) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(err, style: BtText.caption(ctx, color: Bt.red)),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            BtButton(label: 'OK', small: true, onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        btToast(context, 'Import failed: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _isImportingCsv = false);
    }
  }

  /// Bulk import — same template and parser as Add Entry (csv_import_helper.dart).
  Widget _buildCsvImportCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BtSectionHeader(title: 'Import from a spreadsheet'),
        _tour(
          ShowcaseKeys.reportCSV,
          'Import many entries',
          'Download the template (the same one as on Add Entry), choose its columns, fill one row per entry, then upload the CSV — each row becomes an entry.',
          BtGroup(
            children: [
              BtRow(
                leading: const BtTile(icon: Icons.download_rounded),
                title: 'Download template',
                subtitle: 'Same template as Add Entry',
                showChevron: true,
                onTap: _isImportingCsv ? null : _handleDownloadImportTemplate,
              ),
              BtRow(
                leading: const BtTile(icon: Icons.view_column_outlined),
                title: 'Customize columns',
                subtitle: 'Pick and reorder template columns',
                showChevron: true,
                onTap: _isImportingCsv ? null : _openTemplateColumns,
              ),
              BtRow(
                leading: _isImportingCsv
                    ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                    : const BtTile(icon: Icons.upload_file_rounded),
                title: _isImportingCsv ? 'Importing…' : 'Upload CSV file',
                subtitle: 'Adds every row as an entry',
                titleColor: context.bt.brand,
                titleWeight: FontWeight.w600,
                onTap: _isImportingCsv ? null : _handleUploadCsv,
              ),
            ],
          ),
          radius: Bt.rCard,
        ),
        const SizedBox(height: 12),
        _tour(
          _kCsvRevert,
          'Undo an import',
          'Made a mistake in the file? This puts back what was there before your last CSV upload.',
          BtGroup(
            children: [
              BtRow(
                leading: BtTile(icon: Icons.undo_rounded, bg: Bt.redSoft, fg: Bt.red),
                title: 'Revert last CSV import…',
                titleColor: Bt.red,
                onTap: _isImportingCsv ? null : _handleRevertCsv,
              ),
            ],
          ),
          radius: Bt.rCard,
        ),
      ],
    );
  }

  /// Keep filters across visits (main: ReportFilterState). Every state change in this
  /// screen is a filter/sort/page change, so mirror it once here instead of at each call site.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    ReportFilterState.selectedProjectId = _selectedProjectId;
    ReportFilterState.selectedFloor = _selectedFloor;
    ReportFilterState.selectedPhaseId = _selectedPhaseId;
    ReportFilterState.selectedActivityName = _selectedActivityName;
    ReportFilterState.searchQuery = _searchQuery;
    ReportFilterState.selectedItemName = _selectedItemName;
    ReportFilterState.selectedTypes = Set.from(_selectedTypes);
    ReportFilterState.selectedStatus = _selectedStatus;
    ReportFilterState.startDate = _startDate;
    ReportFilterState.endDate = _endDate;
    ReportFilterState.datePreset = _datePreset;
    ReportFilterState.sortColumn = _sortColumn;
    ReportFilterState.sortAscending = _sortAscending;
    ReportFilterState.currentPage = _currentPage;
    ReportFilterState.hasSavedFilters = true;
  }

  String _quickTab() {
    String quickCategoryTab = 'All';
    if (_selectedTypes.length == 1) {
      if (_selectedTypes.contains(EntryType.material)) {
        quickCategoryTab = 'Materials';
      } else if (_selectedTypes.contains(EntryType.labour)) {
        quickCategoryTab = 'Labour';
      } else if (_selectedTypes.contains(EntryType.equipment)) {
        quickCategoryTab = 'Equipment';
      }
    } else if (_selectedTypes.length == 3) {
      quickCategoryTab = 'All';
    } else {
      quickCategoryTab = '';
    }
    return quickCategoryTab;
  }

  /// Every word typed must appear somewhere in the entry: its text fields
  /// (item, contractor, supplier, worker, notes, payment notes…), project,
  /// payment status, dates or amounts. "ravi cement" finds Ravi's cement entries.
  bool _matchesSearch(EntryModel entry, String projectName, String rawQuery) {
    final query = rawQuery.toLowerCase().trim();
    if (query.isEmpty) return true;
    final text = _searchTextOf(entry);
    final extra = [
      projectName.toLowerCase(),
      _getPaymentStatusLabel(entry.paymentStatus, amount: entry.amount, paidAmount: entry.paidAmount).toLowerCase(),
      _formatDateShort(entry.date).toLowerCase(),
      formatDate(entry.date).toLowerCase(),
      if (entry.paymentDate != null) _formatDateShort(entry.paymentDate!).toLowerCase(),
      if (entry.paymentDate != null) formatDate(entry.paymentDate).toLowerCase(),
      for (final v in [entry.amount, entry.ratePerUnit ?? 0, entry.paidAmount, entry.remainingAmount]) ...[
        _formatIndianCurrency(v).toLowerCase(),
        formatInr(v).toLowerCase(),
      ],
    ].join('\u0001');
    final numbers = [
      for (final v in [entry.amount, entry.ratePerUnit, entry.paidAmount, entry.remainingAmount, entry.quantity])
        if (v != null) ...[v.toString(), v.toInt().toString(), v.toStringAsFixed(2)],
    ].join(' ');

    bool tokenMatches(String token) {
      if (text.contains(token) || extra.contains(token)) return true;
      final cleanNumeric = token
          .replaceAll(RegExp(r'^(rs\.?|₹)\s*', caseSensitive: false), '')
          .replaceAll(',', '')
          .trim();
      return cleanNumeric.isNotEmpty &&
          RegExp(r'^[\d.]+$').hasMatch(cleanNumeric) &&
          numbers.contains(cleanNumeric);
    }

    if (tokenMatches(query)) return true;
    final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    return tokens.length > 1 && tokens.every(tokenMatches);
  }

  /// Lower-cased searchable text for an entry, built once per entry object.
  static final Expando<String> _searchTextCache = Expando<String>();
  static String _searchTextOf(EntryModel e) {
    final cached = _searchTextCache[e];
    if (cached != null) return cached;
    final out = StringBuffer();
    void add(String? v) {
      final s = v?.trim();
      if (s != null && s.isNotEmpty) out..write(s.toLowerCase())..write('\u0001');
    }

    for (final v in [
      e.description, e.brand, e.contractor, e.supplier, e.category, e.workerName,
      e.notes, e.remarks, e.floor, e.phase, e.activity, e.unit, e.type.name,
      e.approvedBy, e.paymentMode, e.rejectionReason,
    ]) {
      add(v);
    }
    for (final p in e.paymentHistory) {
      _collectSearchText(p, add);
    }
    if (e.rawJson != null) _collectSearchText(e.rawJson, add);
    return _searchTextCache[e] = out.toString();
  }

  List<EntryModel> _filterEntries(ProjectProvider projectProvider, String quickCategoryTab) {
    final List<EntryModel> allEntries = projectProvider.entries;
    String getProjectName(String id) {
      return projectProvider.projects
              .where((p) => p.id == id)
              .firstOrNull
              ?.name ??
          'Unknown Project';
    }

    return allEntries.where((entry) {
      if (_selectedProjectId != 'all' &&
          entry.projectId.trim() != _selectedProjectId.trim()) {
        return false;
      }
      if (_selectedProjectId != 'all') {
        if (_selectedFloor != null && _selectedFloor != 'Select Floor') {
          if (entry.floor != _selectedFloor) return false;
        }
        if (_selectedPhaseId != null && _selectedPhaseId != 'Select Phase') {
          final project = projectProvider.projects
              .where((p) => p.id == _selectedProjectId)
              .firstOrNull;
          final phaseName = project?.selectedPhases
              ?.where((ph) => ph.id == _selectedPhaseId)
              .firstOrNull
              ?.phaseName;
          if (entry.phaseId != _selectedPhaseId &&
              (phaseName == null || entry.phase != phaseName)) {
            return false;
          }
        }
        if (_selectedActivityName != null &&
            _selectedActivityName != 'Select Activity') {
          if (entry.activity != _selectedActivityName &&
              entry.description != _selectedActivityName) {
            return false;
          }
        }
      }
      if (!_selectedTypes.contains(entry.type)) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !_matchesSearch(entry, getProjectName(entry.projectId), _searchQuery)) {
        return false;
      }
      if (quickCategoryTab != 'All' &&
          _selectedItemName != null &&
          _selectedItemName != 'All') {
        final matchesItem = entry.description == _selectedItemName ||
            entry.brand == _selectedItemName ||
            entry.contractor == _selectedItemName ||
            entry.category == _selectedItemName ||
            entry.supplier == _selectedItemName ||
            entry.workerName == _selectedItemName;
        if (!matchesItem) return false;
      }
      if (_selectedStatus != 'All') {
        final computedLabel = _getPaymentStatusLabel(
          entry.paymentStatus,
          amount: entry.amount,
          paidAmount: entry.paidAmount,
        );
        if (computedLabel.toLowerCase() != _selectedStatus.toLowerCase()) {
          return false;
        }
      }
      if (_startDate != null) {
        final entryDate = DateTime(
          entry.date.year,
          entry.date.month,
          entry.date.day,
        );
        final start = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );
        if (entryDate.isBefore(start)) return false;
      }
      if (_endDate != null) {
        final entryDate = DateTime(
          entry.date.year,
          entry.date.month,
          entry.date.day,
        );
        final end = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
        ).add(Duration(days: 1));
        if (!entryDate.isBefore(end)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    final List<EntryModel> allEntries = projectProvider.entries;
    String getProjectName(String id) {
      return projectProvider.projects
              .where((p) => p.id == id)
              .firstOrNull
              ?.name ??
          'Unknown Project';
    }

    final quickCategoryTab = _quickTab();
    final filtered = _filterEntries(projectProvider, quickCategoryTab);
    filtered.sort((a, b) => compareReportEntries(a, b, _sortColumn, _sortAscending, getProjectName));
    double materialTotal = 0;
    double labourTotal = 0;
    double equipmentTotal = 0;
    double grandTotal = 0;
    double grandPaid = 0;
    for (final entry in filtered) {
      grandTotal += entry.amount;
      grandPaid += entry.paidAmount;
      switch (entry.type) {
        case EntryType.material:
          materialTotal += entry.amount;
          break;
        case EntryType.labour:
          labourTotal += entry.amount;
          break;
        case EntryType.equipment:
          equipmentTotal += entry.amount;
          break;
      }
    }
    final grandRemaining = (grandTotal - grandPaid).clamp(0.0, double.infinity);
    final totalCount = filtered.length;
    final totalPages = (totalCount / _rowsPerPage).ceil() == 0
        ? 1
        : (totalCount / _rowsPerPage).ceil();
    int safeCurrentPage = _currentPage;
    if (safeCurrentPage > totalPages) safeCurrentPage = totalPages;
    if (safeCurrentPage < 1) safeCurrentPage = 1;
    final startIndex = (safeCurrentPage - 1) * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < totalCount)
        ? startIndex + _rowsPerPage
        : totalCount;
    final List<EntryModel> paginatedEntries = (totalCount > 0)
        ? filtered.sublist(startIndex, endIndex)
        : [];
    // Pinned column first, then the saved order — same for sheet and exports.
    final List<String> activeCols = _displayColumns(quickCategoryTab);
    final String? pinnedCol = activeCols.isEmpty ? null : activeCols.first;
    void onPinColumn(String column) => _pinColumn(quickCategoryTab, column);
    final bt = context.bt;
    final entriesTitle = quickCategoryTab == 'All' || quickCategoryTab.isEmpty
        ? 'Entries'
        : '$quickCategoryTab entries';
    String statusOf(EntryModel e) => _getPaymentStatusLabel(e.paymentStatus, amount: e.amount, paidAmount: e.paidAmount);
    void onSheetSort(String column, bool ascending) => setState(() {
          _sortColumn = column;
          _sortAscending = ascending;
          _currentPage = 1;
          ReportFilterState.sortColumn = column;
          ReportFilterState.sortAscending = ascending;
        });

    void openFullScreen() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _FullScreenLogsViewer(
            // Re-filtered from the live entry list on every rebuild, so rows
            // edited / added / paid from here show their new values.
            entriesOf: (pp) => _filterEntries(pp, quickCategoryTab),
            getProjectName: getProjectName,
            statusOf: statusOf,
            quickCategoryTab: quickCategoryTab,
            title: quickCategoryTab == 'All'
                ? 'Report Logs'
                : '$quickCategoryTab Report Logs',
            // Read at call time: a column pinned in full screen counts too.
            onExportCsv: (rows) => _handleCsvExport(
              rows,
              getProjectName,
              quickCategoryTab,
              activeColumns: _displayColumns(quickCategoryTab),
            ),
            onExportPdf: (rows) => _handlePdfExport(
              rows,
              getProjectName,
              quickCategoryTab,
              activeColumns: _displayColumns(quickCategoryTab),
            ),
            columnsOf: () => _displayColumns(quickCategoryTab),
            onPinColumn: onPinColumn,
            sortColumn: _sortColumn,
            sortAscending: _sortAscending,
            onSort: onSheetSort,
            onRowTap: (e) => _showEntryDetailsDialog(context, e, getProjectName(e.projectId)),
            onAddMore: (e) => _ReportActions.addMore(context, e),
            onRecordPayment: (e) => _ReportActions.recordPayment(context, e, getProjectName(e.projectId)),
            onEdit: (e) => _ReportActions.editEntry(context, e),
          ),
        ),
      );
    }

    void openEditColumns() => _showCustomizeColumnsDialog(context, quickCategoryTab.isEmpty ? 'All' : quickCategoryTab);

    void openExport() {
      final shown = activeCols.length;
      final all = _getAllColumnsForTab(quickCategoryTab.isEmpty ? 'All' : quickCategoryTab).length;
      showBtSheet(
        context,
        title: 'Export',
        subtitle: '$totalCount entries · current filters',
        builder: (sheetCtx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ExportFormatCard(
                    format: 'PDF',
                    title: 'Download PDF',
                    subtitle: 'Ready to print or share',
                    dark: true,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _handlePdfExport(filtered, getProjectName, quickCategoryTab, activeColumns: activeCols);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ExportFormatCard(
                    format: 'CSV',
                    title: 'Download CSV',
                    subtitle: 'Opens in Excel or Google Sheets',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _handleCsvExport(filtered, getProjectName, quickCategoryTab, activeColumns: activeCols);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            BtGroup(
              children: [
                BtRow(
                  leading: const BtTile(icon: Icons.view_column_outlined, size: 38),
                  title: 'Customize columns',
                  subtitle: '$shown of $all shown',
                  showChevron: true,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    openEditColumns();
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    void openEntriesMenu() {
      showBtSheet(
        context,
        title: entriesTitle,
        subtitle: '$totalCount entries',
        builder: (sheetCtx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BtSectionHeader(title: 'Sort by', caption: true),
            BtGroup(
              children: [
                for (final o in const [
                  ['date', false, 'Purchase date: newest first', null],
                  ['date', true, 'Purchase date: oldest first', null],
                  ['paymentDate', false, 'Payment date: newest first', 'Latest payment · unpaid entries last'],
                  ['paymentDate', true, 'Payment date: oldest first', 'Latest payment · unpaid entries last'],
                  ['amount', false, 'Amount: high to low', null],
                  ['amount', true, 'Amount: low to high', null],
                  ['project', true, 'Project name', null],
                ])
                  BtRow(
                    title: o[2] as String,
                    subtitle: o[3] as String?,
                    minHeight: 48,
                    trailing: (_sortColumn == o[0] && _sortAscending == o[1])
                        ? Icon(Icons.check_rounded, color: bt.accentInk, size: 20)
                        : null,
                    onTap: () {
                      setState(() {
                        _sortColumn = o[0] as String;
                        _sortAscending = o[1] as bool;
                        _currentPage = 1;
                      });
                      Navigator.pop(sheetCtx);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            BtGroup(
              children: [
                BtRow(
                  leading: const BtTile(icon: Icons.view_column_outlined),
                  title: 'Edit columns',
                  subtitle: 'For table and exports',
                  showChevron: true,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    openEditColumns();
                  },
                ),
                BtRow(
                  leading: const BtTile(icon: Icons.table_chart_outlined),
                  title: 'Open as table',
                  subtitle: 'Full screen, can rotate',
                  showChevron: true,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    openFullScreen();
                  },
                ),
                BtRow(
                  leading: const BtTile(icon: Icons.ios_share_rounded),
                  title: 'Export',
                  subtitle: 'CSV or PDF',
                  showChevron: true,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    openExport();
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    final project = projectProvider.projects.where((p) => p.id == _selectedProjectId).firstOrNull;
    final projectName = _selectedProjectId == 'all' ? 'All projects' : (project?.name ?? 'Project');
    final projectChip = projectName.length > 18 ? '${projectName.substring(0, 17).trimRight()}…' : projectName;
    final periodChip = _datePreset == 'Custom' && (_startDate != null || _endDate != null)
        ? '${_startDate == null ? '…' : formatShortDate(_startDate)} – ${_endDate == null ? '…' : formatShortDate(_endDate)}'
        : _sentence(_datePreset);
    final showSheet = _tableView && paginatedEntries.isNotEmpty;
    // Floor / phase / activity show on their own chips, so the Filter chip
    // counts only what is set inside the sheet alone (payment status).
    final extraFilters = _selectedStatus == 'All' ? 0 : 1;
    final searchVisible = _searchOpen || _searchQuery.isNotEmpty;
    final showWhere = _showWhereChips(projectProvider);
    final sortLabel = switch (_sortColumn) {
      'amount' => _sortAscending ? 'Amount · low' : 'Amount · high',
      'project' => _sortAscending ? 'Project · A–Z' : 'Project · Z–A',
      'paymentDate' => _sortAscending ? 'Paid on · oldest' : 'Paid on · newest',
      _ => _sortAscending ? 'Purchased · oldest' : 'Purchased · newest',
    };
    final topInset = MediaQuery.paddingOf(context).top;
    final glass = Colors.white.withValues(alpha: .09);

    // ── noir compact header: title + project / period / filter chips + actions
    final header = BtHero(
      overlap: 22,
      padding: EdgeInsets.fromLTRB(Bt.gutter, topInset + 8, Bt.gutter, 12 + 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalCount ${totalCount == 1 ? 'ENTRY' : 'ENTRIES'} · ${periodChip.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BtText.num(BtText.mono(context, color: Bt.onNoir2)),
                    ),
                    const SizedBox(height: 2),
                    Text('Reports', maxLines: 1, style: BtText.d2(context, color: Bt.bone)),
                  ],
                ),
              ),
              _tour(
                ShowcaseKeys.helpButton,
                'Guidelines',
                'Tap here anytime to replay this tour of every Reports control.',
                BtIconButton(
                  icon: Icons.help_outline_rounded,
                  semantic: 'App guidelines',
                  color: Bt.bone,
                  size: 21,
                  background: glass,
                  onTap: _startTour,
                ),
                radius: 22,
              ),
              const SizedBox(width: 6),
              _tour(
                _kHeaderExport,
                'Share the report',
                'Download the entries you are looking at as a CSV (spreadsheet) or PDF file, with the current filters applied.',
                BtIconButton(
                  icon: Icons.ios_share_rounded,
                  semantic: 'Export report',
                  color: Bt.bone,
                  size: 20,
                  background: glass,
                  onTap: openExport,
                ),
                radius: 22,
              ),
              const SizedBox(width: 4),
              _tour(
                _kAccount,
                'Your account',
                'Open your profile, settings and sign out.',
                Semantics(
                  button: true,
                  label: 'Account',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: const Padding(padding: EdgeInsets.all(4), child: ProfileAvatar(radius: 18)),
                  ),
                ),
                radius: 24,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _tour(
                  _kProject,
                  'Project',
                  'Pick one project, or "All projects" to see every active project together. Everything below follows this choice.',
                  BtChip(
                    label: projectChip,
                    onDark: true,
                    trailingIcon: Icons.expand_more_rounded,
                    selected: _selectedProjectId != 'all',
                    onTap: () => _pickProject(context, projectProvider),
                  ),
                  radius: Bt.rChip,
                ),
                const SizedBox(width: 8),
                _tour(
                  _kPeriod,
                  'Period',
                  'Choose the dates to report on: All time, this week, this month… or a custom From–To range.',
                  BtChip(
                    label: periodChip,
                    onDark: true,
                    trailingIcon: Icons.expand_more_rounded,
                    selected: _datePreset != 'All Time',
                    onTap: () => _pickPeriod(context),
                  ),
                  radius: Bt.rChip,
                ),
                const SizedBox(width: 8),
                _tour(
                  ShowcaseKeys.reportFilters,
                  'More filters',
                  'Every filter in one place, including payment status (paid, partial, not paid). The number shows when a payment filter is on.',
                  BtChip(
                    label: extraFilters == 0 ? 'Filter' : 'Filter · $extraFilters',
                    onDark: true,
                    icon: Icons.tune_rounded,
                    selected: extraFilters > 0,
                    onTap: () => _openFilterSheet(context, projectProvider),
                  ),
                  radius: Bt.rChip,
                ),
              ],
            ),
          ),
          if (showWhere) ...[
          const SizedBox(height: 8),
          _tour(
            _kWhere,
            'Floor, phase, activity',
            'Filter by floor, phase and activity in one tap. A chosen filter shows its value — tap × to clear it. Pick a project first.',
            _buildWhereChips(context, projectProvider),
            radius: Bt.rChip,
          ),
          ],
        ],
      ),
    );

    // ── toolbar: search · item · Edit columns · sort · Export · full screen | table/list
    final toolbar = Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.hardEdge,
            child: Row(
              children: [
                _tour(
                  _kSearch,
                  'Search',
                  quickCategoryTab == 'All'
                      ? 'Find entries by name, brand, project and more. Tap again to hide the search box.'
                      : 'Find ${quickCategoryTab.toLowerCase()} entries by name. Tap again to hide the search box.',
                  _ToolChip(
                    icon: Icons.search_rounded,
                    semantic: searchVisible ? 'Hide search' : 'Search entries',
                    selected: _searchQuery.isNotEmpty,
                    onTap: () => setState(() {
                      if (_searchQuery.isNotEmpty) {
                        _searchOpen = true;
                      } else {
                        _searchOpen = !_searchOpen;
                      }
                    }),
                  ),
                  radius: Bt.rChip,
                ),
                if (quickCategoryTab != 'All') ...[
                  const SizedBox(width: 8),
                  ..._categoryToolbarChips(context, quickCategoryTab, allEntries),
                ],
                const SizedBox(width: 8),
                _tour(
                  _kEditColumns,
                  'Edit columns',
                  'Choose which columns the sheet shows and drag them into the order you like. Each tab remembers its own columns.',
                  _ToolChip(icon: Icons.view_column_outlined, label: 'Edit columns', onTap: openEditColumns),
                  radius: Bt.rChip,
                ),
                const SizedBox(width: 8),
                _tour(
                  _kSort,
                  'Sort',
                  'Order entries by purchase date, payment date, project or amount, newest/highest or oldest/lowest first. The label shows the current order.',
                  _ToolChip(
                    icon: _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    label: sortLabel,
                    semantic: 'Sort, columns, table and export',
                    onTap: openEntriesMenu,
                  ),
                  radius: Bt.rChip,
                ),
                const SizedBox(width: 8),
                _tour(
                  _kExport,
                  'Export',
                  'Save these entries as a CSV or PDF file to share or print.',
                  _ToolChip(icon: Icons.file_download_outlined, label: 'Export', onTap: openExport),
                  radius: Bt.rChip,
                ),
                const SizedBox(width: 8),
                _tour(
                  _kFullScreen,
                  'Full screen',
                  'Open the sheet on its own screen. Turn your phone sideways to see more columns at once.',
                  _ToolChip(icon: Icons.open_in_full_rounded, semantic: 'Full screen, can rotate', onTap: openFullScreen),
                  radius: Bt.rChip,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _tour(
          _kViewToggle,
          'Sheet or list',
          'Left: spreadsheet view, one row per entry in columns (default). Right: card list grouped by date. Your choice is remembered.',
          ReportViewToggle(
            table: _tableView,
            onChanged: (v) => setState(() {
              _tableView = v;
              ReportFilterState.tableView = v;
            }),
          ),
          radius: Bt.rChip,
        ),
      ],
    );

    // ── summary strip: Total billed · Paid · Remaining
    final summary = _tour(
      _chartsKey,
      'Totals',
      'Total billed, how much is paid and what is still to pay, for exactly the entries matching your project, period and filters.',
      _SummaryStrip(total: grandTotal, paid: grandPaid, remaining: grandRemaining),
    );

    return Scaffold(
      backgroundColor: Bt.ground,
      body: LayoutBuilder(
        builder: (context, viewport) {
          // The sheet takes whatever height is left under the header,
          // toolbar and summary so it is fully visible without scrolling.
          // 297 = header + tabs + toolbar + summary; +44 = the floor / phase /
          // activity chip row.
          final chromeAbove = topInset + 297 + (showWhere ? 44 : 0) + (searchVisible ? 54 : 0);
          const chromeBelow = ReportSheet.footerHeight + 60;
          final sheetMax = (viewport.maxHeight - chromeAbove - chromeBelow).clamp(260.0, 900.0);
          return RefreshIndicator(
            color: Bt.noir,
            backgroundColor: bt.accent,
            edgeOffset: topInset,
            onRefresh: () => ReportFilterState.reloadEntries(context),
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: EdgeInsets.zero,
              children: [
                header,
                BtSheet(
                  overlap: 22,
                  padding: const EdgeInsets.fromLTRB(Bt.gutter, 16, Bt.gutter, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _tour(
                        _kTabs,
                        'Entry types',
                        'Switch between All entries, Materials, Labour and Equipment. Each tab has its own columns and an item picker.',
                        _CategoryTabs(
                          activeTab: quickCategoryTab,
                          onTabChanged: _selectCategoryTab,
                        ),
                      ),
                      const SizedBox(height: 12),
                      toolbar,
                      AnimatedSize(
                        duration: Bt.fast,
                        curve: Bt.ease,
                        alignment: Alignment.topCenter,
                        child: searchVisible
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: quickCategoryTab != 'All'
                                    ? _buildCategorySubFilters(context, quickCategoryTab, allEntries)
                                    : _buildAllTabSearchBar(context),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: 12),
                      summary,
                      const SizedBox(height: 12),
                      if (paginatedEntries.isEmpty && projectProvider.entriesLoading)
                        const BtCard(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(child: BtBrickLoader(label: 'Loading entries…')),
                          ),
                        )
                      else if (paginatedEntries.isEmpty)
                        const BtCard(
                          child: BtEmpty(
                            icon: Icons.search_off_outlined,
                            title: 'No transaction logs match filters.',
                          ),
                        )
                      else if (showSheet)
                        _tour(
                          _kSheet,
                          'The sheet',
                          'One row per entry. Tap a row to see all its details and to add more, record a payment or edit it.',
                          ReportSheet(
                          tourWrap: (part, child) => part == 'header'
                              ? _tour(_kSheetHeader, 'Sort by a column', 'Tap the PURCHASE DATE, PAYMENT DATE, PROJECT or AMOUNT heading to sort by it; tap it again to flip the order. Long-press any heading to pin that column on the left.', child, radius: 0)
                              : _tour(_kSheetScroll, 'Scroll sideways', 'Swipe the sheet left and right to see every column — the pinned column stays put. This bar shows where you are.', child),
                          entries: paginatedEntries,
                          columns: activeCols,
                          pinnedColumn: pinnedCol,
                          onPinColumn: onPinColumn,
                          maxHeight: sheetMax,
                          firstRowNumber: startIndex + 1,
                          projectNameOf: (e) => getProjectName(e.projectId),
                          statusOf: statusOf,
                          sortColumn: _sortColumn,
                          sortAscending: _sortAscending,
                          onSort: onSheetSort,
                          onRowTap: (e) => _showEntryDetailsDialog(context, e, getProjectName(e.projectId), rowNumber: startIndex + paginatedEntries.indexOf(e) + 1),
                          onAddMore: (e) => _ReportActions.addMore(context, e),
                          onRecordPayment: (e) => _ReportActions.recordPayment(context, e, getProjectName(e.projectId)),
                          onEdit: (e) => _ReportActions.editEntry(context, e),
                          ),
                        )
                      else
                        _tour(
                          _kList,
                          'Entry list',
                          'Entries grouped by date. Tap one to see its details and to add more, record a payment or edit it.',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _buildEntryGroups(context, paginatedEntries, getProjectName),
                          ),
                        ),
                      if (paginatedEntries.isNotEmpty && (showSheet || totalCount > _rowsPerPage || _rowsPerPage != 10))
                        _tour(
                          _kPager,
                          'Pages',
                          'Choose how many rows to show per page (10, 20 or 50) and move between pages with the arrows.',
                          _buildPager(context, safeCurrentPage, totalPages),
                        ),
                      const SizedBox(height: 24),
                      _tour(
                        ShowcaseKeys.reportAskAI,
                        'Ask AI',
                        'Ask questions in plain words — costs, missing entries, stock — about this report and get an answer.',
                        _AskAiBanner(projectName: provider.selectedProjectName),
                        radius: Bt.rCard,
                      ),
                      const SizedBox(height: 10),
                      _tour(
                        _kQuickTiles,
                        'Shortcuts',
                        'Table view opens the sheet full screen (rotate for more columns). Export saves the report as CSV or PDF.',
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ReportQuickTile(
                                  icon: Icons.screen_rotation_rounded,
                                  title: 'Table view',
                                  subtitle: 'Full screen',
                                  onTap: openFullScreen,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ReportQuickTile(
                                  icon: Icons.ios_share_rounded,
                                  title: 'Export',
                                  subtitle: 'CSV or PDF',
                                  onTap: openExport,
                                ),
                              ),
                            ],
                          ),
                        ),
                        radius: 20,
                      ),
                      const SizedBox(height: 28),
                      _buildByType(
                        context,
                        total: grandTotal,
                        paid: grandPaid,
                        remaining: grandRemaining,
                        material: materialTotal,
                        labour: labourTotal,
                        equipment: equipmentTotal,
                        onType: (tab) {
                          _selectCategoryTab(tab);
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(0, duration: Bt.medium, curve: Bt.ease);
                          }
                        },
                      ),
                      const SizedBox(height: 28),
                      _buildCsvImportCard(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: AppBottomNav(),
    );
  }

  static String _sentence(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  void _selectCategoryTab(String newTab) {
    setState(() {
      _currentPage = 1;
      _selectedItemName = null;
      _showSuggestions = false;
      if (newTab == 'All') {
        _selectedTypes.addAll({
          EntryType.material,
          EntryType.labour,
          EntryType.equipment,
        });
      } else if (newTab == 'Materials') {
        _selectedTypes.clear();
        _selectedTypes.add(EntryType.material);
      } else if (newTab == 'Labour') {
        _selectedTypes.clear();
        _selectedTypes.add(EntryType.labour);
      } else if (newTab == 'Equipment') {
        _selectedTypes.clear();
        _selectedTypes.add(EntryType.equipment);
      }
    });
  }

  void _applyProject(String val) {
    setState(() {
      _selectedProjectId = val;
      _selectedFloor = null;
      _selectedPhaseId = null;
      _selectedActivityName = null;
      _currentPage = 1;
    });
    ReportFilterState.lastKnownProjectProviderId = val == 'all' ? null : val;
    final projectProvider = context.read<ProjectProvider>();
    final match = val == 'all'
        ? null
        : projectProvider.projects.where((p) => p.id == val).firstOrNull;
    if (match != null) {
      // Make it the app's selected project too (as on main): every later
      // ProjectProvider.load() then refetches this project's entries instead
      // of replacing them with another project's and zeroing the report.
      // selectProject() also loads this project's entries.
      projectProvider.selectProject(match);
    } else {
      projectProvider.loadEntriesForProject(val == 'all' ? null : val);
    }
    context.read<ReportProvider>().selectProject(val);
  }

  /// Single-choice list in a sheet. Returns the chosen value, or null if dismissed.
  Future<String?> _pickOption(BuildContext context, String title, List<MapEntry<String, String>> options, String? current) {
    return showBtSheet<String>(
      context,
      title: title,
      builder: (sheetCtx) => BtGroup(
        children: [
          for (final o in options)
            BtRow(
              title: o.value,
              minHeight: 48,
              trailing: o.key == current ? Icon(Icons.check_rounded, color: sheetCtx.bt.brand, size: 20) : null,
              onTap: () => Navigator.pop(sheetCtx, o.key),
            ),
        ],
      ),
    );
  }

  Future<void> _pickProject(BuildContext context, ProjectProvider projectProvider) async {
    final val = await _pickOption(
      context,
      'Project',
      [
        const MapEntry('all', 'All projects'),
        ...projectProvider.projects.map((p) => MapEntry(p.id, p.name)),
      ],
      _selectedProjectId,
    );
    if (val != null) _applyProject(val);
  }

  static const _periods = ['Today', 'This Week', 'This Month', 'Last 30 Days', 'This Year', 'All Time', 'Custom'];

  Widget _periodPicker(BuildContext context, VoidCallback refresh) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _periods)
              BtChip(
                label: p == 'Custom' ? 'Custom range' : _sentence(p),
                selected: _datePreset == p,
                onTap: () {
                  _setDatePreset(p);
                  refresh();
                },
              ),
          ],
        ),
        if (_datePreset == 'Custom') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BtField(
                  label: 'Start date',
                  child: BtPickerField(
                    text: _startDate == null ? 'Select date' : _formatDateShort(_startDate!),
                    placeholder: _startDate == null,
                    icon: Icons.calendar_today_outlined,
                    onTap: () async {
                      await _selectStartDate(context);
                      refresh();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BtField(
                  label: 'End date',
                  child: BtPickerField(
                    text: _endDate == null ? 'Select date' : _formatDateShort(_endDate!),
                    placeholder: _endDate == null,
                    icon: Icons.calendar_today_outlined,
                    onTap: () async {
                      await _selectEndDate(context);
                      refresh();
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _pickPeriod(BuildContext context) {
    showBtSheet(
      context,
      title: 'Period',
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _periodPicker(sheetCtx, () => setSheet(() {})),
            const SizedBox(height: 20),
            BtButton(label: 'Done', onPressed: () => Navigator.pop(sheetCtx)),
          ],
        ),
      ),
    );
  }

  /// What the Floor / Phase / Activity filters offer for the selected
  /// project (shared by the quick chips and the Filter sheet).
  _WhereOptions _whereOptions(ProjectProvider projectProvider) {
    final proj = _selectedProjectId == 'all'
        ? null
        : projectProvider.projects.where((p) => p.id == _selectedProjectId).firstOrNull;
    final floors = proj?.floors ?? const <String>[];
    final phases = proj?.selectedPhases ?? const <ProjectPhase>[];
    final phase = phases.where((p) => p.id == _selectedPhaseId).firstOrNull;
    final names = <String>{};
    if (phase != null) {
      names.addAll(phase.activities.map((a) => a.name));
    } else if (proj != null) {
      names.addAll(phases.expand((p) => p.activities).map((a) => a.name));
    }
    if (names.isEmpty && proj != null) {
      // Project without a phase plan: offer the activities its entries use.
      for (final e in projectProvider.entries) {
        if (e.projectId.trim() != proj.id.trim()) continue;
        if (phase != null && e.phaseId != phase.id && e.phase != phase.phaseName) continue;
        final a = e.activity?.trim();
        if (a != null && a.isNotEmpty) names.add(a);
      }
    }
    names.removeWhere((n) => n.trim().isEmpty);
    return _WhereOptions(project: proj, floors: floors, phases: phases, phase: phase, activities: names.toList());
  }

  Future<void> _pickFloor(BuildContext context, ProjectProvider projectProvider) async {
    final o = _whereOptions(projectProvider);
    final v = await _pickOption(context, 'Floor', [const MapEntry('Select Floor', 'All floors'), ...o.floors.map((f) => MapEntry(f, f))], _selectedFloor ?? 'Select Floor');
    if (v != null && mounted) setState(() { _selectedFloor = v == 'Select Floor' ? null : v; _currentPage = 1; });
  }

  Future<void> _pickPhase(BuildContext context, ProjectProvider projectProvider) async {
    final o = _whereOptions(projectProvider);
    final v = await _pickOption(context, 'Phase', [const MapEntry('Select Phase', 'All phases'), ...o.phases.map((ph) => MapEntry(ph.id, ph.phaseName))], _selectedPhaseId ?? 'Select Phase');
    if (v == null || !mounted) return;
    final next = v == 'Select Phase' ? null : v;
    if (next == _selectedPhaseId) return;
    // A new phase has its own activities, so the activity choice is cleared.
    setState(() { _selectedPhaseId = next; _selectedActivityName = null; _currentPage = 1; });
  }

  Future<void> _pickActivity(BuildContext context, ProjectProvider projectProvider) async {
    final o = _whereOptions(projectProvider);
    final v = await _pickOption(context, 'Activity', [const MapEntry('Select Activity', 'All activities'), ...o.activities.map((n) => MapEntry(n, n))], _selectedActivityName ?? 'Select Activity');
    if (v != null && mounted) setState(() { _selectedActivityName = v == 'Select Activity' ? null : v; _currentPage = 1; });
  }

  /// Quick chip tapped while "All projects" is selected: pick a project
  /// first, then go straight on to the picker that was tapped.
  Future<void> _whereChipTap(BuildContext context, ProjectProvider projectProvider, Future<void> Function(BuildContext, ProjectProvider) picker) async {
    if (_selectedProjectId == 'all') {
      btToast(context, 'Pick a project to filter by phase or activity.');
      await _pickProject(context, projectProvider);
      if (!mounted || _selectedProjectId == 'all') return;
    }
    if (!context.mounted) return;
    await picker(context, projectProvider);
  }

  /// Floor ▾ · Phase ▾ · Activity ▾ under the project / period chips: the
  /// same filters as the Filter sheet (same state), one tap away, each
  /// showing its value with an × to clear it.
  /// The chip row is left out for a project with no floors, phases or
  /// activities (and nothing picked) — it would only hold dead chips.
  bool _showWhereChips(ProjectProvider projectProvider) {
    final o = _whereOptions(projectProvider);
    return o.project == null ||
        o.floors.isNotEmpty ||
        o.phases.isNotEmpty ||
        o.activities.isNotEmpty ||
        _selectedFloor != null ||
        _selectedPhaseId != null ||
        _selectedActivityName != null;
  }

  Widget _buildWhereChips(BuildContext context, ProjectProvider projectProvider) {
    final o = _whereOptions(projectProvider);
    final hasProject = o.project != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          if (o.floors.isNotEmpty) ...[
            _WhereChip(
              label: 'Floor',
              value: _selectedFloor,
              onTap: () => _pickFloor(context, projectProvider),
              onClear: () => setState(() { _selectedFloor = null; _currentPage = 1; }),
            ),
            const SizedBox(width: 8),
          ],
          _WhereChip(
            label: 'Phase',
            value: o.phase?.phaseName ?? (_selectedPhaseId == null ? null : 'Phase'),
            enabled: !hasProject || o.phases.isNotEmpty,
            dim: !hasProject,
            onTap: () => _whereChipTap(context, projectProvider, _pickPhase),
            onClear: () => setState(() { _selectedPhaseId = null; _selectedActivityName = null; _currentPage = 1; }),
          ),
          const SizedBox(width: 8),
          _WhereChip(
            label: 'Activity',
            value: _selectedActivityName,
            enabled: !hasProject || o.activities.isNotEmpty || _selectedActivityName != null,
            dim: !hasProject,
            onTap: () => _whereChipTap(context, projectProvider, _pickActivity),
            onClear: () => setState(() { _selectedActivityName = null; _currentPage = 1; }),
          ),
        ],
      ),
    );
  }

  void _openFilterSheet(BuildContext context, ProjectProvider projectProvider) {
    showBtSheet(
      context,
      title: 'Filter',
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          void refresh() => setSheet(() {});
          final o = _whereOptions(projectProvider);
          final proj = o.project;
          final floors = o.floors;
          final phases = o.phases;
          final selectedPhase = o.phase;
          final activityNames = o.activities;
          final count = _filterEntries(projectProvider, _quickTab()).length;
          final hasProject = _selectedProjectId != 'all';

          Widget whereRow(String label, String value, bool enabled, Future<void> Function() onTap) => BtRow(
                title: label,
                minHeight: 52,
                titleColor: enabled ? Bt.ink2 : Bt.placeholder,
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right,
                      style: BtText.body(sheetCtx, color: enabled ? Bt.ink : Bt.placeholder)),
                ),
                showChevron: enabled,
                onTap: enabled ? () async {
                  await onTap();
                  refresh();
                } : null,
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Period', style: BtText.caption(sheetCtx))),
                  TextButton(
                    onPressed: () {
                      _applyProject('all');
                      _setDatePreset('All Time');
                      setState(() => _selectedStatus = 'All');
                      refresh();
                    },
                    style: TextButton.styleFrom(foregroundColor: sheetCtx.bt.brand, minimumSize: const Size(44, 36)),
                    child: const Text('Reset all'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _periodPicker(sheetCtx, refresh),
              const SizedBox(height: 20),
              const BtSectionHeader(title: 'Payment', caption: true),
              BtSegmented<String>(
                segments: const {'All': 'All', 'Fully Paid': 'Paid', 'Partial': 'Part paid', 'Not Paid': 'Not paid'},
                value: _selectedStatus,
                onChanged: (v) {
                  setState(() {
                    _selectedStatus = v;
                    _currentPage = 1;
                  });
                  refresh();
                },
              ),
              const SizedBox(height: 20),
              const BtSectionHeader(title: 'Where', caption: true),
              BtGroup(
                children: [
                  whereRow('Project', hasProject ? (proj?.name ?? 'Project') : 'All projects', true, () async {
                    await _pickProject(sheetCtx, projectProvider);
                  }),
                  whereRow('Floor', _selectedFloor ?? 'All', hasProject && floors.isNotEmpty, () => _pickFloor(sheetCtx, projectProvider)),
                  whereRow('Phase', selectedPhase?.phaseName ?? 'All', hasProject && phases.isNotEmpty, () => _pickPhase(sheetCtx, projectProvider)),
                  whereRow('Activity', _selectedActivityName ?? 'All', hasProject && (activityNames.isNotEmpty || _selectedActivityName != null), () => _pickActivity(sheetCtx, projectProvider)),
                ],
              ),
              if (!hasProject)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text('Pick a project to filter by floor, phase or activity.', style: BtText.caption(sheetCtx)),
                ),
              const SizedBox(height: 24),
              BtButton(
                label: 'Show $count ${count == 1 ? 'entry' : 'entries'}',
                onPressed: () => Navigator.pop(sheetCtx),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildEntryGroups(BuildContext context, List<EntryModel> entries, String Function(String) getProjectName) {
    final groups = <String, List<EntryModel>>{};
    for (final e in entries) {
      final String key;
      if (_sortColumn == 'date') {
        key = formatDayGroup(e.date);
      } else if (_sortColumn == 'paymentDate') {
        final paid = ReportSheet.paymentDateOf(e);
        key = paid == null ? 'Not paid yet' : 'Paid · ${formatDayGroup(paid)}';
      } else {
        key = '';
      }
      groups.putIfAbsent(key, () => []).add(e);
    }
    final out = <Widget>[];
    groups.forEach((label, items) {
      if (label.isNotEmpty) {
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
          child: Text(label, style: BtText.caption(context, weight: FontWeight.w500)),
        ));
      }
      out.add(BtGroup(
        children: [for (final e in items) _buildEntryRow(context, e, getProjectName(e.projectId))],
      ));
      out.add(const SizedBox(height: 16));
    });
    return out;
  }

  Widget _buildEntryRow(BuildContext context, EntryModel e, String projectName) {
    final status = _getPaymentStatusLabel(e.paymentStatus, amount: e.amount, paidAmount: e.paidAmount);
    final String statusText;
    final Color statusColor;
    if (status == 'Fully Paid') {
      statusText = 'Paid';
      statusColor = Bt.green;
    } else if (status == 'Partial') {
      statusText = '${formatInr(e.remainingAmount)} due';
      statusColor = Bt.amber;
    } else {
      statusText = 'Not paid';
      statusColor = Bt.red;
    }
    final where = [e.phase, e.activity, e.floor].where((v) => v != null && v.trim().isNotEmpty).take(1).join();
    // With one project selected the name is redundant, so show where the work happened instead.
    final sub = _selectedProjectId == 'all'
        ? [projectName, if (where.isNotEmpty) where].join(' · ')
        : (where.isNotEmpty ? where : projectName);
    return BtRow(
      leading: BtTypeTile(type: e.type.name),
      title: e.description.isEmpty ? _sentence(e.type.name) : e.description,
      subtitle: sub,
      minHeight: 64,
      onTap: () => _showEntryDetailsDialog(context, e, projectName),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatInr(e.amount), style: BtText.num(BtText.body(context, weight: FontWeight.w600))),
          const SizedBox(height: 2),
          Text(statusText, style: BtText.caption(context, color: statusColor, weight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPager(BuildContext context, int page, int totalPages) {
    Widget nav(IconData icon, String semantic, bool enabled, VoidCallback onTap) => Opacity(
          opacity: enabled ? 1 : .4,
          child: BtPressable(
            onTap: enabled ? onTap : () {},
            scale: .92,
            semanticLabel: semantic,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Bt.ink.withValues(alpha: .06), shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: Bt.ink),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          BtChip(
            label: 'Show $_rowsPerPage',
            trailingIcon: Icons.expand_more_rounded,
            onTap: () async {
              final v = await _pickOption(context, 'Rows per page', const [MapEntry('10', '10'), MapEntry('20', '20'), MapEntry('50', '50')], '$_rowsPerPage');
              if (v != null) setState(() { _rowsPerPage = int.parse(v); _currentPage = 1; });
            },
          ),
          const Spacer(),
          nav(Icons.chevron_left_rounded, 'Previous page', page > 1, () => setState(() => _currentPage = page - 1)),
          const SizedBox(width: 10),
          Text('Page $page of $totalPages', style: BtText.num(BtText.subhead(context, color: Bt.ink, weight: FontWeight.w500))),
          const SizedBox(width: 10),
          nav(Icons.chevron_right_rounded, 'Next page', page < totalPages, () => setState(() => _currentPage = page + 1)),
        ],
      ),
    );
  }

  /// "By type": 3-column cost-card grid (default, as in the original app) or
  /// the per-type list. Tap a type to open its tab.
  Widget _buildByType(
    BuildContext context, {
    required double total,
    required double paid,
    required double remaining,
    required double material,
    required double labour,
    required double equipment,
    required ValueChanged<String> onType,
  }) {
    final bt = context.bt;
    double share(double v) => total > 0 ? (v / total).clamp(0.0, 1.0) : 0.0;

    Widget listRow(String label, String tab, String typeName, double v, Color c) {
      return BtRow(
        leading: BtTypeTile(type: typeName),
        title: label,
        subtitle: '${(share(v) * 100).round()}% of billed',
        minHeight: 64,
        onTap: () => onType(tab),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatInr(v, compact: true), style: BtText.num(BtText.body(context, weight: FontWeight.w600))),
                const SizedBox(height: 6),
                BtProgress(value: share(v), color: c, thin: true),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Bt.placeholder, size: 22),
        ]),
      );
    }

    Widget gridRow(List<Widget> cards) => IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: cards[i]),
            ],
          ]),
        );

    final body = _byTypeGrid
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              gridRow([
                _CostCard(title: 'Total billed', value: total, icon: Icons.account_balance_wallet_outlined, featured: true),
                _CostCard(title: 'Paid', value: paid, icon: Icons.check_circle_outline_rounded, color: Bt.green),
                _CostCard(
                  title: 'Remaining',
                  value: remaining,
                  icon: Icons.pending_outlined,
                  color: remaining > 0 ? Bt.red : Bt.green,
                ),
              ]),
              const SizedBox(height: 8),
              gridRow([
                _CostCard(
                  title: 'Material',
                  value: material,
                  icon: BtTypeTile.iconFor('material'),
                  color: bt.series[0],
                  share: share(material),
                  onTap: () => onType('Materials'),
                ),
                _CostCard(
                  title: 'Labour',
                  value: labour,
                  icon: BtTypeTile.iconFor('labour'),
                  color: bt.series[1],
                  share: share(labour),
                  onTap: () => onType('Labour'),
                ),
                _CostCard(
                  title: 'Equipment',
                  value: equipment,
                  icon: BtTypeTile.iconFor('equipment'),
                  color: bt.series[2],
                  share: share(equipment),
                  onTap: () => onType('Equipment'),
                ),
              ]),
            ],
          )
        : BtGroup(children: [
            listRow('Material', 'Materials', 'material', material, bt.series[0]),
            listRow('Labour', 'Labour', 'labour', labour, bt.series[1]),
            listRow('Equipment', 'Equipment', 'equipment', equipment, bt.series[2]),
          ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(child: Text('BY TYPE', style: BtText.mono(context))),
            _tour(
              _kByTypeToggle,
              'Cards or list',
              'Left: cost cards in three columns (default). Right: one row per type with its share of the total. Your choice is remembered.',
              ReportViewToggle(
                table: _byTypeGrid,
                tableIcon: Icons.grid_view_rounded,
                tableLabel: 'Cards',
                listIcon: Icons.view_list_rounded,
                listLabel: 'List',
                onChanged: (v) => setState(() {
                  _byTypeGrid = v;
                  ReportFilterState.byTypeGrid = v;
                }),
              ),
              radius: Bt.rChip,
            ),
          ]),
        ),
        _tour(
          _kByType,
          'By type',
          'What you spent, paid and still owe, then the split between Material, Labour and Equipment. Tap a type to open its tab.',
          body,
          radius: 16,
        ),
      ],
    );
  }

  Widget _searchField(BuildContext context, String hint, ValueChanged<String> onChanged) {
    return TextField(
      controller: _searchController,
      onChanged: onChanged,
      autofocus: _searchOpen && _searchQuery.isEmpty,
      style: BtText.body(context),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: BtText.body(context, color: Bt.placeholder),
        prefixIcon: const Icon(Icons.search_rounded, color: Bt.ink3, size: 22),
        suffixIcon: IconButton(
          tooltip: _searchQuery.isNotEmpty ? 'Clear search' : 'Hide search',
          icon: Icon(_searchQuery.isNotEmpty ? Icons.cancel_rounded : Icons.close_rounded, color: Bt.placeholder, size: 20),
          onPressed: () {
            setState(() {
              if (_searchQuery.isEmpty) _searchOpen = false;
              _searchController.clear();
              _searchQuery = '';
              _selectedItemName = null;
              _showSuggestions = false;
            });
          },
        ),
        filled: true,
        fillColor: Bt.card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: const BorderSide(color: Bt.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: const BorderSide(color: Bt.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: BorderSide(color: context.bt.brand, width: 1.5)),
      ),
    );
  }

  Widget _buildAllTabSearchBar(BuildContext context) {
    return _searchField(
      context,
      'Search entries',
      (val) => setState(() {
        _searchQuery = val.trim();
        _currentPage = 1;
      }),
    );
  }

  ({String placeholder, String label, EntryType type}) _categoryMeta(String tabName) {
    if (tabName == 'Materials') {
      return (placeholder: 'Search materials', label: 'Material', type: EntryType.material);
    } else if (tabName == 'Labour') {
      return (placeholder: 'Search labour', label: 'Worker Type', type: EntryType.labour);
    }
    return (placeholder: 'Search equipment', label: 'Equipment', type: EntryType.equipment);
  }

  List<String> _uniqueItemNames(EntryType targetType, List<EntryModel> allEntries) {
    return allEntries
        .where(
          (e) =>
              e.type == targetType &&
              (_selectedProjectId == 'all' ||
                  e.projectId.trim() == _selectedProjectId.trim()),
        )
        .map((e) => e.description)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Item picker ("Material: All") and, when needed, "Generate report" — they
  /// live in the toolbar so they stay reachable with the search field closed.
  List<Widget> _categoryToolbarChips(
    BuildContext context,
    String tabName,
    List<EntryModel> allEntries,
  ) {
    final meta = _categoryMeta(tabName);
    final dropdownLabel = meta.label;
    final uniqueNames = _uniqueItemNames(meta.type, allEntries);
    final itemLabel = _selectedItemName ?? 'All';
    return [
      _tour(
        _kItem,
        '$dropdownLabel picker',
        'Show only one ${dropdownLabel.toLowerCase()} — the totals and the sheet follow it. Pick "All" to see every one again.',
        radius: Bt.rChip,
        BtChip(
        label: '$dropdownLabel: ${itemLabel.length > 16 ? '${itemLabel.substring(0, 15).trimRight()}…' : itemLabel}',
        trailingIcon: Icons.expand_more_rounded,
        selected: _selectedItemName != null,
        onTap: () async {
          final val = await _pickOption(
            context,
            dropdownLabel,
            [const MapEntry('All', 'All'), ...uniqueNames.map((n) => MapEntry(n, n))],
            _selectedItemName ?? 'All',
          );
          if (val == null) return;
          setState(() {
            _selectedItemName = val == 'All' ? null : val;
            final selectedVal = val == 'All' ? '' : val;
            _searchController.text = selectedVal;
            _searchQuery = selectedVal;
            _showSuggestions = false;
            _currentPage = 1;
          });
        },
      ),
      ),
    ];
  }

  Widget _buildCategorySubFilters(
    BuildContext context,
    String tabName,
    List<EntryModel> allEntries,
  ) {
    final meta = _categoryMeta(tabName);
    final searchPlaceholder = meta.placeholder;
    final uniqueNames = _uniqueItemNames(meta.type, allEntries);
    final suggestions = uniqueNames
        .where(
          (name) => name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
    final showSuggestionsList =
        _showSuggestions &&
        _searchQuery.isNotEmpty &&
        suggestions.isNotEmpty &&
        !(suggestions.length == 1 &&
            suggestions.first.toLowerCase() == _searchQuery.toLowerCase());
    return TapRegion(
      onTapOutside: (event) {
        if (_showSuggestions) setState(() => _showSuggestions = false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _searchField(context, searchPlaceholder, (val) {
            setState(() {
              _searchQuery = val.trim();
              _showSuggestions = true;
              _currentPage = 1;
              if (_selectedItemName != null && _selectedItemName != _searchQuery) {
                _selectedItemName = null;
              }
            });
          }),
          if (showSuggestionsList) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Bt.card,
                borderRadius: BorderRadius.circular(Bt.rInput),
                boxShadow: Bt.shadowLg,
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: suggestions.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 44, color: Bt.line),
                itemBuilder: (context, index) {
                  final name = suggestions[index];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _searchController.text = name;
                        _searchQuery = name;
                        _selectedItemName = name;
                        _showSuggestions = false;
                      });
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          const Icon(Icons.search_rounded, size: 18, color: Bt.ink3),
                          const SizedBox(width: 12),
                          Expanded(child: Text(name, style: BtText.body(context))),
                          const Icon(Icons.north_west_rounded, size: 16, color: Bt.placeholder),
                          const SizedBox(width: 14),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEntryDetailsDialog(
    BuildContext context,
    EntryModel entry,
    String projectName, {
    int? rowNumber,
  }) {
    final status = _getPaymentStatusLabel(
      entry.paymentStatus,
      amount: entry.amount,
      paidAmount: entry.paidAmount,
    );
    final canDelete = EntryPermissions.canDelete(status: entry.approvalStatus.toLowerCase(), createdBy: entry.createdBy ?? '', projectId: entry.projectId);
    final typeLabel = _sentence(entry.type.name);
    final paidShare = entry.amount > 0
        ? (entry.paidAmount / entry.amount).clamp(0.0, 1.0).toDouble()
        : (status == 'Fully Paid' ? 1.0 : 0.0);
    showBtSheet(
      context,
      title: 'Entry details',
      subtitle: rowNumber == null ? '$typeLabel · $projectName' : 'Row $rowNumber · $typeLabel · $projectName',
      builder: (sheetCtx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BtReveal(
            child: BtCard(
              variant: BtCardVariant.ink,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.description.isEmpty ? typeLabel : entry.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: BtText.headline(sheetCtx).copyWith(color: Bt.bone),
                        ),
                      ),
                      const SizedBox(width: 10),
                      BtBadge(label: status, tone: status == 'Fully Paid' ? BtTone.green : (status == 'Partial' ? BtTone.amber : BtTone.red)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _miniStat(sheetCtx, 'Amount', _formatIndianCurrency(entry.amount), Bt.bone)),
                      const SizedBox(width: 8),
                      Expanded(child: _miniStat(sheetCtx, 'Paid', _formatIndianCurrency(entry.paidAmount), const Color(0xFF4ADBA4))),
                      const SizedBox(width: 8),
                      Expanded(child: _miniStat(sheetCtx, 'Remaining', _formatIndianCurrency(entry.remainingAmount), entry.remainingAmount > 0 ? const Color(0xFFFF8A8E) : const Color(0xFF4ADBA4))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  BtProgress(value: paidShare, onDark: true, color: Bt.greenBright),
                ],
              ),
            ),
          ),
          if (entry.rejectionReason != null && entry.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            BtCard(
              variant: BtCardVariant.danger,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REJECTION REASON', style: BtText.mono(sheetCtx, color: Bt.red)),
                  const SizedBox(height: 4),
                  Text(entry.rejectionReason!, style: BtText.body(sheetCtx)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          BtReveal(
            index: 1,
            child: _DetailGrid(items: [
              ('Project', projectName),
              ('Type', typeLabel),
              ('Date', _formatDateLong(entry.date)),
              if (entry.description.isNotEmpty) ('Description', entry.description),
              if (entry.brand != null && entry.brand!.isNotEmpty) ('Brand', entry.brand!),
              if (entry.floor != null && entry.floor!.isNotEmpty) ('Floor', entry.floor!),
              if (entry.phase != null && entry.phase!.isNotEmpty) ('Phase', entry.phase!),
              if (entry.unit != null && entry.unit!.isNotEmpty) ('Unit', entry.unit!),
            ]),
          ),
          BtReveal(
            index: 2,
            child: _PaymentHistorySection(
              entry: entry,
              formatCurrency: _formatIndianCurrency,
              formatDate: _formatDateLong,
            ),
          ),
          const SizedBox(height: 16),
          BtReveal(
            index: 3,
            child: Row(
              children: [
                Expanded(
                  child: _DetailAction(
                    label: 'Add More',
                    semantic: 'Add more of this entry',
                    icon: Icons.add_circle_outline_rounded,
                    variant: BtButtonVariant.primary,
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _ReportActions.addMore(context, entry);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DetailAction(
                    label: 'Payment',
                    semantic: 'Record Payment',
                    icon: Icons.credit_card_outlined,
                    variant: BtButtonVariant.accent,
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _ReportActions.recordPayment(context, entry, projectName);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DetailAction(
                    label: 'Edit',
                    semantic: 'Edit Entry',
                    icon: Icons.edit_outlined,
                    variant: BtButtonVariant.secondary,
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _ReportActions.editEntry(context, entry);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (canDelete) ...[
            const SizedBox(height: 8),
            BtButton(
              label: 'Delete entry…',
              variant: BtButtonVariant.quiet,
              icon: Icons.delete_outline,
              small: true,
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                _ReportActions.deleteEntry(context, entry);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: BtText.caption(context, color: Bt.onNoir2).copyWith(fontSize: 12)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: BtText.num(BtText.body(context, weight: FontWeight.w700, color: color))),
          ),
        ],
      );
}

/// Noir "Ask AI about your costs" card (Reports board).
/// Cost card in the "By type" grid (V2 version of the original app's cards).
class _WhereOptions {
  const _WhereOptions({required this.project, required this.floors, required this.phases, required this.phase, required this.activities});
  final ProjectModel? project;
  final List<String> floors;
  final List<ProjectPhase> phases;
  final ProjectPhase? phase;
  final List<String> activities;
}

/// Quick filter chip on the noir header: "Phase ▾" when off; the chosen value
/// with an × (clears it) when on. [dim] = needs a project first.
class _WhereChip extends StatelessWidget {
  const _WhereChip({required this.label, required this.value, required this.onTap, required this.onClear, this.enabled = true, this.dim = false});
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool enabled;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final on = value != null;
    final fg = on ? Bt.noir : Bt.bone.withValues(alpha: (dim || !enabled) ? .5 : 1);
    final text = on && value!.length > 20 ? '${value!.substring(0, 19).trimRight()}…' : (value ?? label);
    return Semantics(
      button: true,
      label: on ? '$label: $value' : '$label filter',
      child: BtPressable(
        onTap: enabled ? onTap : null,
        scale: .95,
        child: AnimatedContainer(
          duration: Bt.fast,
          curve: Bt.ease,
          constraints: const BoxConstraints(minHeight: 36),
          padding: EdgeInsets.only(left: 13, right: on ? 4 : 9),
          decoration: BoxDecoration(
            color: on ? Bt.bone : Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(Bt.rChip),
            border: on ? null : Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ExcludeSemantics(child: Text(text, style: BtText.subhead(context, weight: FontWeight.w500, color: fg))),
            if (on)
              Semantics(
                button: true,
                label: 'Clear $label',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: SizedBox(width: 30, height: 36, child: Icon(Icons.close_rounded, size: 16, color: fg)),
                ),
              )
            else ...[
              const SizedBox(width: 2),
              Icon(Icons.expand_more_rounded, size: 18, color: fg),
            ],
          ]),
        ),
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  const _CostCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.featured = false,
    this.share,
    this.onTap,
  });
  final String title;
  final double value;
  final IconData icon;
  final Color? color;
  final bool featured;
  /// Share of the total billed (type cards only).
  final double? share;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = featured ? Bt.bone : (color ?? Bt.ink);
    final label = featured ? Bt.onNoir2 : Bt.ink2;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      decoration: BoxDecoration(
        color: featured ? Bt.ink : Bt.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: featured ? null : Bt.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: featured ? Colors.white.withValues(alpha: .1) : (color ?? Bt.ink).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: featured ? Bt.bone : (color ?? Bt.ink)),
          ),
          const SizedBox(height: 10),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: label).copyWith(fontSize: 12)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatInr(value, compact: true),
              maxLines: 1,
              style: BtText.num(BtText.body(context, weight: FontWeight.w700, color: featured ? Bt.bone : Bt.ink)).copyWith(fontSize: 15),
            ),
          ),
          if (share != null) ...[
            const SizedBox(height: 8),
            BtProgress(value: share!, color: fg, thin: true),
          ],
        ],
      ),
    );
    if (onTap == null) return Semantics(label: '$title ${formatInr(value)}', excludeSemantics: true, child: card);
    return BtPressable(
      onTap: onTap!,
      scale: .96,
      semanticLabel: '$title ${formatInr(value)}. Open $title tab',
      child: card,
    );
  }
}

class _AskAiBanner extends StatelessWidget {
  const _AskAiBanner({required this.projectName});
  final String projectName;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      button: true,
      label: 'Ask AI about costs, entries and inventory',
      excludeSemantics: true,
      child: BtCard(
        variant: BtCardVariant.ink,
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        onTap: () => Navigator.pushNamed(
          context,
          '/ai-chat',
          arguments: {'projectName': projectName, 'projectId': ReportFilterState.selectedProjectId},
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bt.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: bt.accent.withValues(alpha: .35), blurRadius: 18)],
              ),
              child: Icon(Icons.auto_awesome, color: bt.onAccent, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ask AI about your costs', maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.headline(context).copyWith(color: Bt.bone)),
                  const SizedBox(height: 2),
                  Text('Costs, entries and inventory', maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, color: Bt.onNoir2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: Bt.onNoir2, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.activeTab, required this.onTabChanged});
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  static const _tabs = ['All', 'Materials', 'Labour', 'Equipment'];
  @override
  Widget build(BuildContext context) {
    return BtSegmented<String>(
      segments: {for (final t in _tabs) t: t},
      value: activeTab,
      onChanged: onTabChanged,
    );
  }
}

/// Toolbar chip (icon only, or icon + label) — Report-Table board.
class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.icon, required this.onTap, this.label, this.semantic, this.selected = false});
  final IconData icon;
  final String? label;
  final String? semantic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Bt.bone : Bt.ink;
    return BtPressable(
      onTap: onTap,
      scale: .95,
      semanticLabel: semantic ?? label,
      child: AnimatedContainer(
        duration: Bt.fast,
        curve: Bt.ease,
        height: 36,
        constraints: const BoxConstraints(minWidth: 36),
        padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 12),
        decoration: BoxDecoration(
          color: selected ? Bt.ink : Bt.card,
          borderRadius: BorderRadius.circular(Bt.rChip),
          border: selected ? null : Border.all(color: Bt.inputBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label!, maxLines: 1, style: BtText.subhead(context, weight: FontWeight.w500, color: fg).copyWith(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Slim 3-cell strip: Total billed · Paid · Remaining.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.total, required this.paid, required this.remaining});
  final double total;
  final double paid;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, double v, Color color) => Expanded(
          child: Container(
            color: Bt.card,
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: Bt.ink2).copyWith(fontSize: 12)),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: BtCountUp(
                    value: v,
                    format: (x) => formatInr(x),
                    style: BtText.body(context, weight: FontWeight.w700, color: color).copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: Bt.shadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: Bt.line,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cell('Total billed', total, Bt.ink),
                const SizedBox(width: 1),
                cell('Paid', paid, Bt.green),
                const SizedBox(width: 1),
                cell('Remaining', remaining, remaining > 0 ? Bt.red : Bt.green),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PDF / CSV format card in the Export sheet (Export-Sheet board).
class _ExportFormatCard extends StatelessWidget {
  const _ExportFormatCard({required this.format, required this.title, required this.subtitle, required this.onTap, this.dark = false});
  final String format;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final docBg = format == 'PDF' ? bt.accent : const Color(0xFF16B981);
    final docFg = format == 'PDF' ? bt.onAccent : Colors.white;
    return BtPressable(
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? Bt.ink : Bt.ground,
          borderRadius: BorderRadius.circular(Bt.rCard),
          border: dark ? null : Border.all(color: Bt.inputBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 54,
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 7),
              decoration: BoxDecoration(
                color: docBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(format, style: BtText.mono(context, color: docFg, size: 10)),
            ),
            const SizedBox(height: 14),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w600, color: dark ? Bt.bone : Bt.ink)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: dark ? Bt.onNoir2 : Bt.ink3).copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Two-column label/value grid with hairline gaps (Report-Row-Detail board).
class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      if (i > 0) rows.add(const SizedBox(height: 1));
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _cell(context, left)),
          const SizedBox(width: 1),
          Expanded(child: right == null ? const ColoredBox(color: Bt.card) : _cell(context, right)),
        ]),
      ));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Bt.line,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      ),
    );
  }

  Widget _cell(BuildContext context, (String, String) item) => Container(
        color: Bt.card,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.$1, style: BtText.caption(context, color: Bt.ink2).copyWith(fontSize: 12)),
            const SizedBox(height: 2),
            Text(item.$2, maxLines: 3, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, color: Bt.ink, weight: FontWeight.w600)),
          ],
        ),
      );
}

/// Compact 3-up action button in the entry details sheet.
class _DetailAction extends StatelessWidget {
  const _DetailAction({required this.label, required this.semantic, required this.icon, required this.variant, required this.onTap});
  final String label;
  final String semantic;
  final IconData icon;
  final BtButtonVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    late Color bg, fg;
    Border? border;
    switch (variant) {
      case BtButtonVariant.primary:
        bg = Bt.ink;
        fg = Bt.bone;
        break;
      case BtButtonVariant.accent:
        bg = bt.accent;
        fg = bt.onAccent;
        break;
      default:
        bg = Bt.card;
        fg = Bt.ink;
        border = Border.all(color: Bt.inputBorder);
    }
    return BtPressable(
      onTap: onTap,
      semanticLabel: semantic,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: border),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.button(context, size: 14, color: fg))),
          ],
        ),
      ),
    );
  }
}

/// Full-screen sheet with a rotate (landscape) / straight view switch.
class _FullScreenLogsViewer extends StatefulWidget {
  const _FullScreenLogsViewer({
    required this.entriesOf,
    required this.getProjectName,
    required this.statusOf,
    required this.quickCategoryTab,
    required this.title,
    required this.onExportCsv,
    required this.onExportPdf,
    required this.columnsOf,
    required this.onPinColumn,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.onRowTap,
    required this.onAddMore,
    required this.onRecordPayment,
    required this.onEdit,
  });
  final List<EntryModel> Function(ProjectProvider) entriesOf;
  final String Function(String) getProjectName;
  final String Function(EntryModel) statusOf;
  final String quickCategoryTab;
  final String title;
  final void Function(List<EntryModel> rows) onExportCsv;
  final void Function(List<EntryModel> rows) onExportPdf;
  /// The tab's columns in on-screen order (pinned first), read on each build.
  final List<String> Function() columnsOf;
  final void Function(String column) onPinColumn;
  final String sortColumn;
  final bool sortAscending;
  final void Function(String column, bool ascending) onSort;
  final void Function(EntryModel) onRowTap;
  final void Function(EntryModel) onAddMore;
  final void Function(EntryModel) onRecordPayment;
  final void Function(EntryModel) onEdit;
  @override
  State<_FullScreenLogsViewer> createState() => _FullScreenLogsViewerState();
}

class _FullScreenLogsViewerState extends State<_FullScreenLogsViewer> {
  int _quarterTurns = 0;
  late String _sortColumn = widget.sortColumn;
  late bool _sortAscending = widget.sortAscending;
  /// Rows as last built (refiltered + sorted in build from the live entries).
  List<EntryModel> _rows = const [];

  void _toggleRotation() {
    setState(() {
      _quarterTurns = (_quarterTurns == 0) ? 1 : 0;
    });
  }

  List<EntryModel> _sorted(List<EntryModel> source) {
    final list = List<EntryModel>.from(source);
    list.sort((a, b) => compareReportEntries(a, b, _sortColumn, _sortAscending, widget.getProjectName));
    return list;
  }

  void _openExport() {
    showBtSheet(
      context,
      title: 'Export',
      subtitle: '${_rows.length} entries',
      builder: (sheetCtx) => BtGroup(
        children: [
          BtRow(
            leading: const BtTile(icon: Icons.description_outlined),
            title: 'Download CSV',
            subtitle: 'Opens in Excel or Google Sheets',
            showChevron: true,
            onTap: () {
              Navigator.pop(sheetCtx);
              widget.onExportCsv(_rows);
            },
          ),
          BtRow(
            leading: const BtTile(icon: Icons.picture_as_pdf_outlined),
            title: 'Download PDF',
            subtitle: 'Ready to print or share',
            showChevron: true,
            onTap: () {
              Navigator.pop(sheetCtx);
              widget.onExportPdf(_rows);
            },
          ),
        ],
      ),
    );
  }

  Widget _content(double width) {
    final rotated = _quarterTurns != 0;
    final columns = widget.columnsOf();
    final wide = width > 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                BtIconButton(
                  icon: Icons.close_rounded,
                  semantic: 'Close',
                  background: Bt.ink.withValues(alpha: .06),
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: widget.title),
                          TextSpan(text: '  (${_rows.length} entries)', style: BtText.caption(context, color: Bt.ink2, weight: FontWeight.w500)),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BtText.navTitle(context).copyWith(fontSize: 16),
                      ),
                      Text('Tap a row for details', maxLines: 1, style: BtText.caption(context).copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: rotated ? 'Straight View' : 'Rotate View (Landscape)',
                  child: _ToolChip(
                    icon: rotated ? Icons.screen_lock_portrait : Icons.screen_rotation,
                    label: wide ? (rotated ? 'Straight view' : 'Rotate view') : null,
                    semantic: rotated ? 'Straight View' : 'Rotate View (Landscape)',
                    onTap: _toggleRotation,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Export Options',
                  child: _ToolChip(
                    icon: Icons.ios_share_rounded,
                    label: wide ? 'CSV · PDF' : null,
                    semantic: 'Export Options',
                    onTap: _openExport,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Bt.gutter, 4, Bt.gutter, 8),
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.topCenter,
                child: _rows.isEmpty
                    ? const BtCard(child: BtEmpty(icon: Icons.search_off_outlined, title: 'No transaction logs match filters.'))
                    : ReportSheet(
                        entries: _rows,
                        columns: columns,
                        pinnedColumn: columns.isEmpty ? null : columns.first,
                        onPinColumn: (column) {
                          widget.onPinColumn(column);
                          setState(() {});
                        },
                        maxHeight: c.maxHeight - ReportSheet.footerHeight,
                        pinnedWidth: wide ? 158 : 132,
                        projectNameOf: (e) => widget.getProjectName(e.projectId),
                        statusOf: widget.statusOf,
                        sortColumn: _sortColumn,
                        sortAscending: _sortAscending,
                        onSort: (column, ascending) {
                          setState(() {
                            _sortColumn = column;
                            _sortAscending = ascending;
                          });
                          widget.onSort(column, ascending);
                        },
                        onRowTap: widget.onRowTap,
                        onAddMore: widget.onAddMore,
                        onRecordPayment: widget.onRecordPayment,
                        onEdit: widget.onEdit,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _rows = _sorted(widget.entriesOf(context.watch<ProjectProvider>()));
    final rotated = _quarterTurns != 0;
    return Scaffold(
      backgroundColor: Bt.ground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!rotated) return _content(constraints.maxWidth);
            return RotatedBox(
              quarterTurns: _quarterTurns,
              child: SizedBox(
                width: constraints.maxHeight,
                height: constraints.maxWidth,
                child: _content(constraints.maxHeight),
              ),
            );
          },
        ),
      ),
    );
  }
}

final _objectIdPattern = RegExp(r'^[0-9a-fA-F]{24}$');
final _isoTimestampPattern = RegExp(r'^\d{4}-\d{2}-\d{2}([T ]|$)');
final _skipSearchKeyPattern = RegExp(
  r'(^_?id$|^__v$|Id$|_id$|url|image|photo|receipt|signature|screenshot|attachment|token|password|^project$|^progress$)',
  caseSensitive: false,
);

/// Feeds every text value of a raw transaction to [add] — nested ones too
/// (worker name and trade, payment notes) — but not ids, links or raw
/// timestamps, which would make short searches like "65" match everything.
void _collectSearchText(dynamic value, void Function(String?) add) {
  if (value is Map) {
    value.forEach((k, v) {
      if (!_skipSearchKeyPattern.hasMatch(k.toString())) _collectSearchText(v, add);
    });
  } else if (value is List) {
    for (final v in value) {
      _collectSearchText(v, add);
    }
  } else if (value is String) {
    final s = value.trim();
    if (_objectIdPattern.hasMatch(s) || _isoTimestampPattern.hasMatch(s)) return;
    add(s);
  }
}

String _getPaymentStatusLabel(
  String status, {
  double? amount,
  double? paidAmount,
}) {
  if (amount != null && paidAmount != null && amount > 0) {
    if (paidAmount >= amount) return 'Fully Paid';
    if (paidAmount > 0) return 'Partial';
  }
  switch (status.toLowerCase().trim()) {
    case 'paid':
    case 'fully paid':
    case 'fullypaid':
      return 'Fully Paid';
    case 'partial':
    case 'partially paid':
    case 'partiallypaid':
    case 'partially':
    case 'partpaid':
      return 'Partial';
    case 'pending':
    case 'not paid':
    case 'notpaid':
    case 'unpaid':
    default:
      return 'Not Paid';
  }
}

class _ReportActions {
  static void addMore(BuildContext context, EntryModel entry) {
    final dupArgs = entry.toJson();
    dupArgs['isDuplicate'] = true;
    dupArgs['fromReport'] = true;
    dupArgs['sourceTransactionId'] = entry.id;
    dupArgs['projectId'] = entry.projectId;
    String route;
    switch (entry.type) {
      case EntryType.labour:
        route = '/add-labour';
        break;
      case EntryType.equipment:
        route = '/add-equipment';
        break;
      case EntryType.material:
        route = '/add-material';
        break;
    }
    Navigator.pushNamed(context, route, arguments: dupArgs).then((saved) {
      // Forms pop with true (saved) or 'deleted'; plain back needs no reload.
      if (context.mounted && saved != null) ReportFilterState.reloadEntries(context);
    });
  }

  static void editEntry(BuildContext context, EntryModel entry) {
    final editArgs = entry.toJson();
    editArgs['isEditing'] = true;
    editArgs['id'] = entry.id;
    editArgs['projectId'] = entry.projectId;
    editArgs['fromReport'] = true;
    String route;
    switch (entry.type) {
      case EntryType.labour:
        route = '/add-labour';
        break;
      case EntryType.equipment:
        route = '/add-equipment';
        break;
      case EntryType.material:
        route = '/add-material';
        break;
    }
    Navigator.pushNamed(context, route, arguments: editArgs).then((saved) {
      // Forms pop with true (saved) or 'deleted'; plain back needs no reload.
      if (context.mounted && saved != null) ReportFilterState.reloadEntries(context);
    });
  }

  static Future<void> deleteEntry(BuildContext context, EntryModel entry) async {
    final confirm = await btConfirm(
      context,
      title: 'Delete Entry?',
      message: 'Are you sure you want to permanently delete this entry?',
      confirmLabel: 'Delete',
    );

    if (confirm == true) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Bt.scrim,
        builder: (ctx) => const Center(child: BtBrickLoader(onDark: true)),
      );
      
      final success = await ApiService.deleteTransaction(entry.id);
      
      if (context.mounted) {
        Navigator.of(context).pop(); // pop progress
        if (success) {
          btToast(context, 'Entry deleted successfully');
          ReportFilterState.reloadEntries(context);
        } else {
          btToast(context, 'Failed to delete entry', error: true);
        }
      }
    }
  }

  static Future<void> recordPayment(
    BuildContext context,
    EntryModel entry,
    String projectName,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Bt.scrim,
      builder: (context) => const Center(child: BtBrickLoader(onDark: true)),
    );
    final tx = await ApiService.fetchTransactionById(entry.id);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
    if (tx == null) {
      if (context.mounted) {
        btToast(context, 'Failed to load transaction details.', error: true);
      }
      return;
    }
    final pId = entry.projectId;
    final pName = projectName;
    final rawItemName =
        tx['materialName'] ??
        tx['itemName'] ??
        tx['title'] ??
        tx['name'] ??
        entry.description;
    final itemType = tx['type'] ?? entry.type.name;
    final qty =
        (tx['quantity'] as num?)?.toDouble() ??
        ((entry.ratePerUnit ?? 0) == 0
            ? 0.0
            : entry.amount / entry.ratePerUnit!);
    final rate = (tx['rate'] as num?)?.toDouble() ?? entry.ratePerUnit ?? 0.0;
    final totalAmount = (tx['amount'] as num?)?.toDouble() ?? entry.amount;
    final paidAmount = (tx['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final outstandingAmount = (totalAmount - paidAmount).clamp(
      0.0,
      double.infinity,
    );
    final payStatus = EntryModel.fromJson(tx).paymentStatus;
    final payArgs = {
      'id': entry.id,
      'projectId': pId,
      'projectName': pName,
      'itemId': tx['materialId'] ?? tx['itemId'] ?? '',
      'itemName': rawItemName,
      'itemType': itemType,
      'quantity': qty,
      'rate': rate,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'outstandingAmount': outstandingAmount,
      'paymentStatus': payStatus,
      'receipt': (tx['attachments'] is List && tx['attachments'].isNotEmpty)
          ? tx['attachments'].first?.toString()
          : null,
      'transactionDetails': tx,
    };
    if (context.mounted) {
      Navigator.pushNamed(
        context,
        '/fulfillment-payment',
        arguments: payArgs,
      ).then((updated) {
        if (updated == true && context.mounted) {
          ReportFilterState.reloadEntries(context);
        }
      });
    }
  }
}

class _PaymentHistorySection extends StatefulWidget {
  final EntryModel entry;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;
  _PaymentHistorySection({
    required this.entry,
    required this.formatCurrency,
    required this.formatDate,
  });
  @override
  State<_PaymentHistorySection> createState() => _PaymentHistorySectionState();
}

class _PaymentHistorySectionState extends State<_PaymentHistorySection> {
  bool _viewAll = false;
  List<Map<String, dynamic>>? _fetchedHistory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry.paymentHistory.isEmpty && widget.entry.paidAmount > 0) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final tx = await ApiService.fetchTransactionById(widget.entry.id);
      if (tx != null && tx['paymentHistory'] != null) {
        final historyList = tx['paymentHistory'];
        if (historyList is List) {
          if (mounted) {
            setState(() {
              _fetchedHistory = List<Map<String, dynamic>>.from(
                historyList.map((e) => Map<String, dynamic>.from(e as Map)),
              );
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading payment history in report dialog: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = _fetchedHistory ?? widget.entry.paymentHistory;
    final bt = context.bt;
    Widget header = BtSectionHeader(
      title: 'Payment history',
      caption: true,
      action: history.length > 1 ? (_viewAll ? 'View less' : 'View all (${history.length})') : null,
      onAction: () => setState(() => _viewAll = !_viewAll),
    );
    Widget note(String text) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(text, style: BtText.caption(context, color: Bt.ink3)),
        );
    Widget content;
    if (_isLoading) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              height: 12,
              width: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation<Color>(bt.accentInk)),
            ),
            const SizedBox(width: 8),
            Text('Loading payment history...', style: BtText.caption(context, color: Bt.ink3)),
          ],
        ),
      );
    } else if (history.isEmpty) {
      if (widget.entry.paidAmount > 0) {
        content = note('Detailed payment history is unavailable for payments recorded before transaction tracking was introduced.');
      } else {
        content = note('No payments recorded yet.');
      }
    } else {
      final displayedList = List.from(history.reversed);
      final itemsToShow = _viewAll ? displayedList : [displayedList.first];
      Widget list = ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: itemsToShow.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 58, color: Bt.line),
        itemBuilder: (context, idx) {
          final item = itemsToShow[idx];
          final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
          final rawDate = item['date'] ?? item['paymentDate'];
          DateTime? dt;
          if (rawDate is String) {
            dt = DateTime.tryParse(rawDate)?.toLocal();
          } else if (rawDate is DateTime) {
            dt = rawDate;
          }
          final dateStr = dt != null ? widget.formatDate(dt) : '—';
          final method = item['method'] as String? ?? 'Cash';
          final note = item['note'] as String? ?? '';
          final receipt = item['receipt'] as String?;
          final methodLabel = method.isEmpty ? method : method[0].toUpperCase() + method.substring(1);
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BtTile(icon: Icons.payments_outlined, bg: Bt.greenSoft, fg: Bt.green, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.formatCurrency(amt)} · $methodLabel',
                          style: BtText.num(BtText.subhead(context, color: Bt.ink, weight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 1),
                        Text(dateStr, style: BtText.caption(context).copyWith(fontSize: 12)),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Note: $note', style: BtText.caption(context, color: Bt.ink2)),
                        ],
                      ],
                    ),
                  ),
                  if (receipt != null && receipt.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Open receipt',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final uri = Uri.parse(receipt);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('Receipt ↗', style: BtText.subhead(context, color: bt.accentInk, weight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
      if (_viewAll && displayedList.length > 3) {
        content = Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(child: list),
          ),
        );
      } else {
        content = list;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Container(
            decoration: BoxDecoration(
              color: Bt.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Bt.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        ],
      ),
    );
  }
}
