import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:buildtrack_mobile/models/project_model.dart';
import '../models/phase_model.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
const _kEntriesKey = 'buildtrack_entries_v1';
const _kCompletedAtKey = 'buildtrack_completed_at_v1';
const _kActivityDetailsKey = 'buildtrack_activity_details_v1';
class ProjectProvider extends ChangeNotifier {
  List<ProjectModel> _projects = [];
  List<EntryModel> _entries = [];
  List<PhaseModel> _phases = [];
  ProjectModel? _selectedProject;
  String? _selectedFloor;
  String? _selectedPhase;
  String? _selectedPhaseId;
  String? _selectedActivity;
  String? _selectedActivityId;
  bool _isLoading = false;
  bool _projectsLoaded = false;
  String _error = '';
  bool _entriesLoading = false;
  bool get entriesLoading => _entriesLoading;
  List<ProjectModel> get projects => List.unmodifiable(_projects);
  List<EntryModel> get entries => List.unmodifiable(_entries);
  List<PhaseModel> get phases => List.unmodifiable(_phases);
  ProjectModel? get selectedProject => _selectedProject;
  String? get selectedFloor => _selectedFloor;
  String? get selectedPhase => _selectedPhase;
  String? get selectedPhaseId => _selectedPhaseId;
  String? get selectedActivity => _selectedActivity;
  String? get selectedActivityId => _selectedActivityId;
  bool get isLoading => _isLoading;
  bool get projectsLoaded => _projectsLoaded;
  String get error => _error;
  bool get hasProjects => _projects.isNotEmpty;
  int get projectCount => _projects.length;
  Map<String, double> get materialStock {
    if (_selectedProject == null) return {};
    final Map<String, double> stockMap = {};
    final materialEntries = _entries.where(
      (e) =>
          e.projectId == _selectedProject!.id && e.type == EntryType.material,
    );
    for (final entry in materialEntries) {
      final brand = (entry.brand == null || entry.brand!.isEmpty)
          ? 'Unknown'
          : entry.brand!;
      stockMap[brand] = (stockMap[brand] ?? 0.0) + entry.amount;
    }
    return stockMap;
  }
  List<EntryModel> entriesForProject(String projectId) =>
      _entries.where((e) => e.projectId.trim() == projectId.trim()).toList();
  List<EntryModel> entriesForProjectByUser(String projectId, String userId) {
    final all = entriesForProject(projectId);
    if (userId.isEmpty) return all;
    final filtered = all.where((e) => e.createdBy == userId).toList();
    return filtered.isNotEmpty ? filtered : all;
  }
  double totalSpentForProject(String projectId) =>
      entriesForProject(projectId).fold(0.0, (sum, e) => sum + e.amount);
  double getProjectSqftCost(ProjectModel project) {
    final area = double.tryParse(project.landArea ?? '0') ?? 0;
    if (area <= 0) return 0;
    return project.spentAmount / area;
  }
  bool isProjectOverBudget(ProjectModel project) =>
      project.spentAmount > project.totalBudget;
  double budgetExceededAmount(ProjectModel project) {
    if (!isProjectOverBudget(project)) return 0;
    return project.spentAmount - project.totalBudget;
  }
  double budgetRemainingAmount(ProjectModel project) {
    final remain = project.totalBudget - project.spentAmount;
    return remain < 0 ? 0 : remain;
  }
  Future<Map<String, DateTime>> _loadPersistedCompletedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCompletedAtKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final result = <String, DateTime>{};
      decoded.forEach((key, value) {
        if (value != null) {
          final dt = DateTime.tryParse(value.toString());
          if (dt != null) result[key] = dt;
        }
      });
      return result;
    } catch (e) {
      dev.log('_loadPersistedCompletedAt error: $e');
      return {};
    }
  }
  Future<void> _saveCompletedAt(
    String projectId,
    String activityId,
    DateTime date,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCompletedAtKey);
      final Map<String, dynamic> existing = raw != null && raw.isNotEmpty
          ? json.decode(raw)
          : {};
      existing['$projectId|$activityId'] = date.toIso8601String();
      await prefs.setString(_kCompletedAtKey, json.encode(existing));
    } catch (e) {
      dev.log('_saveCompletedAt error: $e');
    }
  }
  Future<void> _saveActivityDetails(
    String projectId,
    String activityId, {
    String? notes,
    String? photo,
    List<String>? photos,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kActivityDetailsKey);
      final Map<String, dynamic> existing = raw != null && raw.isNotEmpty
          ? json.decode(raw)
          : {};
      existing['$projectId|$activityId'] = {
        'notes': ?notes,
        'photo': photo,
        'photos': photos,
      };
      await prefs.setString(_kActivityDetailsKey, json.encode(existing));
    } catch (e) {
      dev.log('_saveActivityDetails error: $e');
    }
  }
  Future<Map<String, Map<String, dynamic>>>
  _loadPersistedActivityDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kActivityDetailsKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final result = <String, Map<String, dynamic>>{};
      decoded.forEach((key, value) {
        if (value is Map) {
          result[key] = Map<String, dynamic>.from(value);
        }
      });
      return result;
    } catch (e) {
      dev.log('_loadPersistedActivityDetails error: $e');
      return {};
    }
  }
  Future<void> _backfillCompletedActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCompletedAtKey);
      final Map<String, dynamic> existing = raw != null && raw.isNotEmpty
          ? json.decode(raw)
          : {};
      bool changed = false;
      for (final p in _projects) {
        for (final phase in p.selectedPhases ?? <ProjectPhase>[]) {
          for (final act in phase.activities) {
            final key = '${p.id}|${act.id}';
            if (act.completed && !existing.containsKey(key)) {
              existing[key] = DateTime(2000).toIso8601String();
              changed = true;
            }
          }
        }
      }
      if (changed) {
        await prefs.setString(_kCompletedAtKey, json.encode(existing));
      }
    } catch (e) {
      dev.log('_backfillCompletedActivities error: $e');
    }
  }
  List<ProjectModel> _filterForCurrentUser(List<ProjectModel> all) {
    if (UserSession.isAdmin) return all;
    final assignedIds = UserSession.projectIds.map((id) => id.trim()).toSet();
    if (assignedIds.isEmpty) return [];
    return all.where((p) => assignedIds.contains(p.id.trim())).toList();
  }
  Future<List<EntryModel>> _fetchEntriesForProject(String? projectId) async {
    final apiMaterials = await ApiService.fetchMaterials(projectId: projectId);
    debugPrint(
      'fetchMaterials(project=$projectId): ${apiMaterials.length} items',
    );
    final filtered = apiMaterials.where((json) {
      final rawType = (json['type'] ?? '').toString().toLowerCase();
      if (rawType == 'income' || rawType == 'revenue') return false;
      final approvalStatus = (json['approvalStatus'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (approvalStatus == 'rejected') return false;
      return true;
    }).toList();
    return filtered.map<EntryModel>((json) {
      EntryType parsedType = EntryType.material;
      final rawType = (json['type'] ?? '').toString().toLowerCase();
      if (rawType == 'labour' || rawType == 'wages') {
        parsedType = EntryType.labour;
      } else if (rawType == 'equipment' || rawType == 'expense') {
        parsedType = EntryType.equipment;
      }
      String entryProjectId = '';
      if (json['project'] is Map) {
        entryProjectId = json['project']['_id']?.toString() ?? '';
      } else if (json['project'] != null) {
        entryProjectId = json['project'].toString();
      }
      if (entryProjectId.isEmpty && json['projectId'] != null) {
        if (json['projectId'] is Map) {
          entryProjectId = json['projectId']['_id']?.toString() ?? '';
        } else {
          entryProjectId = json['projectId'].toString();
        }
      }
      entryProjectId = entryProjectId.trim();
      if (entryProjectId.isEmpty) entryProjectId = 'p1';
      double amount = 0;
      final v = json['amount'];
      if (v != null && v is num && v > 0) {
        amount = v.toDouble();
      } else {
        final qty = json['quantity'];
        final rate = json['rate'];
        if (qty is num && rate is num && qty > 0 && rate > 0) {
          amount = (qty * rate).toDouble();
        }
      }
      final parsedPaidAmount = (json['paidAmount'] as num?)?.toDouble() ?? 0.0;
      final parsedPaymentHistory = json['paymentHistory'] != null
          ? List<Map<String, dynamic>>.from(
              (json['paymentHistory'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : <Map<String, dynamic>>[];
      String? createdBy;
      final createdByRaw =
          json['createdBy'] ??
          json['addedBy'] ??
          json['submittedBy'] ??
          json['userId'] ??
          json['user'];
      if (createdByRaw is Map) {
        createdBy =
            createdByRaw['_id']?.toString() ?? createdByRaw['id']?.toString();
      } else if (createdByRaw != null) {
        createdBy = createdByRaw.toString();
      }
      final approvalStatusRaw = json['approvalStatus']?.toString() ?? 'Pending';
      String paymentStatusRaw = json['paymentStatus']?.toString() ?? 'Pending';
      if (amount > 0) {
        if (parsedPaidAmount >= amount) {
          paymentStatusRaw = 'Fully Paid';
        } else if (parsedPaidAmount > 0) {
          paymentStatusRaw = 'Partial';
        }
      }
      final paymentDateRaw = json['paymentDate'] != null
          ? DateTime.tryParse(json['paymentDate'].toString())
          : null;
      return EntryModel(
        id:
            json['_id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        projectId: entryProjectId,
        type: parsedType,
        amount: amount,
        date: json['date'] != null
            ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        description:
            json['materialName'] ??
            json['title'] ??
            json['description'] ??
            json['name'] ??
            'Entry',
        brand: json['materialName'] ?? json['brand'] ?? json['name'],
        ratePerUnit: (json['rate'] is num)
            ? (json['rate'] as num).toDouble()
            : 0,
        floor: json['floor']?.toString(),
        phase: json['phase']?.toString(),
        phaseId: json['phaseId']?.toString(),
        activity: json['activity']?.toString(),
        activityId: json['activityId']?.toString(),
        unit: json['unit']?.toString(),
        createdBy: createdBy,
        approvalStatus: approvalStatusRaw,
        paymentStatus: paymentStatusRaw,
        paymentDate: paymentDateRaw,
        paidAmount: parsedPaidAmount,
        paymentHistory: parsedPaymentHistory,
      );
    }).toList();
  }
  Future<void> loadEntriesForProject(String? projectId) async {
    _entriesLoading = true;
    notifyListeners();
    try {
      final targetId = (projectId == 'all') ? null : projectId;
      final freshEntries = await _fetchEntriesForProject(targetId);
      _entries = freshEntries;
      await _persistEntries();
    } catch (e, st) {
      dev.log('loadEntriesForProject error: $e', stackTrace: st);
    } finally {
      _entriesLoading = false;
      notifyListeners();
    }
  }
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final phaseRaw = prefs.getString('phases');
    if (phaseRaw != null && phaseRaw.isNotEmpty) {
      try {
        _phases = PhaseModel.decodeList(phaseRaw);
      } catch (_) {
        _phases = [];
      }
    }
    if (_phases.isEmpty || _phases.length < 11) {
      _phases =
          [
                'Pre-Construction',
                'Site Preparation',
                'Foundation',
                'Plinth',
                'Superstructure',
                'Masonry',
                'MEP',
                'Plastering',
                'Finishing',
                'Fixtures',
                'Handover',
              ]
              .asMap()
              .entries
              .map(
                (e) => PhaseModel(
                  id: e.value.toLowerCase().replaceAll(' ', '_'),
                  name: e.value,
                  order: e.key,
                ),
              )
              .toList();
      _savePhases();
    }
    final cachedProjectsRaw = prefs.getString('buildtrack_projects_v1');
    final cachedEntriesRaw = prefs.getString(_kEntriesKey);
    bool loadedFromCache = false;
    if (cachedProjectsRaw != null && cachedProjectsRaw.isNotEmpty) {
      try {
        final List<ProjectModel> decodedProjects = ProjectModel.decodeList(
          cachedProjectsRaw,
        );
        _projects = _filterForCurrentUser(decodedProjects);
        loadedFromCache = true;
      } catch (e) {
        dev.log('Decoding cached projects failed: $e');
      }
    }
    if (cachedEntriesRaw != null && cachedEntriesRaw.isNotEmpty) {
      try {
        _entries = EntryModel.decodeList(cachedEntriesRaw);
      } catch (e) {
        dev.log('Decoding cached entries failed: $e');
      }
    }
    final String? cachedProjId = prefs.getString(
      'buildtrack_selected_project_id',
    );
    final String? initialProjId =
        cachedProjId ??
        (UserSession.projectId.isNotEmpty ? UserSession.projectId : null);
    if (loadedFromCache) {
      if (initialProjId != null) {
        final existingIdx = _projects.indexWhere(
          (p) => p.id.trim() == initialProjId.trim(),
        );
        if (existingIdx != -1) {
          _selectedProject = _projects[existingIdx];
        } else if (_projects.isNotEmpty) {
          _selectedProject = _projects.first;
        }
      } else if (_projects.isNotEmpty) {
        _selectedProject = _projects.first;
      }
      if (_selectedProject != null) {
        UserSession.projectId = _selectedProject!.id;
        final cachedProjId = prefs.getString('buildtrack_selected_project_id');
        if (cachedProjId == _selectedProject?.id) {
          _selectedFloor = prefs.getString('buildtrack_selected_floor');
          _selectedPhase = prefs.getString('buildtrack_selected_phase');
          _selectedPhaseId = prefs.getString('buildtrack_selected_phase_id');
          _selectedActivity = prefs.getString('buildtrack_selected_activity');
          _selectedActivityId = prefs.getString(
            'buildtrack_selected_activity_id',
          );
        }
      }
      _isLoading = false;
      notifyListeners();
      _fetchNetworkData(initialProjId);
      return;
    }
    _setLoading(true);
    await _fetchNetworkData(initialProjId);
    _setLoading(false);
  }
  Future<void> _fetchNetworkData(String? initialProjId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? targetProjId =
          initialProjId ??
          prefs.getString('buildtrack_selected_project_id') ??
          (UserSession.projectId.isNotEmpty ? UserSession.projectId : null);
      final Map<String, DateTime> persistedDates =
          await _loadPersistedCompletedAt();
      final Map<String, Map<String, dynamic>> persistedDetails =
          await _loadPersistedActivityDetails();
      final Map<String, Map<String, DateTime>> prevCompletedAt = {};
      persistedDates.forEach((key, date) {
        final parts = key.split('|');
        if (parts.length == 2) {
          prevCompletedAt.putIfAbsent(parts[0], () => {})[parts[1]] = date;
        }
      });
      for (final p in _projects) {
        for (final phase in p.selectedPhases ?? <ProjectPhase>[]) {
          for (final act in phase.activities) {
            if (act.completed && act.completedAt != null) {
              prevCompletedAt.putIfAbsent(p.id, () => {})[act.id] =
                  act.completedAt!;
            } else if (act.completed && act.completedAt == null) {
              prevCompletedAt
                  .putIfAbsent(p.id, () => {})
                  .putIfAbsent(act.id, () => DateTime(2000));
            }
          }
        }
      }
      final results = await Future.wait([
        ApiService.fetchProjects(),
        if (targetProjId != null)
          _fetchEntriesForProject(targetProjId)
        else
          Future.value(<EntryModel>[]),
      ]);
      final fetched = results[0] as List<ProjectModel>;
      final List<EntryModel> freshEntries = results[1] as List<EntryModel>;
      _projects = _filterForCurrentUser(fetched);
      _projects = _projects.map((p) {
        final actDates = prevCompletedAt[p.id];
        final List<ProjectPhase>
        mergedPhases = (p.selectedPhases ?? <ProjectPhase>[]).map((phase) {
          final mergedActivities = phase.activities.map((act) {
            var updatedAct = act;
            if (actDates != null) {
              final savedDate = actDates[act.id];
              if (savedDate != null) {
                if (updatedAct.completedAt == null || !updatedAct.completed) {
                  updatedAct = updatedAct.copyWith(
                    completed: true,
                    completedAt: savedDate == DateTime(2000) ? null : savedDate,
                  );
                }
              }
            }
            final detailsKey = '${p.id}|${act.id}';
            final savedDetails = persistedDetails[detailsKey];
            if (savedDetails != null) {
              updatedAct = updatedAct.copyWith(
                notes: updatedAct.notes ?? savedDetails['notes']?.toString(),
                photo: updatedAct.photo ?? savedDetails['photo']?.toString(),
                photos:
                    updatedAct.photos ??
                    (savedDetails['photos'] as List?)
                        ?.map((x) => x.toString())
                        .toList(),
              );
            }
            return updatedAct;
          }).toList();
          return phase.copyWith(activities: mergedActivities);
        }).toList();
        final floors = (p.floors == null || p.floors!.isEmpty)
            ? ['Ground']
            : p.floors!;
        final effectivePhases = mergedPhases;
        final totalActs = effectivePhases.fold<int>(
          0,
          (s, ph) => s + ph.totalCount,
        );
        final doneActs = effectivePhases.fold<int>(
          0,
          (s, ph) => s + ph.completedCount,
        );
        final computedProgress = totalActs > 0
            ? doneActs / totalActs
            : p.progress;
        final completedKeys = effectivePhases
            .expand((ph) => ph.activities)
            .where((a) => a.completed)
            .map((a) => a.id)
            .toList();
        return p.copyWith(
          selectedPhases: effectivePhases,
          completedActivityKeys: completedKeys.isNotEmpty
              ? completedKeys
              : p.completedActivityKeys,
          floors: floors,
          progress: computedProgress,
        );
      }).toList();
      debugPrint('Projects loaded: ${_projects.length}');
      for (final p in _projects) {
        debugPrint(
          '  Project: "${p.name}" id=${p.id} floors=${p.floors} spentAmount=${p.spentAmount}',
        );
      }
      await _persistProjects();
      final double? prevProgress = _selectedProject?.progress;
      if (_selectedProject != null) {
        final existingIdx = _projects.indexWhere(
          (p) => p.id.trim() == _selectedProject!.id.trim(),
        );
        if (existingIdx != -1) {
          _selectedProject = _projects[existingIdx];
        } else if (_projects.isNotEmpty) {
          _selectedProject = _projects.first;
        } else {
          _selectedProject = null;
        }
      } else {
        if (targetProjId != null) {
          final existingIdx = _projects.indexWhere(
            (p) => p.id.trim() == targetProjId.trim(),
          );
          if (existingIdx != -1) {
            _selectedProject = _projects[existingIdx];
          } else if (_projects.isNotEmpty) {
            _selectedProject = _projects.first;
          } else {
            _selectedProject = null;
          }
        } else if (_projects.isNotEmpty) {
          _selectedProject = _projects.first;
        }
      }
      if (prevProgress != null && _selectedProject != null) {
        _selectedProject = _selectedProject!.copyWith(progress: prevProgress);
      }
      if (_selectedProject != null) {
        UserSession.projectId = _selectedProject!.id;
      }
      if (_selectedProject != null) {
        if (_selectedProject!.id == targetProjId) {
          _entries = freshEntries;
        } else {
          _entries = await _fetchEntriesForProject(_selectedProject!.id);
        }
      } else {
        _entries = [];
      }
      _projects = _projects.map((p) {
        final localTotal = totalSpentForProject(p.id);
        if (localTotal > 0 && localTotal > p.spentAmount) {
          return p.copyWith(spentAmount: localTotal);
        }
        return p;
      }).toList();
      final cachedProjId = prefs.getString('buildtrack_selected_project_id');
      if (cachedProjId == _selectedProject?.id) {
        _selectedFloor = prefs.getString('buildtrack_selected_floor');
        _selectedPhase = prefs.getString('buildtrack_selected_phase');
        _selectedPhaseId = prefs.getString('buildtrack_selected_phase_id');
        _selectedActivity = prefs.getString('buildtrack_selected_activity');
        _selectedActivityId = prefs.getString(
          'buildtrack_selected_activity_id',
        );
      } else {
        _selectedFloor = null;
        _selectedPhase = null;
        _selectedPhaseId = null;
        _selectedActivity = null;
        _selectedActivityId = null;
      }
      await _backfillCompletedActivities();
      await _persistEntries();
      _projectsLoaded = true;
      _error = '';
      notifyListeners();
    } catch (e, st) {
      _error = 'Failed to load background network: $e';
      dev.log(
        'ProjectProvider._fetchNetworkData error',
        error: e,
        stackTrace: st,
      );
    }
  }
  Future<ProjectModel?> refreshProject(String projectId) async {
    try {
      final fresh = await ApiService.fetchProjectById(projectId);
      if (fresh == null) return null;
      final idx = _projects.indexWhere(
        (p) => p.id.trim() == projectId.trim(),
      );
      if (idx != -1) {
        _projects[idx] = fresh;
      } else {
        _projects.add(fresh);
      }
      if (_selectedProject?.id.trim() == projectId.trim()) {
        _selectedProject = fresh;
      }
      await _persistProjects();
      UserSession.projectId = fresh.id;
      notifyListeners();
      return fresh;
    } catch (e) {
      dev.log('refreshProject error: $e');
      return null;
    }
  }
  Future<void> fetchProjects() async {
    _setLoading(true);
    try {
      final fetched = await ApiService.fetchProjects();
      _projects = _filterForCurrentUser(fetched);
      _projects = _projects.map((p) {
        final floors = p.floors;
        if (floors == null || floors.isEmpty) {
          return p.copyWith(floors: ['Ground']);
        }
        return p;
      }).toList();
      if (_projects.isNotEmpty && _selectedProject == null) {
        _selectedProject = _projects.first;
      }
      if (_selectedProject != null) {
        UserSession.projectId = _selectedProject!.id;
      }
      _projectsLoaded = true;
      _error = '';
    } catch (e) {
      _error = 'Failed to fetch projects: $e';
      dev.log('fetchProjects error: $e');
    } finally {
      _setLoading(false);
    }
  }
  Future<void> addProject(
    ProjectModel project, {
    String? clientName,
    String? projectType,
    DateTime? expectedEndDate,
    List<String>? floors,
  }) async {
    final finalFloors = (floors == null || floors.isEmpty)
        ? (project.floors == null || project.floors!.isEmpty
              ? ['Ground']
              : project.floors!)
        : floors;
    final updatedProject = project.copyWith(
      clientName: clientName,
      projectType: projectType,
      expectedEndDate: expectedEndDate,
      floors: finalFloors,
    );
    final saved = await ApiService.addProject(updatedProject.toJson());
    if (saved == null) {
      dev.log('addProject failed');
      throw Exception('Failed to save project');
    }
    _projects.add(saved);
    _selectedProject = saved;
    UserSession.projectId = saved.id;
    notifyListeners();
    unawaited(loadEntriesForProject(saved.id));
  }
  Future<void> updateProject(ProjectModel updated) async {
    _setLoading(true);
    try {
      final response = await ApiService.put(
        '/projects/${updated.id}',
        updated.toJson(),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final Map<String, dynamic> projectJson = 
            (decoded is Map && decoded.containsKey('project'))
                ? decoded['project'] as Map<String, dynamic>
                : decoded as Map<String, dynamic>;
        final serverProject = ProjectModel.fromJson(projectJson);
        final idx = _projects.indexWhere((p) => p.id == serverProject.id);
        if (idx != -1) _projects[idx] = serverProject;
        if (_selectedProject?.id == serverProject.id) {
          _selectedProject = serverProject;
          UserSession.projectId = serverProject.id;
        }
        _error = '';
      } else {
        _error = 'Failed to update project: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Update error: $e';
      dev.log('updateProject error: $e');
    } finally {
      _setLoading(false);
    }
  }
  Future<void> _saveContextPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selectedProject != null) {
        await prefs.setString(
          'buildtrack_selected_project_id',
          _selectedProject!.id,
        );
      } else {
        await prefs.remove('buildtrack_selected_project_id');
      }
      if (_selectedFloor != null) {
        await prefs.setString('buildtrack_selected_floor', _selectedFloor!);
      } else {
        await prefs.remove('buildtrack_selected_floor');
      }
      if (_selectedPhase != null) {
        await prefs.setString('buildtrack_selected_phase', _selectedPhase!);
      } else {
        await prefs.remove('buildtrack_selected_phase');
      }
      if (_selectedPhaseId != null) {
        await prefs.setString(
          'buildtrack_selected_phase_id',
          _selectedPhaseId!,
        );
      } else {
        await prefs.remove('buildtrack_selected_phase_id');
      }
      if (_selectedActivity != null) {
        await prefs.setString(
          'buildtrack_selected_activity',
          _selectedActivity!,
        );
      } else {
        await prefs.remove('buildtrack_selected_activity');
      }
      if (_selectedActivityId != null) {
        await prefs.setString(
          'buildtrack_selected_activity_id',
          _selectedActivityId!,
        );
      } else {
        await prefs.remove('buildtrack_selected_activity_id');
      }
    } catch (e) {
      dev.log('_saveContextPrefs error: $e');
    }
  }
  void selectProject(ProjectModel project) {
    _selectedProject = project;
    UserSession.projectId = project.id;
    _selectedFloor = null;
    _selectedPhase = null;
    _selectedPhaseId = null;
    _selectedActivity = null;
    _selectedActivityId = null;
    _saveContextPrefs();
    notifyListeners();
    unawaited(loadEntriesForProject(project.id));
  }
  void selectFloor(String? floor) {
    _selectedFloor = floor;
    _selectedPhase = null;
    _selectedPhaseId = null;
    _selectedActivity = null;
    _selectedActivityId = null;
    _saveContextPrefs();
    notifyListeners();
  }
  void selectPhase(String? phase, String? phaseId) {
    _selectedPhase = phase;
    _selectedPhaseId = phaseId;
    _selectedActivity = null;
    _selectedActivityId = null;
    _saveContextPrefs();
    notifyListeners();
  }
  void selectActivity(String? activity, [String? activityId]) {
    _selectedActivity = activity;
    _selectedActivityId = activityId;
    _saveContextPrefs();
    notifyListeners();
  }
  Future<bool> updateProjectProgress(String id, double progress) async {
    debugPrint('[DEBUG] updateProjectProgress: id=$id, progress=$progress');
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx == -1) {
      debugPrint(
        '[DEBUG] updateProjectProgress: project not found in list (idx == -1)',
      );
      return false;
    }
    _projects[idx] = _projects[idx].copyWith(
      progress: progress.clamp(0.0, 1.0),
    );
    if (_selectedProject?.id == id) _selectedProject = _projects[idx];
    try {
      debugPrint(
        '[DEBUG] updateProjectProgress: sending PUT to /projects/$id...',
      );
      final response = await ApiService.put(
        '/projects/$id',
        _projects[idx].toJson(),
      );
      debugPrint(
        '[DEBUG] updateProjectProgress: PUT response status: ${response.statusCode}',
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[DEBUG] updateProjectProgress PERSISTENCE ERROR: $e');
      return false;
    }
  }
  Future<bool> toggleActivityCompletion(
    String projectId,
    String activityId, {
    DateTime? completedAt,
    String? notes,
    String? photo,
    List<String>? photos,
    double? manualProgress,
  }) async {
    debugPrint(
      '[DEBUG] toggleActivityCompletion: projectId=$projectId, activityId=$activityId, notes=${notes != null}, photo=${photo != null}, photos=${photos != null}',
    );
    final projectIndex = _projects.indexWhere((p) => p.id == projectId);
    if (projectIndex == -1) {
      debugPrint(
        '[DEBUG] toggleActivityCompletion: project not found in list (projectIndex == -1)',
      );
      return false;
    }
    final project = _projects[projectIndex];
    final phases = List<ProjectPhase>.from(project.selectedPhases ?? []);
    bool found = false;
    DateTime? stampedDate;
    for (var p = 0; p < phases.length; p++) {
      final phase = phases[p];
      final activities = List<ProjectActivity>.from(phase.activities);
      final aIndex = activities.indexWhere((a) => a.id == activityId);
      if (aIndex != -1) {
        final current = activities[aIndex];
        stampedDate = completedAt ?? current.completedAt ?? DateTime.now();
        final shouldClear = (photos != null && photos.isEmpty);
        activities[aIndex] = current.copyWith(
          completed: true,
          completedAt: stampedDate,
          notes: notes ?? current.notes,
          photo: shouldClear
              ? null
              : ((photos != null && photos.isNotEmpty)
                    ? photos.first
                    : (photo ?? current.photo)),
          photos: shouldClear ? [] : (photos ?? current.photos),
          clearPhoto: shouldClear,
          clearPhotos: shouldClear,
        );
        phases[p] = phase.copyWith(activities: activities);
        found = true;
        break;
      }
    }
    if (!found) {
      debugPrint(
        '[DEBUG] toggleActivityCompletion: activity $activityId not found in phases',
      );
      return false;
    }
    final total = phases.fold<int>(0, (sum, p) => sum + p.totalCount);
    final done = phases.fold<int>(0, (sum, p) => sum + p.completedCount);
    final completedKeys = phases
        .expand((p) => p.activities)
        .where((a) => a.completed)
        .map((a) => a.id)
        .toList();
    final updated = project.copyWith(
      selectedPhases: phases,
      completedActivityKeys: completedKeys,
      progress:
          manualProgress ?? (total == 0 ? project.progress : done / total),
    );
    _projects[projectIndex] = updated;
    if (_selectedProject?.id == projectId) _selectedProject = updated;
    notifyListeners();
    if (stampedDate != null) {
      await _saveCompletedAt(projectId, activityId, stampedDate);
    }
    if (notes != null || photo != null || photos != null) {
      final firstPhoto = (photos != null && photos.isNotEmpty)
          ? photos.first
          : photo;
      await _saveActivityDetails(
        projectId,
        activityId,
        notes: notes,
        photo: firstPhoto,
        photos: photos,
      );
    }
    try {
      debugPrint(
        '[DEBUG] toggleActivityCompletion: sending PUT to /projects/$projectId...',
      );
      final response = await ApiService.put(
        '/projects/$projectId',
        updated.toJson(),
      );
      debugPrint(
        '[DEBUG] toggleActivityCompletion: PUT response status: ${response.statusCode}',
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          try {
            final data = jsonDecode(response.body);
            if (data['project'] != null) {
              final newProject = ProjectModel.fromJson(
                data['project'] as Map<String, dynamic>,
              );
              _projects[projectIndex] = newProject;
              if (_selectedProject?.id == projectId) {
                _selectedProject = newProject;
              }
              notifyListeners();
            }
          } catch (e) {
            dev.log('[DEBUG] toggleActivityCompletion parse error: $e');
          }
        }
        await _persistProjects();
        return true;
      } else {
        _projects[projectIndex] = project;
        if (_selectedProject?.id == projectId) _selectedProject = project;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[DEBUG] toggleActivityCompletion PERSISTENCE ERROR: $e');
      _projects[projectIndex] = project;
      if (_selectedProject?.id == projectId) _selectedProject = project;
      notifyListeners();
      return false;
    }
  }
  Future<bool> markActivityComplete(
    String projectId,
    String activityId,
    DateTime completionDate,
  ) async {
    return await toggleActivityCompletion(
      projectId,
      activityId,
      completedAt: completionDate,
    );
  }
  Future<bool> updateActivityBudget(
    String projectId,
    String activityId, {
    required double budgetMaterial,
    required double budgetLabour,
    required double budgetEquipment,
  }) async {
    dev.log(
      '[DEBUG] updateActivityBudget: projectId=$projectId, activityId=$activityId',
    );
    final projectIndex = _projects.indexWhere((p) => p.id == projectId);
    if (projectIndex == -1) {
      dev.log('[DEBUG] updateActivityBudget: project not found in list');
      return false;
    }
    final project = _projects[projectIndex];
    final phases = List<ProjectPhase>.from(project.selectedPhases ?? []);
    bool found = false;
    for (var p = 0; p < phases.length; p++) {
      final phase = phases[p];
      final activities = List<ProjectActivity>.from(phase.activities);
      final aIndex = activities.indexWhere((a) => a.id == activityId);
      if (aIndex != -1) {
        final current = activities[aIndex];
        activities[aIndex] = current.copyWith(
          budgetMaterial: budgetMaterial,
          budgetLabour: budgetLabour,
          budgetEquipment: budgetEquipment,
        );
        phases[p] = phase.copyWith(activities: activities);
        found = true;
        break;
      }
    }
    if (!found) {
      dev.log(
        '[DEBUG] updateActivityBudget: activity $activityId not found in phases',
      );
      return false;
    }
    final updated = project.copyWith(selectedPhases: phases);
    _projects[projectIndex] = updated;
    if (_selectedProject?.id == projectId) _selectedProject = updated;
    notifyListeners();
    try {
      dev.log(
        '[DEBUG] updateActivityBudget: sending PUT to /projects/$projectId...',
      );
      final response = await ApiService.put(
        '/projects/$projectId',
        updated.toJson(),
      );
      dev.log(
        '[DEBUG] updateActivityBudget: PUT response status: ${response.statusCode}',
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          try {
            final data = jsonDecode(response.body);
            if (data['project'] != null) {
              final newProject = ProjectModel.fromJson(
                data['project'] as Map<String, dynamic>,
              );
              _projects[projectIndex] = newProject;
              if (_selectedProject?.id == projectId) {
                _selectedProject = newProject;
              }
              notifyListeners();
            }
          } catch (e) {
            dev.log('[DEBUG] updateActivityBudget parse error: $e');
          }
        }
        return true;
      } else {
        _projects[projectIndex] = project;
        if (_selectedProject?.id == projectId) _selectedProject = project;
        notifyListeners();
        return false;
      }
    } catch (e) {
      dev.log('[DEBUG] updateActivityBudget PERSISTENCE ERROR: $e');
      _projects[projectIndex] = project;
      if (_selectedProject?.id == projectId) _selectedProject = project;
      notifyListeners();
      return false;
    }
  }
  Future<void> addEntry(
    EntryModel entry, {
    String? brand,
    double? ratePerUnit,
    String? floor,
    String? phase,
  }) async {
    String rawType = 'Materials';
    if (entry.type == EntryType.labour) rawType = 'Wages';
    if (entry.type == EntryType.equipment) rawType = 'Expense';
    final payload = {
      'title': entry.description.isNotEmpty ? entry.description : 'New Entry',
      'type': rawType,
      'project': entry.projectId,
      'category': brand ?? entry.brand ?? entry.description,
      'unit': entry.unit ?? 'unit',
      'quantity': entry.amount,
      'rate': ratePerUnit ?? entry.ratePerUnit ?? 1,
      'amount': entry.amount * (ratePerUnit ?? entry.ratePerUnit ?? 1),
      'paymentStatus': 'Pending',
      'paymentMode': 'Cash',
      'paidAmount': 0,
    };
    final success = await ApiService.addMaterial(payload);
    if (!success) {
      dev.log('Failed to save entry to backend.');
      return;
    }
    final updatedEntry = EntryModel(
      id: entry.id,
      projectId: entry.projectId,
      type: entry.type,
      amount: 0,
      date: entry.date,
      description: entry.description,
      brand: brand ?? entry.brand,
      ratePerUnit: ratePerUnit ?? entry.ratePerUnit,
      floor: floor ?? entry.floor,
      phase: phase ?? entry.phase,
      phaseId: entry.phaseId,
      activity: entry.activity,
      activityId: entry.activityId,
      createdBy: UserSession.userId,
      approvalStatus: 'Pending',
      paymentStatus: 'Pending',
      paymentDate: null,
    );
    _entries.add(updatedEntry);
    await _persistEntries();
    notifyListeners();
  }
  Future<void> _persistEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEntriesKey, EntryModel.encodeList(_entries));
  }
  Future<void> _persistProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'buildtrack_projects_v1',
        ProjectModel.encodeList(_projects),
      );
    } catch (e) {
      dev.log('Persisting projects error: $e');
    }
  }
  void _savePhases() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phases', PhaseModel.encodeList(_phases));
  }
  void addPhase(String name) {
    _phases.add(
      PhaseModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        order: _phases.length,
      ),
    );
    _savePhases();
    notifyListeners();
  }
  void renamePhase(String id, String newName) {
    final index = _phases.indexWhere((p) => p.id == id);
    if (index != -1) {
      _phases[index] = PhaseModel(
        id: _phases[index].id,
        name: newName,
        order: _phases[index].order,
      );
      _savePhases();
      notifyListeners();
    }
  }
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  void clear() {
    _projects = [];
    _entries = [];
    _phases = [];
    _selectedProject = null;
    _isLoading = false;
    _projectsLoaded = false;
    _error = '';
    notifyListeners();
  }
}
