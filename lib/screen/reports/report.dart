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
import 'package:buildtrack_mobile/screen/reports/report_widgets.dart' show EfficiencyBanner;
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
            UserSession.markModuleVisited('ReportScreen');
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

class ReportFilterState {
  static String selectedProjectId = 'all';
  static String? selectedFloor;
  static String? selectedPhaseId;
  static String? selectedActivityName;
  static String searchQuery = '';
  static String? selectedItemName;
  static bool reportGenerated = true;
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
  /// Entries show as a spreadsheet (true) or as the card list (false).
  static bool tableView = true;

  static void reset() {
    selectedProjectId = 'all';
    selectedFloor = null;
    selectedPhaseId = null;
    selectedActivityName = null;
    searchQuery = '';
    selectedItemName = null;
    reportGenerated = true;
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
  }
}

class _ReportsView extends StatefulWidget {
  _ReportsView();
  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView> {
  final GlobalKey _chartsKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  bool _linked = false;
  String _selectedProjectId = ReportFilterState.selectedProjectId;
  String? _selectedFloor = ReportFilterState.selectedFloor;
  String? _selectedPhaseId = ReportFilterState.selectedPhaseId;
  String? _selectedActivityName = ReportFilterState.selectedActivityName;
  String _searchQuery = ReportFilterState.searchQuery;
  String? _selectedItemName = ReportFilterState.selectedItemName;
  bool _reportGenerated = ReportFilterState.reportGenerated;
  bool _showSuggestions = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!UserSession.hasSkippedTour && !UserSession.visitedModules.contains('ReportsScreen')) {
        ShowCaseWidget.of(context).startShowCase([
          ShowcaseKeys.reportAskAI,
          ShowcaseKeys.reportFilters,
          _chartsKey,
          ShowcaseKeys.reportCSV,
          ShowcaseKeys.helpButton,
        ]);
        UserSession.markModuleVisited('ReportsScreen');
      }
    });
  }

  Future<void> _loadActiveColumns() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = UserSession.userId;
    List<String>? all = prefs.getStringList('activeColumnsAll_$userId');
    List<String>? materials = prefs.getStringList('activeColumnsMaterials_$userId');
    List<String>? labour = prefs.getStringList('activeColumnsLabour_$userId');
    List<String>? equipment = prefs.getStringList('activeColumnsEquipment_$userId');
    
    try {
      final res = await ApiService.get('/users/profile');
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded != null && decoded['user'] != null && decoded['user']['preferences'] != null) {
          final rc = decoded['user']['preferences']['reportColumns'];
          if (rc != null) {
            if (rc['All'] != null) all = List<String>.from(rc['All']);
            if (rc['Materials'] != null) materials = List<String>.from(rc['Materials']);
            if (rc['Labour'] != null) labour = List<String>.from(rc['Labour']);
            if (rc['Equipment'] != null) equipment = List<String>.from(rc['Equipment']);
          }
        }
      }
    } catch(e) {}
    
    if (mounted) {
      setState(() {
        if (all != null) _activeColumnsAll = all;
        if (materials != null) _activeColumnsMaterials = materials;
        if (labour != null) _activeColumnsLabour = labour;
        if (equipment != null) _activeColumnsEquipment = equipment;
      });
    }
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
      if (!ReportFilterState.hasSavedFilters) {
        if (currentGlobalProjId != null) {
          ReportFilterState.selectedProjectId = currentGlobalProjId;
          ReportFilterState.selectedFloor = projectProvider.selectedFloor;
          ReportFilterState.selectedPhaseId = projectProvider.selectedPhaseId;
          ReportFilterState.selectedActivityName = projectProvider.selectedActivity;
          ReportFilterState.lastKnownProjectProviderId = currentGlobalProjId;
        }
      } else if (currentGlobalProjId != null &&
          ReportFilterState.lastKnownProjectProviderId != null &&
          currentGlobalProjId != ReportFilterState.lastKnownProjectProviderId) {
        ReportFilterState.selectedProjectId = currentGlobalProjId;
        ReportFilterState.selectedFloor = projectProvider.selectedFloor;
        ReportFilterState.selectedPhaseId = projectProvider.selectedPhaseId;
        ReportFilterState.selectedActivityName = projectProvider.selectedActivity;
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
      _reportGenerated = ReportFilterState.reportGenerated;
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

  Future<void> _syncPreferences(String key, List<String> cols) async {
    try {
      final tabKey = key.replaceAll('activeColumns', '');
      await ApiService.put('/users/profile', {
        'preferences': {
          'reportColumns': {
            tabKey: cols,
          }
        }
      });
    } catch(e) {}
  }

  Future<void> _setActiveColumnsForTab(String tabName, List<String> cols) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = UserSession.userId;
    
    setState(() {
      if (tabName == 'Materials') {
        _activeColumnsMaterials = cols;
        prefs.setStringList('activeColumnsMaterials_$userId', cols); _syncPreferences('activeColumnsMaterials', cols);
      } else if (tabName == 'Labour') {
        _activeColumnsLabour = cols;
        prefs.setStringList('activeColumnsLabour_$userId', cols); _syncPreferences('activeColumnsLabour', cols);
      } else if (tabName == 'Equipment') {
        _activeColumnsEquipment = cols;
        prefs.setStringList('activeColumnsEquipment_$userId', cols); _syncPreferences('activeColumnsEquipment', cols);
      } else {
        _activeColumnsAll = cols;
        prefs.setStringList('activeColumnsAll_$userId', cols); _syncPreferences('activeColumnsAll', cols);
      }
    });
  }

  void _showCustomizeColumnsDialog(BuildContext context, String tabName) {
    final List<String> allCols = _getAllColumnsForTab(tabName);
    List<String> tempActive = List.from(_getActiveColumnsForTab(tabName));
    final inactive = allCols.where((c) => !tempActive.contains(c)).toList();
    List<String> tempAll = [...tempActive, ...inactive];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Bt.card,
      barrierColor: Bt.scrim,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final maxListH = MediaQuery.of(context).size.height * 0.55;
            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BtSheetHeader(
                    title: 'Edit columns',
                    subtitle: '${tempActive.length} of ${tempAll.length} shown · drag ≡ to reorder',
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
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final item = tempAll.removeAt(oldIndex);
                              tempAll.insert(newIndex, item);
                              final newTempActive = <String>[];
                              for (final col in tempAll) {
                                if (tempActive.contains(col)) {
                                  newTempActive.add(col);
                                }
                              }
                              tempActive = newTempActive;
                            });
                          },
                          itemBuilder: (context, index) {
                            final col = tempAll[index];
                            final isChecked = tempActive.contains(col);
                            return Material(
                              key: ValueKey(col),
                              color: Bt.card,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (index > 0) const Divider(height: 1, indent: 16, color: Bt.line),
                                  SizedBox(
                                    height: 52,
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(col, style: BtText.body(context, color: isChecked ? Bt.ink : Bt.ink3)),
                                        ),
                                        BtSwitch(
                                          value: isChecked,
                                          onChanged: (val) {
                                            setDialogState(() {
                                              if (val == true) {
                                                tempActive.add(col);
                                                final newTempActive = <String>[];
                                                for (final c in tempAll) {
                                                  if (tempActive.contains(c)) {
                                                    newTempActive.add(c);
                                                  }
                                                }
                                                tempActive = newTempActive;
                                              } else {
                                                if (tempActive.length > 1) {
                                                  tempActive.remove(col);
                                                } else {
                                                  btToast(context, 'At least one column must be visible.', error: true);
                                                }
                                              }
                                            });
                                          },
                                        ),
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: const SizedBox(
                                            width: 48,
                                            height: 52,
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
                              _setActiveColumnsForTab(tabName, tempActive);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No report entries to export.')),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV Export failed: $e')));
    }
  }

  Future<void> _handlePdfExport(
    List<EntryModel> filtered,
    String Function(String) getProjectName,
    String quickCategoryTab, {
    List<String>? activeColumns,
  }) async {
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No report entries to export.')),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF Export failed: $e')));
    }
  }

  Future<void> _handleDownloadImportTemplate(
    String quickCategoryTab,
    List<String> activeCols,
  ) async {
    try {
      await CsvImportHelper.downloadTemplate(
        quickCategoryTab: quickCategoryTab,
        activeColumns: activeCols,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import template downloaded!'),
            backgroundColor: Color(0xFF067647),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template download failed: $e'),
            backgroundColor: const Color(0xFFC01048),
          ),
        );
      }
    }
  }

  Future<void> _handleRevertCsv() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revert Last Upload'),
        content: Text('Are you sure you want to undo the last CSV import? This will restore the transactions to their previous state.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Revert', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    
    setState(() => _isImportingCsv = true);
    final success = await ApiService.revertCsv();
    setState(() => _isImportingCsv = false);
    
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully reverted last CSV import')));
        context.read<ReportProvider>().refresh();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to revert CSV import')));
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
        selectedProjectId: _selectedProjectId == 'all'
            ? null
            : _selectedProjectId,
      );
      if (!mounted) return;
      final activeProjId = projectProvider.selectedProject?.id;
      if (activeProjId != null) {
        context.read<ProjectProvider>().load();
      }
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Import Results',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total rows processed: ${result.totalRows}'),
                SizedBox(height: 8),
                Text(
                  'Successfully imported: ${result.successCount}',
                  style: TextStyle(
                    color: Color(0xFF067647),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 16, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• Materials: ${result.materialCount}'),
                      Text('• Labour: ${result.labourCount}'),
                      Text('• Equipment: ${result.equipmentCount}'),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Failed: ${result.failedCount}',
                  style: TextStyle(
                    color: result.failedCount > 0 ? const Color(0xFFC01048) : const Color(0xFF667085),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (result.errors.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Text(
                    'Details/Errors:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Container(
                    constraints: BoxConstraints(maxHeight: 150),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Bt.line),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: result.errors.map((err) => Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            err,
                            style: TextStyle(
                              color: Colors.red[800],
                              fontSize: 13,
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: const Color(0xFFC01048),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImportingCsv = false);
    }
  }

  Widget _buildCsvImportCard(String quickCategoryTab, List<String> activeCols) {
    final tab = quickCategoryTab.isEmpty ? 'All' : quickCategoryTab;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BtSectionHeader(title: 'Import from a spreadsheet'),
        BtGroup(
          children: [
            BtRow(
              leading: const BtTile(icon: Icons.download_rounded),
              title: 'Download template',
              subtitle: 'CSV with your chosen columns',
              showChevron: true,
              onTap: _isImportingCsv ? null : () => _handleDownloadImportTemplate(tab, activeCols),
            ),
            BtRow(
              leading: const BtTile(icon: Icons.view_column_outlined),
              title: 'Customize columns',
              subtitle: 'Pick and reorder template columns',
              showChevron: true,
              onTap: _isImportingCsv ? null : () => _showCustomizeColumnsDialog(context, tab),
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
        const SizedBox(height: 12),
        BtGroup(
          children: [
            BtRow(
              leading: BtTile(icon: Icons.undo_rounded, bg: Bt.redSoft, fg: Bt.red),
              title: 'Revert last CSV import…',
              titleColor: Bt.red,
              onTap: _isImportingCsv
                  ? null
                  : () async {
                      final ok = await btConfirm(
                        context,
                        title: 'Revert last import?',
                        message: 'Entries added by your most recent CSV upload will be removed.',
                        confirmLabel: 'Revert',
                      );
                      if (ok) _handleRevertCsv();
                    },
            ),
          ],
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
    ReportFilterState.reportGenerated = _reportGenerated;
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
    filtered.sort((a, b) {
      int cmp = 0;
      if (_sortColumn == 'date') {
        cmp = a.date.compareTo(b.date);
      } else if (_sortColumn == 'amount') {
        cmp = a.amount.compareTo(b.amount);
      } else if (_sortColumn == 'project') {
        cmp = getProjectName(
          a.projectId,
        ).compareTo(getProjectName(b.projectId));
      }
      return _sortAscending ? cmp : -cmp;
    });
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
    final List<String> activeCols = _getActiveColumnsForTab(quickCategoryTab);
    final List<String> uiActiveCols = [
      ...activeCols,
      'Add More',
      'Record Payment',
      'Edit Entry',
    ];
    final List<DataColumn> columns = uiActiveCols.map((colName) {
      if (colName == 'Date') {
        return DataColumn(
          label: Text(
            'Date',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onSort: (colIndex, ascending) {
            setState(() {
              _sortColumn = 'date';
              _sortAscending = ascending;
              ReportFilterState.sortColumn = 'date';
              ReportFilterState.sortAscending = ascending;
            });
          },
        );
      } else if (colName == 'Project') {
        return DataColumn(
          label: Text(
            'Project',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onSort: (colIndex, ascending) {
            setState(() {
              _sortColumn = 'project';
              _sortAscending = ascending;
              ReportFilterState.sortColumn = 'project';
              ReportFilterState.sortAscending = ascending;
            });
          },
        );
      } else if (colName == 'Amount') {
        return DataColumn(
          label: Text(
            'Amount (INR)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          numeric: true,
          onSort: (colIndex, ascending) {
            setState(() {
              _sortColumn = 'amount';
              _sortAscending = ascending;
              ReportFilterState.sortColumn = 'amount';
              ReportFilterState.sortAscending = ascending;
            });
          },
        );
      } else if (colName == 'Rate' ||
          colName == 'Rate/Day' ||
          colName == 'Rent Rate' ||
          colName == 'Qty' ||
          colName == 'Days' ||
          colName == 'Duration') {
        return DataColumn(
          label: Text(
            colName,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          numeric: true,
        );
      } else if (colName == 'Paid') {
        return DataColumn(
          label: Text(
            'Paid (INR)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          numeric: true,
        );
      } else if (colName == 'Remaining') {
        return DataColumn(
          label: Text(
            'Remaining (INR)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          numeric: true,
        );
      } else if (colName == 'Add More' ||
          colName == 'Record Payment' ||
          colName == 'Edit Entry') {
        return DataColumn(
          label: Text(
            colName,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        );
      } else {
        return DataColumn(
          label: Text(
            colName,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        );
      }
    }).toList();
    context.read<NavController>().markCurrent('/reports');
    final bt = context.bt;
    final entriesTitle = quickCategoryTab == 'All' || quickCategoryTab.isEmpty
        ? 'Entries'
        : '$quickCategoryTab entries';

    void openFullScreen() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _FullScreenLogsViewer(
            columns: columns,
            filteredEntries: filtered,
            getProjectName: getProjectName,
            quickCategoryTab: quickCategoryTab,
            title: quickCategoryTab == 'All'
                ? 'Report Logs'
                : '$quickCategoryTab Report Logs',
            onExportCsv: () => _handleCsvExport(
              filtered,
              getProjectName,
              quickCategoryTab,
              activeColumns: activeCols,
            ),
            onExportPdf: () => _handlePdfExport(
              filtered,
              getProjectName,
              quickCategoryTab,
              activeColumns: activeCols,
            ),
            activeColumns: uiActiveCols,
          ),
        ),
      );
    }

    void openExport() {
      showBtSheet(
        context,
        title: 'Export',
        subtitle: '$totalCount entries · current filters',
        builder: (sheetCtx) => BtGroup(
          children: [
            BtRow(
              leading: const BtTile(icon: Icons.description_outlined),
              title: 'Download CSV',
              subtitle: 'Opens in Excel or Google Sheets',
              showChevron: true,
              onTap: () {
                Navigator.pop(sheetCtx);
                _handleCsvExport(filtered, getProjectName, quickCategoryTab, activeColumns: activeCols);
              },
            ),
            BtRow(
              leading: const BtTile(icon: Icons.picture_as_pdf_outlined),
              title: 'Download PDF',
              subtitle: 'Ready to print or share',
              showChevron: true,
              onTap: () {
                Navigator.pop(sheetCtx);
                _handlePdfExport(filtered, getProjectName, quickCategoryTab, activeColumns: activeCols);
              },
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
                  ['date', false, 'Newest first'],
                  ['date', true, 'Oldest first'],
                  ['amount', false, 'Amount: high to low'],
                  ['amount', true, 'Amount: low to high'],
                  ['project', true, 'Project name'],
                ])
                  BtRow(
                    title: o[2] as String,
                    minHeight: 48,
                    trailing: (_sortColumn == o[0] && _sortAscending == o[1])
                        ? Icon(Icons.check_rounded, color: bt.brand, size: 20)
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
                    _showCustomizeColumnsDialog(context, quickCategoryTab.isEmpty ? 'All' : quickCategoryTab);
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
    final showSheet = _tableView &&
        !(quickCategoryTab != 'All' && !_reportGenerated) &&
        paginatedEntries.isNotEmpty;
    final extraFilters = [
      _selectedFloor,
      _selectedPhaseId,
      _selectedActivityName,
      _selectedStatus == 'All' ? null : _selectedStatus,
    ].where((v) => v != null).length;

    return Scaffold(
      backgroundColor: Bt.ground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: bt.brand,
          onRefresh: provider.refresh,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              BtLargeHeader(
                title: 'Reports',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Showcase(
                      key: ShowcaseKeys.helpButton,
                      description: 'Tap here anytime to replay this tour and get help.',
                      tooltipBackgroundColor: Bt.ink,
                      textColor: Colors.white,
                      tooltipBorderRadius: BorderRadius.circular(16),
                      tooltipPadding: const EdgeInsets.all(16),
                      child: BtIconButton(
                        icon: Icons.help_outline_rounded,
                        semantic: 'App guidelines',
                        color: Bt.ink2,
                        onTap: () {
                          ShowCaseWidget.of(context).startShowCase([
                            ShowcaseKeys.reportAskAI,
                            ShowcaseKeys.reportFilters,
                            _chartsKey,
                            ShowcaseKeys.reportCSV,
                            ShowcaseKeys.helpButton,
                          ]);
                        },
                      ),
                    ),
                    BtIconButton(
                      icon: Icons.ios_share_rounded,
                      semantic: 'Export report',
                      color: Bt.ink2,
                      onTap: openExport,
                    ),
                    Semantics(
                      button: true,
                      label: 'Account',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                        child: const Padding(padding: EdgeInsets.all(4), child: ProfileAvatar(radius: 18)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Bt.gutter),
                child: Showcase(
                  key: ShowcaseKeys.reportAskAI,
                  description: 'Ask AI about costs, missing entries, or anything related to this report.',
                  tooltipBackgroundColor: Bt.ink,
                  textColor: Colors.white,
                  tooltipBorderRadius: BorderRadius.circular(16),
                  tooltipPadding: const EdgeInsets.all(16),
                  child: _AskAiBanner(projectName: provider.selectedProjectName),
                ),
              ),
              const SizedBox(height: 12),
              Showcase(
                key: ShowcaseKeys.reportFilters,
                description: 'Filter your reports by project, date, status and more.',
                tooltipBackgroundColor: Bt.ink,
                textColor: Colors.white,
                tooltipBorderRadius: BorderRadius.circular(16),
                tooltipPadding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Bt.gutter),
                  child: Row(
                    children: [
                      BtChip(
                        label: projectChip,
                        trailingIcon: Icons.expand_more_rounded,
                        selected: _selectedProjectId != 'all',
                        onTap: () => _pickProject(context, projectProvider),
                      ),
                      const SizedBox(width: 8),
                      BtChip(
                        label: periodChip,
                        trailingIcon: Icons.expand_more_rounded,
                        selected: _datePreset != 'All Time',
                        onTap: () => _pickPeriod(context),
                      ),
                      const SizedBox(width: 8),
                      BtChip(
                        label: extraFilters == 0 ? 'Filter' : 'Filter · $extraFilters',
                        icon: Icons.tune_rounded,
                        selected: extraFilters > 0,
                        onTap: () => _openFilterSheet(context, projectProvider),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Bt.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Showcase(
                      key: _chartsKey,
                      description: 'View a quick financial summary based on your filters.',
                      tooltipBackgroundColor: Bt.ink,
                      textColor: Colors.white,
                      tooltipBorderRadius: BorderRadius.circular(16),
                      tooltipPadding: const EdgeInsets.all(16),
                      child: _buildCostSummary(
                        context,
                        total: grandTotal,
                        paid: grandPaid,
                        remaining: grandRemaining,
                        material: materialTotal,
                        labour: labourTotal,
                        equipment: equipmentTotal,
                        onType: _selectCategoryTab,
                      ),
                    ),
                    const SizedBox(height: 12),
                    EfficiencyBanner(
                      note: 'Tap to view category breakdowns, monthly spending trends, and budget health charts.',
                      isExceeded: grandRemaining > 0,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Entries', maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.title(context)),
                        ),
                        if (!_tableView) ...[
                          Text('$totalCount', style: BtText.num(BtText.subhead(context))),
                          const SizedBox(width: 8),
                        ],
                        ReportViewToggle(
                          table: _tableView,
                          onChanged: (v) => setState(() {
                            _tableView = v;
                            ReportFilterState.tableView = v;
                          }),
                        ),
                        const SizedBox(width: 4),
                        BtIconButton(
                          icon: Icons.more_horiz_rounded,
                          semantic: 'Sort, columns, table and export',
                          color: Bt.ink2,
                          filled: true,
                          onTap: openEntriesMenu,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _CategoryTabs(
                      activeTab: quickCategoryTab,
                      onTabChanged: _selectCategoryTab,
                    ),
                    const SizedBox(height: 12),
                    if (quickCategoryTab != 'All')
                      _buildCategorySubFilters(context, quickCategoryTab, allEntries)
                    else
                      _buildAllTabSearchBar(context),
                    const SizedBox(height: 16),
                    if (quickCategoryTab != 'All' && !_reportGenerated)
                      BtCard(
                        child: BtEmpty(
                          icon: Icons.analytics_outlined,
                          title: 'Set your filters',
                          message: 'Configure filters above and tap "Generate report" to view logs.',
                        ),
                      )
                    else if (paginatedEntries.isEmpty)
                      const BtCard(
                        child: BtEmpty(
                          icon: Icons.search_off_outlined,
                          title: 'No transaction logs match filters.',
                        ),
                      )
                    else if (!_tableView) ...[
                      ..._buildEntryGroups(context, paginatedEntries, getProjectName),
                      if (totalCount > _rowsPerPage || _rowsPerPage != 10)
                        _buildPager(context, safeCurrentPage, totalPages)
                      else
                        const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              // The spreadsheet runs edge to edge, so it sits outside the padded column.
              if (showSheet) ...[
                ReportSheet(
                  entries: paginatedEntries,
                  columns: activeCols,
                  totalCount: totalCount,
                  projectNameOf: (e) => getProjectName(e.projectId),
                  statusOf: (e) => _getPaymentStatusLabel(e.paymentStatus, amount: e.amount, paidAmount: e.paidAmount),
                  sortColumn: _sortColumn,
                  sortAscending: _sortAscending,
                  onSort: (column, ascending) => setState(() {
                    _sortColumn = column;
                    _sortAscending = ascending;
                    _currentPage = 1;
                    ReportFilterState.sortColumn = column;
                    ReportFilterState.sortAscending = ascending;
                  }),
                  onRowTap: (e) => _showEntryDetailsDialog(context, e, getProjectName(e.projectId)),
                  onAddMore: (e) => _ReportActions.addMore(context, e),
                  onRecordPayment: (e) => _ReportActions.recordPayment(context, e, getProjectName(e.projectId)),
                  onEdit: (e) => _ReportActions.editEntry(context, e),
                  onEditColumns: () => _showCustomizeColumnsDialog(context, quickCategoryTab.isEmpty ? 'All' : quickCategoryTab),
                  onFullScreen: openFullScreen,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Bt.gutter, 4, Bt.gutter, 0),
                  child: _buildPager(context, safeCurrentPage, totalPages),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Bt.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    Showcase(
                      key: ShowcaseKeys.reportCSV,
                      description: 'Use this to export data to CSV or import bulk entries from a CSV file.',
                      tooltipBackgroundColor: Bt.ink,
                      textColor: Colors.white,
                      tooltipBorderRadius: BorderRadius.circular(16),
                      tooltipPadding: const EdgeInsets.all(16),
                      child: _buildCsvImportCard(quickCategoryTab, activeCols),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(),
    );
  }

  static String _sentence(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  void _selectCategoryTab(String newTab) {
    setState(() {
      _currentPage = 1;
      _selectedItemName = null;
      _reportGenerated = true;
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
    context.read<ProjectProvider>().loadEntriesForProject(val == 'all' ? null : val);
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

  void _openFilterSheet(BuildContext context, ProjectProvider projectProvider) {
    showBtSheet(
      context,
      title: 'Filter',
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          void refresh() => setSheet(() {});
          final proj = projectProvider.projects.where((p) => p.id == _selectedProjectId).firstOrNull;
          final floors = proj?.floors ?? [];
          final phases = proj?.selectedPhases ?? [];
          final selectedPhase = phases.where((p) => p.id == _selectedPhaseId).firstOrNull;
          final List<ProjectActivity> activities = [];
          if (_selectedPhaseId != null) {
            activities.addAll(selectedPhase?.activities ?? []);
          } else if (proj != null) {
            activities.addAll(phases.expand((p) => p.activities));
          }
          final activityNames = activities.map((a) => a.name).toSet().toList();
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
                  whereRow('Floor', _selectedFloor ?? 'All', hasProject && floors.isNotEmpty, () async {
                    final v = await _pickOption(sheetCtx, 'Floor', [const MapEntry('Select Floor', 'All floors'), ...floors.map((f) => MapEntry(f, f))], _selectedFloor ?? 'Select Floor');
                    if (v != null) setState(() { _selectedFloor = v == 'Select Floor' ? null : v; _currentPage = 1; });
                  }),
                  whereRow('Phase', selectedPhase?.phaseName ?? 'All', hasProject && phases.isNotEmpty, () async {
                    final v = await _pickOption(sheetCtx, 'Phase', [const MapEntry('Select Phase', 'All phases'), ...phases.map((ph) => MapEntry(ph.id, ph.phaseName))], _selectedPhaseId ?? 'Select Phase');
                    if (v != null) setState(() { _selectedPhaseId = v == 'Select Phase' ? null : v; _selectedActivityName = null; _currentPage = 1; });
                  }),
                  whereRow('Activity', _selectedActivityName ?? 'All', hasProject && activityNames.isNotEmpty, () async {
                    final v = await _pickOption(sheetCtx, 'Activity', [const MapEntry('Select Activity', 'All activities'), ...activityNames.map((n) => MapEntry(n, n))], _selectedActivityName ?? 'Select Activity');
                    if (v != null) setState(() { _selectedActivityName = v == 'Select Activity' ? null : v; _currentPage = 1; });
                  }),
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
      final key = _sortColumn == 'date' ? formatDayGroup(e.date) : '';
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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(Bt.rChip),
            onTap: () async {
              final v = await _pickOption(context, 'Rows per page', const [MapEntry('10', '10'), MapEntry('20', '20'), MapEntry('50', '50')], '$_rowsPerPage');
              if (v != null) setState(() { _rowsPerPage = int.parse(v); _currentPage = 1; });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Show $_rowsPerPage', style: BtText.subhead(context)),
                const Icon(Icons.expand_more_rounded, size: 18, color: Bt.ink3),
              ]),
            ),
          ),
          const Spacer(),
          BtIconButton(
            icon: Icons.chevron_left_rounded,
            semantic: 'Previous page',
            color: page > 1 ? Bt.ink : Bt.placeholder,
            onTap: page > 1 ? () => setState(() => _currentPage = page - 1) : () {},
          ),
          Text('$page of $totalPages', style: BtText.num(BtText.subhead(context, color: Bt.ink))),
          BtIconButton(
            icon: Icons.chevron_right_rounded,
            semantic: 'Next page',
            color: page < totalPages ? Bt.ink : Bt.placeholder,
            onTap: page < totalPages ? () => setState(() => _currentPage = page + 1) : () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCostSummary(
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
    Widget split(String label, double v, Color c) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: BtText.caption(context)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatInr(v), maxLines: 1, style: BtText.num(BtText.headline(context).copyWith(color: c))),
              ),
            ],
          ),
        );
    Widget type(String label, String tab, String typeName, double v, Color c) {
      final share = total > 0 ? (v / total).clamp(0.0, 1.0) : 0.0;
      return BtRow(
        leading: BtTypeTile(type: typeName),
        title: label,
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
                BtProgress(value: share, color: c, thin: true),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Bt.placeholder, size: 22),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total billed', style: BtText.subhead(context)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatInr(total), maxLines: 1, style: BtText.amount(context)),
              ),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(children: [
                  split('Paid', paid, Bt.green),
                  const VerticalDivider(width: 24, thickness: 1, color: Bt.line),
                  split('Still owed', remaining, remaining > 0 ? Bt.amber : Bt.green),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const BtSectionHeader(title: 'By type'),
        BtGroup(children: [
          type('Material', 'Materials', 'material', material, bt.series[0]),
          type('Labour', 'Labour', 'labour', labour, bt.series[1]),
          type('Equipment', 'Equipment', 'equipment', equipment, bt.series[2]),
        ]),
      ],
    );
  }

  Widget _searchField(BuildContext context, String hint, ValueChanged<String> onChanged) {
    return TextField(
      controller: _searchController,
      onChanged: onChanged,
      style: BtText.body(context),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: BtText.body(context, color: Bt.placeholder),
        prefixIcon: const Icon(Icons.search_rounded, color: Bt.ink3, size: 22),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.cancel_rounded, color: Bt.placeholder, size: 20),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedItemName = null;
                    _showSuggestions = false;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Bt.fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: BorderSide.none),
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

  Widget _buildCategorySubFilters(
    BuildContext context,
    String tabName,
    List<EntryModel> allEntries,
  ) {
    final String searchPlaceholder;
    final String dropdownLabel;
    final EntryType targetType;
    if (tabName == 'Materials') {
      searchPlaceholder = 'Search materials';
      dropdownLabel = 'Material';
      targetType = EntryType.material;
    } else if (tabName == 'Labour') {
      searchPlaceholder = 'Search labour';
      dropdownLabel = 'Worker Type';
      targetType = EntryType.labour;
    } else {
      searchPlaceholder = 'Search equipment';
      dropdownLabel = 'Equipment';
      targetType = EntryType.equipment;
    }
    final uniqueNames = allEntries
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
                border: Border.all(color: Bt.line),
                boxShadow: const [BoxShadow(color: Color(0x14101828), blurRadius: 16, offset: Offset(0, 6))],
              ),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: BtChip(
                  label: '$dropdownLabel: ${_selectedItemName ?? 'All'}',
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
              if (!_reportGenerated) ...[
                const SizedBox(width: 8),
                BtButton(
                  label: 'Generate report',
                  small: true,
                  expand: false,
                  icon: Icons.analytics_outlined,
                  onPressed: () {
                    setState(() {
                      _reportGenerated = true;
                      _currentPage = 1;
                      _showSuggestions = false;
                    });
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showEntryDetailsDialog(
    BuildContext context,
    EntryModel entry,
    String projectName,
  ) {
    final status = _getPaymentStatusLabel(
      entry.paymentStatus,
      amount: entry.amount,
      paidAmount: entry.paidAmount,
    );
    final canDelete = EntryPermissions.canDelete(status: entry.approvalStatus.toLowerCase(), createdBy: entry.createdBy ?? '', projectId: entry.projectId);
    showBtSheet(
      context,
      title: entry.description.isEmpty ? 'Entry details' : entry.description,
      subtitle: '$projectName · ${_sentence(entry.type.name)}',
      builder: (sheetCtx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_formatIndianCurrency(entry.amount), style: BtText.amount(sheetCtx, size: 28))),
                    BtBadge(label: status, tone: status == 'Fully Paid' ? BtTone.green : (status == 'Partial' ? BtTone.amber : BtTone.red)),
                  ],
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: _miniStat(sheetCtx, 'Paid', _formatIndianCurrency(entry.paidAmount), Bt.green)),
                      const VerticalDivider(width: 24, thickness: 1, color: Bt.line),
                      Expanded(child: _miniStat(sheetCtx, 'Remaining', _formatIndianCurrency(entry.remainingAmount), entry.remainingAmount > 0 ? Bt.amber : Bt.green)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (entry.rejectionReason != null && entry.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            BtCard(
              variant: BtCardVariant.danger,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rejection reason', style: BtText.caption(sheetCtx, color: Bt.red, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(entry.rejectionReason!, style: BtText.body(sheetCtx)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          BtGroup(
            children: [
              _buildDetailRow('Project', projectName),
              _buildDetailRow('Type', _sentence(entry.type.name)),
              _buildDetailRow('Date', _formatDateLong(entry.date)),
              if (entry.description.isNotEmpty) _buildDetailRow('Description', entry.description),
              if (entry.brand != null && entry.brand!.isNotEmpty) _buildDetailRow('Brand', entry.brand!),
              if (entry.floor != null && entry.floor!.isNotEmpty) _buildDetailRow('Floor', entry.floor!),
              if (entry.phase != null && entry.phase!.isNotEmpty) _buildDetailRow('Phase', entry.phase!),
              if (entry.unit != null && entry.unit!.isNotEmpty) _buildDetailRow('Unit', entry.unit!),
            ],
          ),
          const SizedBox(height: 8),
          _PaymentHistorySection(
            entry: entry,
            formatCurrency: _formatIndianCurrency,
            formatDate: _formatDateLong,
          ),
          const SizedBox(height: 16),
          BtButton(
            label: 'Record Payment',
            icon: Icons.credit_card_outlined,
            onPressed: () {
              Navigator.of(sheetCtx).pop();
              _ReportActions.recordPayment(context, entry, projectName);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: BtButton(
                  label: 'Add More',
                  icon: Icons.add_rounded,
                  variant: BtButtonVariant.secondary,
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    _ReportActions.addMore(context, entry);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BtButton(
                  label: 'Edit Entry',
                  icon: Icons.edit_outlined,
                  variant: BtButtonVariant.secondary,
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    _ReportActions.editEntry(context, entry);
                  },
                ),
              ),
            ],
          ),
          if (canDelete) ...[
            const SizedBox(height: 10),
            BtButton(
              label: 'Delete entry…',
              variant: BtButtonVariant.destructive,
              icon: Icons.delete_outline,
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
          Text(label, style: BtText.caption(context)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: BtText.num(BtText.body(context, weight: FontWeight.w600, color: color))),
          ),
        ],
      );

  Widget _buildDetailRow(String label, String value, {bool isWarning = false}) {
    return BtValueRow(label: label, value: value, valueColor: isWarning ? Bt.red : null);
  }


}

class _AskAiBanner extends StatelessWidget {
  _AskAiBanner({required this.projectName});
  final String projectName;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      button: true,
      label: 'Ask AI about costs, entries and inventory',
      excludeSemantics: true,
      child: Material(
        color: Bt.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Bt.rInput),
          side: const BorderSide(color: Bt.inputBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Bt.rInput),
          onTap: () => Navigator.pushNamed(
            context,
            '/ai-chat',
            arguments: {'projectName': projectName},
          ),
          child: SizedBox(
            height: Bt.fieldH,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.auto_awesome, color: bt.brand, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ask AI about your costs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BtText.body(context, color: Bt.placeholder),
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  _CategoryTabs({required this.activeTab, required this.onTabChanged});
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

class _FullScreenLogsViewer extends StatefulWidget {
  _FullScreenLogsViewer({
    required this.columns,
    required this.filteredEntries,
    required this.getProjectName,
    required this.quickCategoryTab,
    required this.title,
    required this.onExportCsv,
    required this.onExportPdf,
    required this.activeColumns,
  });
  final List<DataColumn> columns;
  final List<EntryModel> filteredEntries;
  final String Function(String) getProjectName;
  final String quickCategoryTab;
  final String title;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;
  final List<String> activeColumns;
  @override
  State<_FullScreenLogsViewer> createState() => _FullScreenLogsViewerState();
}

class _FullScreenLogsViewerState extends State<_FullScreenLogsViewer> {
  int _quarterTurns = 0;
  void _toggleRotation() {
    setState(() {
      _quarterTurns = (_quarterTurns == 0) ? 1 : 0;
    });
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

  Widget _buildTypeChip(EntryType type) {
    Color color;
    IconData icon;
    switch (type) {
      case EntryType.material:
        color = AppColors.primary;
        icon = Icons.construction;
        break;
      case EntryType.labour:
        color = Color(0xFF067647);
        icon = Icons.people_outline;
        break;
      case EntryType.equipment:
        color = Color(0xFFF59E0B);
        icon = Icons.precision_manufacturing_outlined;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 4),
          Text(
            type.name.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    final label = _getPaymentStatusLabel(status);
    switch (label) {
      case 'Fully Paid':
        bg = Color(0xFFE7F6EE);
        text = Color(0xFF067647);
        break;
      case 'Partial':
        bg = Color(0xFFFEF3E7);
        text = Color(0xFFB54708);
        break;
      case 'Not Paid':
      default:
        bg = Color(0xFFFDECEF);
        text = Color(0xFFC01048);
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showEntryDetailsDialog(
    BuildContext context,
    EntryModel entry,
    String projectName,
  ) {
    String formatDateLong(DateTime dt) {
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

    Widget detailRow(String label, String value, {bool isWarning = false}) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isWarning ? AppColors.error : AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Entry Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (EntryPermissions.canDelete(status: entry.approvalStatus.toLowerCase(), createdBy: entry.createdBy ?? '', projectId: entry.projectId))
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 20, color: const Color(0xFFC01048)),
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                _ReportActions.deleteEntry(context, entry);
                              },
                            ),
                          IconButton(
                            icon: Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Divider(height: 1),
                  SizedBox(height: 12),
                  detailRow('Project', projectName),
                  detailRow('Type', entry.type.name.toUpperCase()),
                  detailRow('Date', formatDateLong(entry.date)),
                  detailRow('Amount', _formatIndianCurrency(entry.amount)),
                  detailRow('Paid', _formatIndianCurrency(entry.paidAmount)),
                  detailRow(
                    'Remaining',
                    _formatIndianCurrency(entry.remainingAmount),
                  ),
                  detailRow(
                    'Status',
                    _getPaymentStatusLabel(entry.paymentStatus),
                  ),
                  _PaymentHistorySection(
                    entry: entry,
                    formatCurrency: _formatIndianCurrency,
                    formatDate: formatDateLong,
                  ),
                  if (entry.description.isNotEmpty)
                    detailRow('Description', entry.description),
                  if (entry.brand != null && entry.brand!.isNotEmpty)
                    detailRow('Brand', entry.brand!),
                  if (entry.floor != null && entry.floor!.isNotEmpty)
                    detailRow('Floor', entry.floor!),
                  if (entry.phase != null && entry.phase!.isNotEmpty)
                    detailRow('Phase', entry.phase!),
                  if (entry.unit != null && entry.unit!.isNotEmpty)
                    detailRow('Unit', entry.unit!),
                  if (entry.rejectionReason != null &&
                      entry.rejectionReason!.isNotEmpty)
                    detailRow(
                      'Rejection Reason',
                      entry.rejectionReason!,
                      isWarning: true,
                    ),
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _ReportActionBtn(
                          label: 'Add More',
                          icon: Icons.add_circle_outline,
                          style: _ReportActionStyle.primary,
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _ReportActions.addMore(context, entry);
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _ReportActionBtn(
                          label: 'Record Payment',
                          icon: Icons.credit_card_outlined,
                          style: _ReportActionStyle.secondary,
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _ReportActions.recordPayment(
                              context,
                              entry,
                              projectName,
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _ReportActionBtn(
                          label: 'Edit Entry',
                          icon: Icons.edit_outlined,
                          style: _ReportActionStyle.tertiary,
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _ReportActions.editEntry(context, entry);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rotated = _quarterTurns != 0;
    return Scaffold(
      backgroundColor: Bt.card,
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: BtText.navTitle(context)),
            Text('${widget.filteredEntries.length} entries', style: BtText.caption(context)),
          ],
        ),
        backgroundColor: Bt.card,
        surfaceTintColor: Bt.card,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Bt.line)),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded, color: Bt.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: rotated ? 'Straight View' : 'Rotate View (Landscape)',
            icon: Icon(
              rotated ? Icons.screen_lock_portrait : Icons.screen_rotation,
              color: Bt.ink2,
            ),
            onPressed: _toggleRotation,
          ),
          Theme(
            data: Theme.of(context).copyWith(cardColor: Colors.white),
            child: PopupMenuButton<String>(
              tooltip: 'Export Options',
              icon: const Icon(Icons.ios_share_rounded, color: Bt.ink2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (val) {
                if (val == 'csv') {
                  widget.onExportCsv();
                } else if (val == 'pdf') {
                  widget.onExportPdf();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text('Download CSV'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(
                        Icons.picture_as_pdf_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text('Download PDF'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rows = widget.filteredEntries.map((entry) {
              final projectName = widget.getProjectName(entry.projectId);
              final List<DataCell> cells = widget.activeColumns.map((colName) {
                if (colName == 'Purchased Date') {
                  return DataCell(
                    Text(
                      _formatDateShort(entry.date),
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                } else if (colName == 'Payment Date') {
                  final payDateStr = entry.paymentDate != null
                      ? _formatDateShort(entry.paymentDate!)
                      : '—';
                  return DataCell(
                    Text(payDateStr, style: TextStyle(fontSize: 13)),
                  );
                } else if (colName == 'Project') {
                  return DataCell(
                    Text(projectName, style: TextStyle(fontSize: 13)),
                  );
                } else if (colName == 'Type') {
                  return DataCell(_buildTypeChip(entry.type));
                } else if (colName == 'Description') {
                  return DataCell(
                    Text(
                      entry.description.isEmpty ? '—' : entry.description,
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                } else if (colName == 'Material' ||
                    colName == 'Worker Type' ||
                    colName == 'Equipment') {
                  return DataCell(
                    Text(
                      entry.description,
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                } else if (colName == 'Brand') {
                  return DataCell(
                    Text(
                      entry.brand ?? '—',
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                } else if (colName == 'Floor') {
                  return DataCell(
                    Text(
                      entry.floor ?? '—',
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                } else if (colName == 'Phase') {
                  return DataCell(
                    Text(
                      entry.phase ?? '—',
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                } else if (colName == 'Activity') {
                  return DataCell(
                    Text(
                      entry.activity ?? '—',
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                } else if (colName == 'Unit') {
                  return DataCell(
                    Text(
                      entry.unit ?? '—',
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                } else if (colName == 'Status') {
                  return DataCell(_buildStatusBadge(entry.paymentStatus));
                } else if (colName == 'Amount') {
                  return DataCell(
                    Text(
                      _formatIndianCurrency(entry.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  );
                } else if (colName == 'Paid') {
                  return DataCell(
                    Text(
                      _formatIndianCurrency(entry.paidAmount),
                      style: TextStyle(
                        fontSize: 13,
                        color: entry.paidAmount > 0
                            ? Color(0xFF067647)
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                } else if (colName == 'Remaining') {
                  final rem = entry.remainingAmount;
                  return DataCell(
                    Text(
                      _formatIndianCurrency(rem),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: rem > 0
                            ? Color(0xFFC01048)
                            : Color(0xFF067647),
                      ),
                    ),
                  );
                } else if (colName == 'Rate' ||
                    colName == 'Rate/Day' ||
                    colName == 'Rent Rate') {
                  final rate = entry.ratePerUnit ?? 0.0;
                  return DataCell(
                    Text(
                      _formatIndianCurrency(rate),
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                } else if (colName == 'Qty' ||
                    colName == 'Days' ||
                    colName == 'Duration') {
                  final rate = entry.ratePerUnit ?? 0.0;
                  final val = (rate == 0) ? 0.0 : entry.amount / rate;
                  return DataCell(
                    Text(
                      val.toStringAsFixed(1),
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                } else if (colName == 'Add More') {
                  return DataCell(
                    _ReportActionBtn(
                      label: 'Add More',
                      icon: Icons.add_circle_outline,
                      style: _ReportActionStyle.primary,
                      onTap: () => _ReportActions.addMore(context, entry),
                    ),
                  );
                } else if (colName == 'Record Payment') {
                  return DataCell(
                    _ReportActionBtn(
                      label: 'Record Payment',
                      icon: Icons.credit_card_outlined,
                      style: _ReportActionStyle.secondary,
                      onTap: () => _ReportActions.recordPayment(
                        context,
                        entry,
                        projectName,
                      ),
                    ),
                  );
                } else if (colName == 'Edit Entry') {
                  return DataCell(
                    _ReportActionBtn(
                      label: 'Edit Entry',
                      icon: Icons.edit_outlined,
                      style: _ReportActionStyle.tertiary,
                      onTap: () => _ReportActions.editEntry(context, entry),
                    ),
                  );
                } else {
                  return DataCell(SizedBox.shrink());
                }
              }).toList();
              return DataRow(
                onSelectChanged: (selected) {
                  if (selected ?? false) {
                    _showEntryDetailsDialog(context, entry, projectName);
                  }
                },
                cells: cells,
              );
            }).toList();
            Widget tableWidget = SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Theme(
                  data: Theme.of(context).copyWith(cardColor: Colors.white),
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStateProperty.all(
                      AppColors.primary.withValues(alpha: 0.04),
                    ),
                    horizontalMargin: 16,
                    columnSpacing: 24,
                    columns: widget.columns,
                    rows: rows,
                  ),
                ),
              ),
            );
            if (rotated) {
              tableWidget = RotatedBox(
                quarterTurns: _quarterTurns,
                child: SizedBox(
                  width: constraints.maxHeight,
                  height: constraints.maxWidth,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(cardColor: Colors.white),
                        child: DataTable(
                          showCheckboxColumn: false,
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.primary.withValues(alpha: 0.04),
                          ),
                          horizontalMargin: 16,
                          columnSpacing: 24,
                          columns: widget.columns,
                          rows: rows,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return Center(child: tableWidget);
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

enum _ReportActionStyle { primary, secondary, tertiary }

class _ReportActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final _ReportActionStyle style;
  final VoidCallback onTap;
  _ReportActionBtn({
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
      case _ReportActionStyle.primary:
        deco = BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B63CE), Color(0xFF1D4ED8)],
          ),
          borderRadius: BorderRadius.circular(6),
        );
        color = Colors.white;
        break;
      case _ReportActionStyle.secondary:
        deco = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(0xFF0B63CE), width: 1.0),
        );
        color = Color(0xFF0B63CE);
        break;
      case _ReportActionStyle.tertiary:
        deco = BoxDecoration(
          color: Color(0xFFEEF1F5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(0xFFE4E7EC), width: 1.0),
        );
        color = Color(0xFF475467);
        break;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: deco,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    Navigator.pushNamed(context, route, arguments: dupArgs).then((val) {
      if (context.mounted) {
        final loadId = ReportFilterState.selectedProjectId == 'all'
            ? null
            : ReportFilterState.selectedProjectId;
        context.read<ProjectProvider>().loadEntriesForProject(loadId);
        context.read<ProjectProvider>().load();
      }
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
    Navigator.pushNamed(context, route, arguments: editArgs).then((val) {
      if (context.mounted) {
        final loadId = ReportFilterState.selectedProjectId == 'all'
            ? null
            : ReportFilterState.selectedProjectId;
        context.read<ProjectProvider>().loadEntriesForProject(loadId);
        context.read<ProjectProvider>().load();
      }
    });
  }

  static Future<void> deleteEntry(BuildContext context, EntryModel entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Entry?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to permanently delete this entry?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: const Color(0xFF667085))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC01048)),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(child: CircularProgressIndicator()),
      );
      
      final success = await ApiService.deleteTransaction(entry.id);
      
      if (context.mounted) {
        Navigator.of(context).pop(); // pop progress
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Entry deleted successfully'), backgroundColor: const Color(0xFFC01048)),
          );
          context.read<ProjectProvider>().load();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete entry'), backgroundColor: const Color(0xFFC01048)),
          );
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
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    final tx = await ApiService.fetchTransactionById(entry.id);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
    if (tx == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load transaction details.')),
        );
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
          context.read<ProjectProvider>().load();
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
    Widget header = BtSectionHeader(
      title: 'Payment history',
      action: history.length > 1 ? (_viewAll ? 'View less' : 'View all (${history.length})') : null,
      onAction: () => setState(() => _viewAll = !_viewAll),
    );
    Widget content;
    if (_isLoading) {
      content = Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              height: 12,
              width: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Loading payment history...',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    } else if (history.isEmpty) {
      if (widget.entry.paidAmount > 0) {
        content = Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Detailed payment history is unavailable for payments recorded before transaction tracking was introduced.',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        );
      } else {
        content = Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No payments recorded yet.',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        );
      }
    } else {
      final displayedList = List.from(history.reversed);
      final itemsToShow = _viewAll ? displayedList : [displayedList.first];
      Widget list = ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: itemsToShow.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 16, color: Bt.line),
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
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Column(
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
                            dateStr,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.badgeInfoBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  method.isEmpty ? method : method[0].toUpperCase() + method.substring(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.badgeInfoText,
                                  ),
                                ),
                              ),
                              if (receipt != null && receipt.isNotEmpty) ...[
                                SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.parse(receipt);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  },
                                  child: Text(
                                    'Receipt ↗',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      widget.formatCurrency(amt),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.badgeSuccessText,
                      ),
                    ),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    'Note: $note',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
      if (_viewAll && displayedList.length > 3) {
        content = Container(
          constraints: BoxConstraints(maxHeight: 180),
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
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          BtCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: content),
        ],
      ),
    );
  }
}
