import 'dart:convert';
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
enum ProjectStage {
  preConstruction,
  sitePreparation,
  foundationPlinthWork,
  floorConstruction,
  finishingWork,
  externalWorks,
  materialMaster,
  labourMaster,
  equipmentMaster,
}
enum EntryType { material, labour, equipment }
extension ProjectStageX on ProjectStage {
  String get label {
    switch (this) {
      case ProjectStage.preConstruction:
        return 'Pre-Construction';
      case ProjectStage.sitePreparation:
        return 'Site Preparation';
      case ProjectStage.foundationPlinthWork:
        return 'Foundation & Plinth Work';
      case ProjectStage.floorConstruction:
        return 'Floor Construction';
      case ProjectStage.finishingWork:
        return 'Finishing Work';
      case ProjectStage.externalWorks:
        return 'External Works';
      case ProjectStage.materialMaster:
        return 'Material';
      case ProjectStage.labourMaster:
        return 'Labour';
      case ProjectStage.equipmentMaster:
        return 'Equipment';
    }
  }
}
extension EntryTypeX on EntryType {
  String get label {
    switch (this) {
      case EntryType.material:
        return 'Material';
      case EntryType.labour:
        return 'Labour';
      case EntryType.equipment:
        return 'Equipment';
    }
  }
}
class EntryModel {
  EntryModel({
    required this.id,
    required this.projectId,
    required this.type,
    required this.amount,
    required this.date,
    this.description = '',
    this.brand,
    this.quantity,
    this.ratePerUnit,
    this.floor,
    this.phase,
    this.phaseId,
    this.activity,
    this.activityId,
    this.unit,
    this.createdBy,
    this.approvalStatus = 'Pending',
    this.paymentStatus = 'Pending',
    this.approvedBy,
    this.approvedAt,
    this.paymentDate,
    this.rejectionReason,
    this.paidAmount = 0.0,
    this.paymentHistory = const [],
  });
  final String id;
  final String projectId;
  final EntryType type;
  double amount;
  final DateTime date;
  final String description;
  final String? brand;
  final double? quantity;
  final double? ratePerUnit;
  final String? floor;
  final String? phase;
  final String? phaseId;
  final String? activity;
  final String? activityId;
  final String? unit;
  final String? createdBy;
  final String approvalStatus;
  final String paymentStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? paymentDate;
  final String? rejectionReason;
  final double paidAmount;
  final List<Map<String, dynamic>> paymentHistory;
  double get remainingAmount =>
      (amount - paidAmount).clamp(0.0, double.infinity);
  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'type': type.name,
    'amount': amount,
    'date': date.toIso8601String(),
    'description': description,
    'brand': brand,
    'ratePerUnit': ratePerUnit,
    'floor': floor,
    'phase': phase,
    'phaseId': phaseId,
    'activity': activity,
    'activityId': activityId,
    'unit': unit,
    'createdBy': createdBy,
    'approvalStatus': approvalStatus,
    'paymentStatus': paymentStatus,
    'approvedBy': approvedBy,
    'approvedAt': approvedAt?.toIso8601String(),
    'paymentDate': paymentDate?.toIso8601String(),
    'rejectionReason': rejectionReason,
    'paidAmount': paidAmount,
    'paymentHistory': paymentHistory,
  };
  factory EntryModel.fromJson(Map<String, dynamic> j) {
    String? createdBy;
    final raw = j['createdBy'];
    if (raw is Map) {
      createdBy = raw['_id']?.toString() ?? raw['id']?.toString();
    } else if (raw != null) {
      createdBy = raw.toString();
    }
    String desc = j['title']?.toString() ?? j['materialName']?.toString() ?? j['description']?.toString() ?? j['name']?.toString() ?? '';
    
    final typeStr = (j['type']?.toString() ?? '').toLowerCase();
    if ((typeStr == 'labour' || typeStr == 'wages') && j['worker'] != null && j['worker'] is Map) {
      final workerName = j['worker']['name']?.toString() ?? '';
      if (workerName.isNotEmpty) {
        desc = workerName + (desc.isNotEmpty ? ' - $desc' : '');
      }
    } else if (j['supplier'] != null) {
      final supplier = j['supplier']?.toString() ?? '';
      if (supplier.isNotEmpty) {
        desc = supplier + (desc.isNotEmpty ? ' - $desc' : '');
      }
    }

    return EntryModel(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      projectId: j['project']?.toString() ?? j['projectId']?.toString() ?? '',
      type: EntryType.values.firstWhere(
        (e) => e.name.toLowerCase() == (j['type']?.toString() ?? '').toLowerCase(),
        orElse: () => EntryType.material,
      ),
      amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(j['date']?.toString() ?? j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      description: desc,
      brand: j['brand']?.toString(),
      quantity: (j['quantity'] as num?)?.toDouble(),
      ratePerUnit: (j['rate'] as num?)?.toDouble() ?? (j['ratePerUnit'] as num?)?.toDouble(),
      floor: j['floor']?.toString(),
      phase: j['phase']?.toString(),
      phaseId: j['phaseId']?.toString(),
      activity: j['activity']?.toString(),
      activityId: j['activityId']?.toString(),
      unit: j['unit']?.toString(),
      createdBy: createdBy,
      approvalStatus: j['approvalStatus']?.toString() ?? 'Pending',
      paymentStatus: (() {
        final rawPaid = (j['paidAmount'] as num?)?.toDouble() ?? 0.0;
        final rawAmt = (j['amount'] as num?)?.toDouble() ?? 0.0;
        if (rawAmt > 0) {
          if (rawPaid >= rawAmt) return 'Fully Paid';
          if (rawPaid > 0) return 'Partial';
        }
        final rawStatus = j['paymentStatus']?.toString();
        if (rawStatus != null && rawStatus.isNotEmpty) return rawStatus;
        return 'Pending';
      })(),
      approvedBy: j['approvedBy'] != null
          ? (j['approvedBy'] is Map
                ? j['approvedBy']['name']?.toString() ??
                      j['approvedBy']['_id']?.toString()
                : j['approvedBy'].toString())
          : null,
      approvedAt: j['approvedAt'] != null
          ? DateTime.tryParse(j['approvedAt'].toString())
          : null,
      paymentDate: j['paymentDate'] != null
          ? DateTime.tryParse(j['paymentDate'].toString())
          : null,
      rejectionReason: j['rejectionReason']?.toString(),
      paidAmount: (j['paidAmount'] as num?)?.toDouble() ?? 0.0,
      paymentHistory: j['paymentHistory'] != null
          ? List<Map<String, dynamic>>.from(
              (j['paymentHistory'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : const [],
    );
  }
  static String encodeList(List<EntryModel> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());
  static List<EntryModel> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => EntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
class ProjectActivity {
  final String id;
  final String name;
  final bool isCustom;
  final bool completed;
  final DateTime? completedAt;
  final String? notes;
  final String? photo;
  final List<String>? photos;
  final double? budgetMaterial;
  final double? budgetLabour;
  final double? budgetEquipment;
  final ActivityBudget? budget;
  final double? qty;
  final String? unit;
  final double? materialRate;
  final double? materialAmount;
  final double? labourRate;
  final double? labourAmount;
  final double? equipmentRate;
  final double? equipmentAmount;
  final double? totalAmount;
  ProjectActivity({
    required this.id,
    required this.name,
    this.isCustom = false,
    this.completed = false,
    this.completedAt,
    this.notes,
    this.photo,
    this.photos,
    this.budgetMaterial,
    this.budgetLabour,
    this.budgetEquipment,
    this.budget,
    this.qty,
    this.unit,
    this.materialRate,
    this.materialAmount,
    this.labourRate,
    this.labourAmount,
    this.equipmentRate,
    this.equipmentAmount,
    this.totalAmount,
  });
  double get budgetTotal =>
      (budgetMaterial ?? 0.0) +
      (budgetLabour ?? 0.0) +
      (budgetEquipment ?? 0.0);
  ProjectActivity copyWith({
    bool? completed,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool clearPhoto = false,
    bool clearPhotos = false,
    String? notes,
    String? photo,
    List<String>? photos,
    double? budgetMaterial,
    double? budgetLabour,
    double? budgetEquipment,
    ActivityBudget? budget,
    double? qty,
    String? unit,
    double? materialRate,
    double? materialAmount,
    double? labourRate,
    double? labourAmount,
    double? equipmentRate,
    double? equipmentAmount,
    double? totalAmount,
  }) {
    return ProjectActivity(
      id: id,
      name: name,
      isCustom: isCustom,
      completed: completed ?? this.completed,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      notes: notes ?? this.notes,
      photo: clearPhoto ? null : (photo ?? this.photo),
      photos: clearPhotos ? null : (photos ?? this.photos),
      budgetMaterial: budgetMaterial ?? this.budgetMaterial,
      budgetLabour: budgetLabour ?? this.budgetLabour,
      budgetEquipment: budgetEquipment ?? this.budgetEquipment,
      budget: budget ?? this.budget,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      materialRate: materialRate ?? this.materialRate,
      materialAmount: materialAmount ?? this.materialAmount,
      labourRate: labourRate ?? this.labourRate,
      labourAmount: labourAmount ?? this.labourAmount,
      equipmentRate: equipmentRate ?? this.equipmentRate,
      equipmentAmount: equipmentAmount ?? this.equipmentAmount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isCustom': isCustom,
    'completed': completed,
    'isCompleted': completed,
    'status': completed ? 'Completed' : 'Pending',
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (notes != null) 'notes': notes,
    'photo': photo,
    'photos': photos,
    'budgetMaterial': budgetMaterial ?? 0.0,
    'budgetLabour': budgetLabour ?? 0.0,
    'budgetEquipment': budgetEquipment ?? 0.0,
    if (qty != null) 'qty': qty,
    if (unit != null) 'unit': unit,
    if (materialRate != null) 'materialRate': materialRate,
    if (materialAmount != null) 'materialAmount': materialAmount,
    if (labourRate != null) 'labourRate': labourRate,
    if (labourAmount != null) 'labourAmount': labourAmount,
    if (equipmentRate != null) 'equipmentRate': equipmentRate,
    if (equipmentAmount != null) 'equipmentAmount': equipmentAmount,
    if (totalAmount != null) 'totalAmount': totalAmount,
  };
  factory ProjectActivity.fromJson(Map<String, dynamic> j) {
    final double mat = (j['budgetMaterial'] as num?)?.toDouble() ?? 0.0;
    final double lab = (j['budgetLabour'] as num?)?.toDouble() ?? 0.0;
    final double equ = (j['budgetEquipment'] as num?)?.toDouble() ?? 0.0;
    
    bool isDone = false;
    final rawComp = j['completed'] ?? j['isCompleted'] ?? j['is_completed'] ?? j['complete'];
    if (rawComp is bool) {
      isDone = rawComp;
    } else if (rawComp is num) {
      isDone = rawComp != 0;
    } else if (rawComp is String) {
      final s = rawComp.toLowerCase().trim();
      isDone = s == 'true' || s == '1' || s == 'completed' || s == 'done' || s == 'yes';
    }
    final rawStatus = (j['status'] ?? '').toString().toLowerCase().trim();
    if (rawStatus == 'completed' || rawStatus == 'done') {
      isDone = true;
    }

    return ProjectActivity(
      id: (j['id'] ?? j['_id'])?.toString() ?? '',
      name: (j['name'] ?? '').toString(),
      isCustom: (j['isCustom'] as bool?) ?? false,
      completed: isDone,
      completedAt: j['completedAt'] != null
          ? DateTime.tryParse(j['completedAt'].toString())
          : null,
      notes: j['notes']?.toString(),
      photo: j['photo']?.toString(),
      photos: j['photos'] != null
          ? List<String>.from(j['photos'] as List)
          : null,
      budgetMaterial: mat,
      budgetLabour: lab,
      budgetEquipment: equ,
      budget: j['budget'] != null
          ? ActivityBudget.fromJson(j['budget'] as Map<String, dynamic>)
          : ActivityBudget.zero(mat, lab, equ),
      qty: (j['qty'] as num?)?.toDouble(),
      unit: j['unit']?.toString(),
      materialRate: (j['materialRate'] as num?)?.toDouble(),
      materialAmount: (j['materialAmount'] as num?)?.toDouble(),
      labourRate: (j['labourRate'] as num?)?.toDouble(),
      labourAmount: (j['labourAmount'] as num?)?.toDouble(),
      equipmentRate: (j['equipmentRate'] as num?)?.toDouble(),
      equipmentAmount: (j['equipmentAmount'] as num?)?.toDouble(),
      totalAmount: (j['totalAmount'] as num?)?.toDouble(),
    );
  }
}
class ActivityBudget {
  final ActivityBudgetCategory material;
  final ActivityBudgetCategory labour;
  final ActivityBudgetCategory equipment;
  final ActivityBudgetCategory total;
  final DateTime? budgetLastCalculatedAt;
  ActivityBudget({
    required this.material,
    required this.labour,
    required this.equipment,
    required this.total,
    this.budgetLastCalculatedAt,
  });
  factory ActivityBudget.fromJson(Map<String, dynamic> j) {
    return ActivityBudget(
      material: ActivityBudgetCategory.fromJson(
        j['material'] as Map<String, dynamic>? ?? {},
      ),
      labour: ActivityBudgetCategory.fromJson(
        j['labour'] as Map<String, dynamic>? ?? {},
      ),
      equipment: ActivityBudgetCategory.fromJson(
        j['equipment'] as Map<String, dynamic>? ?? {},
      ),
      total: ActivityBudgetCategory.fromJson(
        j['total'] as Map<String, dynamic>? ?? {},
      ),
      budgetLastCalculatedAt: j['budgetLastCalculatedAt'] != null
          ? DateTime.tryParse(j['budgetLastCalculatedAt'].toString())
          : null,
    );
  }
  static ActivityBudget zero(
    double budgetMaterial,
    double budgetLabour,
    double budgetEquipment,
  ) {
    final double total = budgetMaterial + budgetLabour + budgetEquipment;
    return ActivityBudget(
      material: ActivityBudgetCategory.zero(budgetMaterial),
      labour: ActivityBudgetCategory.zero(budgetLabour),
      equipment: ActivityBudgetCategory.zero(budgetEquipment),
      total: ActivityBudgetCategory.zero(total),
    );
  }
}
class ActivityBudgetCategory {
  final double allocated;
  final double spent;
  final double remaining;
  final double utilization;
  final double progress;
  ActivityBudgetCategory({
    required this.allocated,
    required this.spent,
    required this.remaining,
    required this.utilization,
    required this.progress,
  });
  factory ActivityBudgetCategory.fromJson(Map<String, dynamic> j) {
    return ActivityBudgetCategory(
      allocated: (j['allocated'] as num?)?.toDouble() ?? 0.0,
      spent: (j['spent'] as num?)?.toDouble() ?? 0.0,
      remaining: (j['remaining'] as num?)?.toDouble() ?? 0.0,
      utilization: (j['utilization'] as num?)?.toDouble() ?? 0.0,
      progress: (j['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }
  factory ActivityBudgetCategory.zero(double allocated) {
    return ActivityBudgetCategory(
      allocated: allocated,
      spent: 0.0,
      remaining: allocated,
      utilization: 0.0,
      progress: 0.0,
    );
  }
}
class ProjectPhase {
  final String id;
  final String phaseName;
  final bool isCustom;
  final bool isExpanded;
  final List<ProjectActivity> activities;
  ProjectPhase({
    required this.id,
    required this.phaseName,
    this.isCustom = false,
    this.isExpanded = false,
    List<ProjectActivity>? activities,
  }) : activities = activities ?? [];
  int get totalCount => activities.length;
  int get completedCount => activities.where((a) => a.completed).length;
  ProjectPhase copyWith({List<ProjectActivity>? activities}) {
    return ProjectPhase(
      id: id,
      phaseName: phaseName,
      isCustom: isCustom,
      isExpanded: isExpanded,
      activities: activities ?? List<ProjectActivity>.from(this.activities),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'phaseName': phaseName,
    'isCustom': isCustom,
    'activities': activities.map((a) => a.toJson()).toList(),
  };
  factory ProjectPhase.fromJson(Map<String, dynamic> j) {
    return ProjectPhase(
      id: (j['id'] ?? j['_id'])?.toString() ?? '',
      phaseName: (j['phaseName'] ?? j['name'] ?? '').toString(),
      isCustom: j['isCustom'] as bool? ?? false,
      activities:
          (j['activities'] as List<dynamic>?)
              ?.map((e) => ProjectActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
class ProjectModel {
  final String id;
  final String name;
  final String city;
  final String sector;
  final ProjectStage stage;
  final double progress;
  final double totalBudget;
  final double spentAmount;
  final double totalIncome;
  final DateTime startDate;
  final String location;
  final String? clientName;
  final String? projectType;
  final DateTime? expectedEndDate;
  final List<String>? floors;
  final List<String>? selectedPhaseNames;
  final List<String>? trackedActivityKeys;
  final List<String>? completedActivityKeys;
  final List<ProjectPhase>? selectedPhases;
  final String? projectCode;
  final String? mapAddress;
  final String? contractorName;
  final String? siteEngineer;
  final String? contactNumber;
  final DateTime? actualEndDate;
  final String? landArea;
  final String? landUnit;
  final int? room1BHK;
  final int? room2BHK;
  final int? room3BHK;
  final int? roomCustom;
  final int? bathWestern;
  final int? bathIndian;
  final int? bathCommon;
  final int? bathAttached;
  final List<String>? selectedFeatures;
  final double? budgetMaterial;
  final double? budgetLabour;
  final double? budgetEquipment;
  final double? budgetMisc;
  final String? projectStatus;
  ProjectModel({
    required this.id,
    required this.name,
    required this.city,
    required this.sector,
    required this.stage,
    required this.progress,
    required this.totalBudget,
    required this.spentAmount,
    this.totalIncome = 0.0,
    required this.startDate,
    required this.location,
    this.clientName,
    this.projectType,
    this.expectedEndDate,
    this.floors,
    this.selectedPhaseNames,
    this.trackedActivityKeys,
    this.completedActivityKeys,
    this.selectedPhases,
    this.projectCode,
    this.mapAddress,
    this.contractorName,
    this.siteEngineer,
    this.contactNumber,
    this.actualEndDate,
    this.landArea,
    this.landUnit,
    this.room1BHK,
    this.room2BHK,
    this.room3BHK,
    this.roomCustom,
    this.bathWestern,
    this.bathIndian,
    this.bathCommon,
    this.bathAttached,
    this.selectedFeatures,
    this.budgetMaterial,
    this.budgetLabour,
    this.budgetEquipment,
    this.budgetMisc,
    this.projectStatus,
  });
  ProjectModel copyWith({
    String? id,
    String? name,
    String? city,
    String? sector,
    ProjectStage? stage,
    double? progress,
    double? totalBudget,
    double? spentAmount,
    double? totalIncome,
    DateTime? startDate,
    String? location,
    String? clientName,
    String? projectType,
    DateTime? expectedEndDate,
    List<String>? floors,
    List<String>? selectedPhaseNames,
    List<String>? trackedActivityKeys,
    List<String>? completedActivityKeys,
    List<ProjectPhase>? selectedPhases,
    String? projectCode,
    String? mapAddress,
    String? contractorName,
    String? siteEngineer,
    String? contactNumber,
    DateTime? actualEndDate,
    String? landArea,
    String? landUnit,
    int? room1BHK,
    int? room2BHK,
    int? room3BHK,
    int? roomCustom,
    int? bathWestern,
    int? bathIndian,
    int? bathCommon,
    int? bathAttached,
    List<String>? selectedFeatures,
    double? budgetMaterial,
    double? budgetLabour,
    double? budgetEquipment,
    double? budgetMisc,
    String? projectStatus,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      sector: sector ?? this.sector,
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      totalBudget: totalBudget ?? this.totalBudget,
      spentAmount: spentAmount ?? this.spentAmount,
      totalIncome: totalIncome ?? this.totalIncome,
      startDate: startDate ?? this.startDate,
      location: location ?? this.location,
      clientName: clientName ?? this.clientName,
      projectType: projectType ?? this.projectType,
      expectedEndDate: expectedEndDate ?? this.expectedEndDate,
      floors: floors ?? this.floors,
      selectedPhaseNames: selectedPhaseNames ?? this.selectedPhaseNames,
      trackedActivityKeys: trackedActivityKeys ?? this.trackedActivityKeys,
      completedActivityKeys:
          completedActivityKeys ?? this.completedActivityKeys,
      selectedPhases: selectedPhases ?? this.selectedPhases,
      projectCode: projectCode ?? this.projectCode,
      mapAddress: mapAddress ?? this.mapAddress,
      contractorName: contractorName ?? this.contractorName,
      siteEngineer: siteEngineer ?? this.siteEngineer,
      contactNumber: contactNumber ?? this.contactNumber,
      actualEndDate: actualEndDate ?? this.actualEndDate,
      landArea: landArea ?? this.landArea,
      landUnit: landUnit ?? this.landUnit,
      room1BHK: room1BHK ?? this.room1BHK,
      room2BHK: room2BHK ?? this.room2BHK,
      room3BHK: room3BHK ?? this.room3BHK,
      roomCustom: roomCustom ?? this.roomCustom,
      bathWestern: bathWestern ?? this.bathWestern,
      bathIndian: bathIndian ?? this.bathIndian,
      bathCommon: bathCommon ?? this.bathCommon,
      bathAttached: bathAttached ?? this.bathAttached,
      selectedFeatures: selectedFeatures ?? this.selectedFeatures,
      budgetMaterial: budgetMaterial ?? this.budgetMaterial,
      budgetLabour: budgetLabour ?? this.budgetLabour,
      budgetEquipment: budgetEquipment ?? this.budgetEquipment,
      budgetMisc: budgetMisc ?? this.budgetMisc,
      projectStatus: projectStatus ?? this.projectStatus,
    );
  }
  double get remainingBudget => totalBudget - spentAmount;
  double get budgetUtilization =>
      totalBudget <= 0 ? 0 : (spentAmount / totalBudget).clamp(0.0, 1.0);
  String get formattedBudget => formatCurrency(totalBudget);
  String get formattedSpent => formatCurrency(spentAmount);
  String get formattedRemaining => formatCurrency(remainingBudget);
  Map<String, dynamic> toJson() {
    final mappedStatus = (() {
      final status = (projectStatus ?? '').trim().toLowerCase();
      if (status == 'completed') return 'Completed';
      if (status == 'on hold') return 'On Hold';
      if (status == 'cancelled') return 'Cancelled';
      if (status == 'in progress') return 'Active';
      return 'Planning';
    })();
    final String ptStr = projectType ?? '';
    final String separator = ptStr.contains('→') ? '→' : '/';
    final mainType = ptStr.contains(separator)
        ? ptStr.split(separator).first.trim()
        : ptStr.trim();
    final subType = ptStr.contains(separator)
        ? ptStr.split(separator).last.trim()
        : '';
    return {
      '_id': id,
      'name': name,
      'projectName': name,
      'city': city,
      'sector': sector,
      'stage': stage.name,
      'progress': progress,
      'spentAmount': spentAmount,
      'totalIncome': totalIncome,
      'totalBudget': totalBudget,
      'startDate': startDate.toIso8601String(),
      'dates': {
        'startDate': startDate.toIso8601String(),
        if (expectedEndDate != null)
          'expectedEndDate': expectedEndDate!.toIso8601String(),
        if (actualEndDate != null)
          'actualEndDate': actualEndDate!.toIso8601String(),
      },
      if (expectedEndDate != null)
        'expectedEndDate': expectedEndDate!.toIso8601String(),
      if (actualEndDate != null)
        'actualEndDate': actualEndDate!.toIso8601String(),
      'location': location,
      'clientName': clientName ?? 'Internal Client',
      'projectCode':
          projectCode ?? 'PRJ-${DateTime.now().millisecondsSinceEpoch}',
      'budgetMaterial': budgetMaterial ?? 0,
      'budgetMaterials': budgetMaterial ?? 0,
      'budgetLabour': budgetLabour ?? 0,
      'budgetEquipment': budgetEquipment ?? 0,
      'budgetMisc': budgetMisc ?? 0,
      'budgetMiscellaneous': budgetMisc ?? 0,
      'buildingType': {'mainType': mainType, 'subType': subType},
      'budget': {
        'total': totalBudget,
        'material': budgetMaterial ?? 0,
        'materials': budgetMaterial ?? 0,
        'labour': budgetLabour ?? 0,
        'equipment': budgetEquipment ?? 0,
        'misc': budgetMisc ?? 0,
        'miscellaneous': budgetMisc ?? 0,
      },
      'status': mappedStatus,
      'projectStatus': projectStatus,
      'floors': floors,
      'selectedPhaseNames': selectedPhaseNames,
      'trackedActivityKeys': trackedActivityKeys,
      'completedActivityKeys': completedActivityKeys,
      'selectedPhases': selectedPhases?.map((p) => p.toJson()).toList(),
      'contractorName': contractorName,
      'siteEngineer': siteEngineer,
      'contactNumber': contactNumber,
      'mapAddress': mapAddress,
      'landArea': landArea,
      'landUnit': landUnit,
      'room1BHK': room1BHK,
      'room2BHK': room2BHK,
      'room3BHK': room3BHK,
      'roomCustom': roomCustom,
      'bathWestern': bathWestern,
      'bathIndian': bathIndian,
      'bathCommon': bathCommon,
      'bathAttached': bathAttached,
      'selectedFeatures': selectedFeatures,
      'projectType': projectType,
    };
  }
  factory ProjectModel.fromJson(Map<String, dynamic> j) {
    final dates = j['dates'] as Map<String, dynamic>?;
    final budget = j['budget'] as Map<String, dynamic>?;
    final buildingType = j['buildingType'] as Map<String, dynamic>?;
    final rawName = (j['projectName'] ?? j['name'] ?? '').toString();
    final pCode = (j['projectCode'] ?? 'Unnamed Project').toString();
    final finalName = rawName.trim().isNotEmpty ? rawName : pCode;
    DateTime parsedStartDate = DateTime.now();
    final rawStartDate =
        j['startDate']?.toString() ?? dates?['startDate']?.toString();
    if (rawStartDate != null && rawStartDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawStartDate);
      if (parsed != null) parsedStartDate = parsed;
    }
    DateTime? parsedExpectedEnd;
    final rawExpected =
        j['expectedEndDate']?.toString() ??
        dates?['expectedEndDate']?.toString();
    if (rawExpected != null && rawExpected.isNotEmpty) {
      parsedExpectedEnd = DateTime.tryParse(rawExpected);
    }
    List<String>? parsedFloors;
    final rawFloors = j['floors'] as List?;
    if (rawFloors != null && rawFloors.isNotEmpty) {
      parsedFloors = rawFloors.map((f) => f.toString()).toList();
    }
    String? resolvedProjectStatus = j['projectStatus']?.toString();
    if (resolvedProjectStatus == null || resolvedProjectStatus.isEmpty) {
      final backendStatus = (j['status'] ?? '').toString().toLowerCase();
      if (backendStatus == 'active') {
        resolvedProjectStatus = 'In Progress';
      } else if (backendStatus == 'on hold') {
        resolvedProjectStatus = 'On Hold';
      } else if (backendStatus == 'completed') {
        resolvedProjectStatus = 'Completed';
      } else if (backendStatus == 'review needed') {
        resolvedProjectStatus = 'On Hold';
      } else {
        resolvedProjectStatus = 'Planning';
      }
    }
    int? safeInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v');
    final bMat =
        (budget?['material'] as num?)?.toDouble() ??
        (budget?['materials'] as num?)?.toDouble() ??
        (j['budgetMaterial'] as num?)?.toDouble() ??
        (j['budgetMaterials'] as num?)?.toDouble() ??
        0.0;
    final bLab =
        (budget?['labour'] as num?)?.toDouble() ??
        (j['budgetLabour'] as num?)?.toDouble() ??
        0.0;
    final bEq =
        (budget?['equipment'] as num?)?.toDouble() ??
        (j['budgetEquipment'] as num?)?.toDouble() ??
        0.0;
    final bMisc =
        (budget?['misc'] as num?)?.toDouble() ??
        (budget?['miscellaneous'] as num?)?.toDouble() ??
        (j['budgetMisc'] as num?)?.toDouble() ??
        (j['budgetMiscellaneous'] as num?)?.toDouble() ??
        0.0;
    String? projectTypeStr = j['projectType']?.toString();
    if ((projectTypeStr == null || projectTypeStr.isEmpty) &&
        buildingType != null) {
      final mainType = buildingType['mainType']?.toString() ?? '';
      final subType = buildingType['subType']?.toString() ?? '';
      projectTypeStr = subType.isNotEmpty ? '$mainType → $subType' : mainType;
    }
    if (projectTypeStr != null) {
      if (projectTypeStr.contains('Business / Commercial')) {
        projectTypeStr = projectTypeStr.replaceAll(
          'Business / Commercial',
          'Commercial',
        );
      } else if (projectTypeStr.contains('Business/Commercial')) {
        projectTypeStr = projectTypeStr.replaceAll(
          'Business/Commercial',
          'Commercial',
        );
      }
      if (projectTypeStr.contains(' / ')) {
        projectTypeStr = projectTypeStr.replaceFirst(' / ', ' → ');
      }
    }
    final List<String>? parsedCompletedKeys = (j['completedActivityKeys'] ??
            j['completedActivities'] ??
            j['completed_activity_keys']) !=
        null
        ? List<String>.from(
            (j['completedActivityKeys'] ??
                    j['completedActivities'] ??
                    j['completed_activity_keys']) as List,
          )
        : null;

    final Set<String> completedSet = Set<String>.from(parsedCompletedKeys ?? []);

    List<ProjectPhase>? parsedSelectedPhases = j['selectedPhases'] != null
        ? (j['selectedPhases'] as List<dynamic>)
            .map((e) => ProjectPhase.fromJson(e as Map<String, dynamic>))
            .toList()
        : null;

    if (parsedSelectedPhases != null && parsedSelectedPhases.isNotEmpty) {
      final updatedPhases = parsedSelectedPhases.map((phase) {
        final updatedActivities = phase.activities.map((act) {
          final isKeyCompleted = completedSet.contains(act.id) ||
              completedSet.contains(act.name) ||
              completedSet.contains('${phase.phaseName}_${act.name}') ||
              completedSet.contains('${phase.id}_${act.id}');
          if (act.completed) {
            completedSet.add(act.id);
            completedSet.add(act.name);
            return act;
          } else if (isKeyCompleted) {
            return act.copyWith(completed: true);
          }
          return act;
        }).toList();
        return phase.copyWith(activities: updatedActivities);
      }).toList();
      parsedSelectedPhases = updatedPhases;
    }

    final int totalCount = parsedSelectedPhases?.fold<int>(
            0, (sum, p) => sum + p.totalCount) ??
        0;
    final int doneCount = parsedSelectedPhases?.fold<int>(
            0, (sum, p) => sum + p.completedCount) ??
        completedSet.length;

    double parsedProgress = (j['progress'] as num?)?.toDouble() ?? 0.0;
    if (totalCount > 0 && (parsedProgress == 0.0 || doneCount > 0)) {
      parsedProgress = (doneCount / totalCount).clamp(0.0, 1.0);
    }

    return ProjectModel(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      name: finalName,
      city: (j['city']?.toString() ?? '').isNotEmpty
          ? j['city'].toString()
          : (j['location']?.toString() ?? ''),
      sector: j['sector']?.toString() ?? '',
      stage: ProjectStage.values.firstWhere(
        (e) => e.name == j['stage'],
        orElse: () => ProjectStage.preConstruction,
      ),
      progress: parsedProgress,
      spentAmount: (j['spentAmount'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (j['totalIncome'] as num?)?.toDouble() ?? 0.0,
      totalBudget:
          (j['totalBudget'] as num?)?.toDouble() ??
          (budget?['total'] as num?)?.toDouble() ??
          0.0,
      startDate: parsedStartDate,
      location: j['location']?.toString() ?? '',
      clientName: j['clientName']?.toString(),
      projectType: projectTypeStr,
      expectedEndDate: parsedExpectedEnd,
      floors: parsedFloors,
      selectedPhaseNames: j['selectedPhaseNames'] != null
          ? List<String>.from(j['selectedPhaseNames'] as List)
          : null,
      trackedActivityKeys: j['trackedActivityKeys'] != null
          ? List<String>.from(j['trackedActivityKeys'] as List)
          : null,
      completedActivityKeys: completedSet.isNotEmpty
          ? completedSet.toList()
          : parsedCompletedKeys,
      selectedPhases: parsedSelectedPhases,
      contractorName: j['contractorName']?.toString(),
      siteEngineer:
          j['siteEngineer']?.toString() ?? j['siteEngineerName']?.toString(),
      contactNumber: j['contactNumber']?.toString(),
      mapAddress: j['mapAddress']?.toString(),
      actualEndDate: dates?['actualEndDate'] != null
          ? DateTime.tryParse(dates!['actualEndDate'].toString())
          : (j['actualEndDate'] != null
                ? DateTime.tryParse(j['actualEndDate'].toString())
                : null),
      landArea: j['landArea']?.toString(),
      landUnit: j['landUnit']?.toString(),
      projectCode: j['projectCode']?.toString(),
      room1BHK: safeInt(j['room1BHK']),
      room2BHK: safeInt(j['room2BHK']),
      room3BHK: safeInt(j['room3BHK']),
      roomCustom: safeInt(j['roomCustom']),
      bathWestern: safeInt(j['bathWestern']),
      bathIndian: safeInt(j['bathIndian']),
      bathCommon: safeInt(j['bathCommon']),
      bathAttached: safeInt(j['bathAttached']),
      selectedFeatures: j['selectedFeatures'] != null
          ? List<String>.from(j['selectedFeatures'] as List)
          : null,
      budgetMaterial: bMat > 0 ? bMat : null,
      budgetLabour: bLab > 0 ? bLab : null,
      budgetEquipment: bEq > 0 ? bEq : null,
      budgetMisc: bMisc > 0 ? bMisc : null,
      projectStatus: resolvedProjectStatus,
    );
  }
  static String encodeList(List<ProjectModel> list) =>
      jsonEncode(list.map((p) => p.toJson()).toList());
  static List<ProjectModel> decodeList(String raw) {
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
