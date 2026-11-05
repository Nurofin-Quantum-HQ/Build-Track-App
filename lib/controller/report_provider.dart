import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'report_model.dart';
class ReportProvider extends ChangeNotifier {
  int _tabIndex = 0;
  String _selectedProjectId = 'all';
  ProjectProvider? _projectProvider;
  int get tabIndex => _tabIndex;
  String get selectedProjectId => _selectedProjectId;
  String get selectedProjectName {
    if (_selectedProjectId == 'all') return 'All Active Projects';
    final match = _projectProvider?.projects
        .where((p) => p.id == _selectedProjectId)
        .firstOrNull;
    return match?.name ?? 'All Active Projects';
  }
  bool get isLoading => _projectProvider?.isLoading ?? false;
  String? get error => _projectProvider?.error;
  bool get hasData => _projectProvider?.hasProjects ?? false;
  ReportModel get report => buildLiveReport();
  String get currentPeriod {
    switch (_tabIndex) {
      case 0:
        return 'month';
      case 1:
        return 'quarter';
      case 2:
        return 'year';
      default:
        return 'month';
    }
  }
  void linkProjectProvider(ProjectProvider provider) {
    if (_projectProvider == provider) return;
    _projectProvider?.removeListener(_onProjectDataChanged);
    _projectProvider = provider;
    provider.addListener(_onProjectDataChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  void _onProjectDataChanged() {
    notifyListeners();
  }
  @override
  void dispose() {
    _projectProvider?.removeListener(_onProjectDataChanged);
    super.dispose();
  }
  void selectTab(int index) {
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
  }
  void selectProject(String projectId) {
    if (_selectedProjectId == projectId) return;
    _selectedProjectId = projectId;
    notifyListeners();
  }
  /// Reload projects, then the entries for the project this report shows
  /// (all projects for 'all'). load() alone only fetches the app's selected
  /// project's entries, which emptied an all-projects / other-project report.
  Future<void> refresh() async {
    final provider = _projectProvider;
    if (provider == null) return;
    await provider.load();
    await provider.loadEntriesForProject(
      _selectedProjectId == 'all' ? null : _selectedProjectId,
    );
    notifyListeners();
  }
  DateTime? _periodStart() {
    final now = DateTime.now();
    switch (_tabIndex) {
      case 1:
        final quarter = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, quarter, 1);
      case 2:
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(now.year, now.month, 1);
    }
  }
  ReportModel buildLiveReport() {
    final provider = _projectProvider;
    if (provider == null || provider.projects.isEmpty) {
      return ReportModel.empty();
    }
    final List<ProjectModel> targetProjects = _selectedProjectId == 'all'
        ? provider.projects
        : provider.projects.where((p) => p.id == _selectedProjectId).toList();
    if (targetProjects.isEmpty) return ReportModel.empty();
    final periodStart = _periodStart();
    double material = 0;
    double labour = 0;
    double equipment = 0;
    double totalPaid = 0;
    for (final project in targetProjects) {
      final entries = provider.entriesForProject(project.id);
      for (final entry in entries) {
        if (periodStart != null && entry.date.isBefore(periodStart)) continue;
        switch (entry.type) {
          case EntryType.material:
            material += entry.amount;
            break;
          case EntryType.labour:
            labour += entry.amount;
            break;
          case EntryType.equipment:
            equipment += entry.amount;
            break;
        }
        totalPaid += entry.paidAmount;
      }
    }
    double targetMaterial = 0,
        targetLabour = 0,
        targetEquipment = 0,
        targetMisc = 0;
    for (final project in targetProjects) {
      targetMaterial += project.budgetMaterial ?? 0;
      targetLabour += project.budgetLabour ?? 0;
      targetEquipment += project.budgetEquipment ?? 0;
      targetMisc += project.budgetMisc ?? 0;
    }
    final total = material + labour + equipment;
    final totalTarget =
        targetMaterial + targetLabour + targetEquipment + targetMisc;
    final isOver = totalTarget > 0 && total > totalTarget;
    return ReportModel(
      totalCost: total,
      materialCost: material,
      labourCost: labour,
      equipmentCost: equipment,
      miscCost: 0,
      categoryBudget: {
        'Material': targetMaterial,
        'Labour': targetLabour,
        'Equipment': targetEquipment,
      },
      targetMaterial: targetMaterial,
      targetLabour: targetLabour,
      targetEquipment: targetEquipment,
      targetMisc: targetMisc,
      totalPaid: totalPaid,
      totalRemaining: total - totalPaid,
      efficiencyNote: isOver
          ? 'Budget exceeded by ${_fmt(total - totalTarget)}'
          : 'Project is within budget',
    );
  }
  String _fmt(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
