import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/log_sheet.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/inventory_provider.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/screen/reports/save_helper_stub.dart'
    if (dart.library.html) 'package:buildtrack_mobile/screen/reports/save_helper_web.dart'
    if (dart.library.io) 'package:buildtrack_mobile/screen/reports/save_helper_mobile.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';

class AddEntryScreen extends StatelessWidget {
  AddEntryScreen({super.key});
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
          backgroundColor: AppColors.primary, 
          textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        )
      ], 
      enableAutoScroll: true,
      onFinish: () {
        UserSession.markModuleVisited('AddEntryScreen');
        if (UserSession.globalTourActive) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) {
              final nav = Provider.of<NavController>(context, listen: false);
              nav.setRoute('/inventory', context);
            }
          });
        }
      },
      builder: (context) => const _AddEntryScreenContent(),
    );
  }
}

class _AddEntryScreenContent extends StatefulWidget {
  const _AddEntryScreenContent();
  @override
  State<_AddEntryScreenContent> createState() => _AddEntryScreenContentState();
}
class _AddEntryScreenContentState extends State<_AddEntryScreenContent> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isUploadingCsv = false;
  List<String> _customColumns = [
    'Date',
    'Project',
    'Floor',
    'Phase',
    'Activity',
    'Type',
    'Name',
    'Category / Trade',
    'Subtype',
    'Brand',
    'Supplier / Operator',
    'Quantity',
    'Unit',
    'Rate',
    'Overtime',
    'IsWithGst',
    'GstPercentage',
    'Payment Status',
    'Notes',
  ];
  late Map<String, bool> _columnVisibility;
  final GlobalKey _csvKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _columnVisibility = {for (var c in _customColumns) c: true};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!UserSession.hasSkippedTour && !UserSession.visitedModules.contains('AddEntryScreen')) {
        final keys = <GlobalKey>[];
        if (RoleManager.canManageExpenses) keys.add(ShowcaseKeys.addEntryMaterial);
        if (RoleManager.canAddEntries) keys.add(ShowcaseKeys.addEntryLabour);
        if (RoleManager.canManageEquipmentMaster) keys.add(ShowcaseKeys.addEntryEquipment);
        keys.add(ShowcaseKeys.addEntryCSV);
        keys.add(_csvKey);
        ShowCaseWidget.of(context).startShowCase(keys);
        UserSession.markModuleVisited('AddEntryScreen');
      }
    });
  }
  List<Map<String, dynamic>> get _entries {
    final items = <Map<String, dynamic>>[];
    if (RoleManager.canManageExpenses) {
      items.add({
        'icon': Icons.category,
        'title': 'Material',
        'subtitle':
            'Log concrete, steel, lumber, or site-specific procurement items.',
        'type': 'material',
        'short': 'Concrete, steel, lumber & site items',
      });
    }
    if (RoleManager.canAddEntries) {
      items.add({
        'icon': Icons.people,
        'title': 'Labour',
        'subtitle':
            'Track crew hours, specialized trade performance, and site presence.',
        'type': 'labour',
        'short': 'Crew hours, trades, site presence',
      });
    }
    if (RoleManager.canManageEquipmentMaster) {
      items.add({
        'icon': Icons.precision_manufacturing,
        'title': 'Equipment',
        'subtitle':
            'Record heavy machinery runtime, fuel logs, and maintenance events.',
        'type': 'equipment',
        'short': 'Machine runtime, fuel, maintenance',
      });
    }
    return items;
  }
  void _navigateToContext(BuildContext context, String type) {
    Navigator.pushNamed(
      context,
      '/execution-context',
      arguments: {'type': type},
    );
  }
  Future<void> _downloadCsvTemplate(String type) async {
    final List<List<dynamic>> csvRows = [];
    String filename = '';
    String shareText = '';
    if (type == 'material') {
      csvRows.add([
        'Date',
        'Project',
        'Floor',
        'Phase',
        'Activity',
        'Material / Item',
        'Unit',
        'Quantity',
        'Rate',
        'Brand',
        'Category',
        'Supplier',
        'IsWithGst',
        'GstPercentage',
        'Notes',
      ]);
      filename = 'material_entries_template.csv';
      shareText = 'Download Material Entries CSV Template';
    } else if (type == 'labour') {
      csvRows.add([
        'Date',
        'Project',
        'Floor',
        'Phase',
        'Activity',
        'Labour Type',
        'Unit',
        'Quantity',
        'Rate',
        'Trade / Work Type',
        'Contractor / Team',
        'Overtime Amount',
        'Notes',
      ]);
      filename = 'labour_entries_template.csv';
      shareText = 'Download Labour Entries CSV Template';
    } else if (type == 'equipment') {
      csvRows.add([
        'Date',
        'Project',
        'Floor',
        'Phase',
        'Activity',
        'Equipment Name',
        'Unit',
        'Quantity',
        'Rate',
        'Machinery Sub-Class / Model',
        'Operator / Vendor',
        'IsWithGst',
        'GstPercentage',
        'Notes',
      ]);
      filename = 'equipment_entries_template.csv';
      shareText = 'Download Equipment Entries CSV Template';
    } else if (type == 'all') {
      final activeHeaders = _customColumns
          .where((c) => _columnVisibility[c] ?? true)
          .toList();
      csvRows.add(activeHeaders);
      filename = 'all_entries_template.csv';
      shareText = 'Download Consolidated All Entries CSV Template';
    }
    final csvContent = const ListToCsvConverter().convert(csvRows);
    try {
      await saveAndShareCsv(
        csvContent: csvContent,
        filename: filename,
        shareText: shareText,
      );
      if (mounted) {
        btToast(
          context,
          '${type == "all" ? "All" : type[0].toUpperCase() + type.substring(1)} template downloaded successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        btToast(context, 'Download failed: $e', error: true);
      }
    }
  }
  Future<void> _uploadCsv() async {
    setState(() => _isUploadingCsv = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isUploadingCsv = false);
        return;
      }
      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        throw Exception("Failed to read file data");
      }
      final csvString = utf8.decode(fileBytes);
      final List<List<dynamic>> parsedCsv = const CsvToListConverter().convert(
        csvString,
      );
      if (parsedCsv.isEmpty || parsedCsv.length <= 1) {
        throw Exception("CSV file is empty or missing headers");
      }
      final headers = parsedCsv.first
          .map((h) => h.toString().trim().toLowerCase())
          .toList();
      String detectedType = '';
      if (headers.contains('type')) {
        detectedType = 'all';
      } else if (headers.contains('material / item') ||
          headers.contains('material_item')) {
        detectedType = 'material';
      } else if (headers.contains('labour type') ||
          headers.contains('labour_type')) {
        detectedType = 'labour';
      } else if (headers.contains('equipment name') ||
          headers.contains('equipment_name')) {
        detectedType = 'equipment';
      } else {
        throw Exception(
          "Could not detect entry type. CSV headers must contain 'Type', 'Material / Item', 'Labour Type', or 'Equipment Name'.",
        );
      }
      final dateIdx = headers.indexOf('date');
      final projIdx = headers.indexOf('project');
      final floorIdx = headers.indexOf('floor');
      final phaseIdx = headers.indexOf('phase');
      final activityIdx = headers.indexOf('activity');
      final notesIdx = headers.indexOf('notes');
      final typeIdx = headers.indexOf('type');
      final nameIdx = headers.indexOf('name');
      final catOrTradeIdx = headers.contains('category / trade')
          ? headers.indexOf('category / trade')
          : headers.indexOf('category_or_trade');
      final subtypeIdx = headers.indexOf('subtype');
      final brandIdx = headers.indexOf('brand');
      final supplierOrOperatorIdx = headers.contains('supplier / operator')
          ? headers.indexOf('supplier / operator')
          : headers.indexOf('supplier_or_operator');
      final qtyIdx = headers.indexOf('quantity');
      final unitIdx = headers.indexOf('unit');
      final rateIdx = headers.indexOf('rate');
      final otIdx = headers.indexOf('overtime');
      final isWithGstIdx = headers.indexOf('iswithgst');
      final gstPctIdx = headers.indexOf('gstpercentage');
      final paymentStatusIdx = headers.contains('payment status')
          ? headers.indexOf('payment status')
          : headers.indexOf('payment_status');
      final materialItemIdx = headers.contains('material / item')
          ? headers.indexOf('material / item')
          : headers.indexOf('material_item');
      final matUnitIdx = headers.indexOf('unit');
      final matQtyIdx = headers.indexOf('quantity');
      final matRateIdx = headers.indexOf('rate');
      final matBrandIdx = headers.indexOf('brand');
      final matCatIdx = headers.indexOf('category');
      final matSupplierIdx = headers.indexOf('supplier');
      final matIsWithGstIdx = headers.indexOf('iswithgst');
      final matGstPctIdx = headers.indexOf('gstpercentage');
      final labourTypeIdx = headers.contains('labour type')
          ? headers.indexOf('labour type')
          : headers.indexOf('labour_type');
      final labUnitIdx = headers.indexOf('unit');
      final labQtyIdx = headers.indexOf('quantity');
      final labRateIdx = headers.indexOf('rate');
      final labTradeIdx = headers.contains('trade / work type')
          ? headers.indexOf('trade / work type')
          : headers.indexOf('trade_work_type');
      final labContractorIdx = headers.contains('contractor / team')
          ? headers.indexOf('contractor / team')
          : headers.indexOf('contractor_team');
      final labOvertimeIdx = headers.contains('overtime amount')
          ? headers.indexOf('overtime amount')
          : headers.indexOf('overtime_amount');
      final eqNameIdx = headers.contains('equipment name')
          ? headers.indexOf('equipment name')
          : headers.indexOf('equipment_name');
      final eqUnitIdx = headers.indexOf('unit');
      final eqQtyIdx = headers.indexOf('quantity');
      final eqRateIdx = headers.indexOf('rate');
      final eqSubclassIdx = headers.contains('machinery sub-class / model')
          ? headers.indexOf('machinery sub-class / model')
          : headers.indexOf('machinery_subclass_model');
      final eqOperatorIdx = headers.contains('operator / vendor')
          ? headers.indexOf('operator / vendor')
          : headers.indexOf('operator_vendor');
      final eqIsWithGstIdx = headers.indexOf('iswithgst');
      final eqGstPctIdx = headers.indexOf('gstpercentage');
      if (detectedType == 'all' && (typeIdx == -1 || nameIdx == -1)) {
        throw Exception(
          "CSV missing required 'Type' or 'Name' columns for consolidated import",
        );
      }
      if (detectedType == 'material' && materialItemIdx == -1) {
        throw Exception("CSV missing required 'Material / Item' column");
      }
      if (detectedType == 'labour' && labourTypeIdx == -1) {
        throw Exception("CSV missing required 'Labour Type' column");
      }
      if (detectedType == 'equipment' && eqNameIdx == -1) {
        throw Exception("CSV missing required 'Equipment Name' column");
      }
      final projectProvider = Provider.of<ProjectProvider>(
        context,
        listen: false,
      );
      if (projectProvider.projects.isEmpty) {
        await projectProvider.load();
      }
      final projects = projectProvider.projects;
      double parseDouble(dynamic v) {
        if (v == null) return 0.0;
        if (v is num) return v.toDouble();
        final clean = v.toString().trim().replaceAll(RegExp(r'[^\d\.]'), '');
        return double.tryParse(clean) ?? 0.0;
      }
      bool parseBool(dynamic v) {
        if (v == null) return false;
        final s = v.toString().trim().toLowerCase();
        return s == 'true' || s == 'yes' || s == '1';
      }
      String parseString(dynamic v) {
        if (v == null) return '';
        return v.toString().trim();
      }
      int successCount = 0;
      int materialCount = 0;
      int labourCount = 0;
      int equipmentCount = 0;
      int failedCount = 0;
      final List<String> errorMessages = [];
      StateSetter? dialogSetState;
      String progressText = "Preparing import...";
      double progressValue = 0.0;
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setDlgState) {
              dialogSetState = setDlgState;
              return _ImportProgressDialog(
                text: progressText,
                value: progressValue,
              );
            },
          );
        },
      );
      void updateProgress(String text, double value) {
        progressText = text;
        progressValue = value;
        if (dialogSetState != null) {
          dialogSetState!(() {});
        }
      }
      final totalRows = parsedCsv.length - 1;
      List<Map<String, dynamic>> bulkPayloads = [];
      for (int i = 1; i < parsedCsv.length; i++) {
        final row = parsedCsv[i];
        if (row.isEmpty ||
            row.every(
              (element) => element == null || element.toString().trim().isEmpty,
            )) {
          continue;
        }
        final rowNum = i + 1;
        updateProgress("Processing row $i of $totalRows...", i / totalRows);
        try {
          final dateStr = dateIdx != -1 && dateIdx < row.length
              ? parseString(row[dateIdx])
              : '';
          final date = dateStr.isNotEmpty
              ? (DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now())
              : DateTime.now();
          final notes = notesIdx != -1 && notesIdx < row.length
              ? parseString(row[notesIdx])
              : '';
          final csvProjName = projIdx != -1 && projIdx < row.length
              ? parseString(row[projIdx])
              : '';
          var matchedProject = projects.cast<ProjectModel?>().firstWhere(
            (p) =>
                p?.name.trim().toLowerCase() ==
                    csvProjName.trim().toLowerCase() ||
                p?.id == csvProjName,
            orElse: () => null,
          );
          if (matchedProject == null) {
            if (csvProjName.isNotEmpty) {
              throw Exception(
                "Row $rowNum: No project found with the name '$csvProjName' in your account.",
              );
            }
            matchedProject = projectProvider.selectedProject;
          }
          if (matchedProject == null) {
            throw Exception(
              "Row $rowNum: No project provided in the CSV, and no active project selected in the app.",
            );
          }
          final projectId = matchedProject.id;
          final csvFloor = floorIdx != -1 && floorIdx < row.length
              ? parseString(row[floorIdx])
              : '';
          String? resolvedFloor;
          if (csvFloor.isNotEmpty) {
            resolvedFloor = csvFloor;
          } else if (matchedProject.floors != null &&
              matchedProject.floors!.isNotEmpty) {
            resolvedFloor = matchedProject.floors!.first;
          }
          final csvPhase = phaseIdx != -1 && phaseIdx < row.length
              ? parseString(row[phaseIdx])
              : '';
          String? phaseName;
          String? phaseId;
          if (csvPhase.isNotEmpty) {
            if (matchedProject.selectedPhases != null) {
              final phaseMatch = matchedProject.selectedPhases!
                  .cast<ProjectPhase?>()
                  .firstWhere(
                    (p) =>
                        p?.phaseName.trim().toLowerCase() ==
                        csvPhase.trim().toLowerCase(),
                    orElse: () => null,
                  );
              if (phaseMatch != null) {
                phaseName = phaseMatch.phaseName;
                phaseId = phaseMatch.id;
              }
            }
            phaseName ??= csvPhase;
          }
          final csvActivity = activityIdx != -1 && activityIdx < row.length
              ? parseString(row[activityIdx])
              : '';
          String? activityName;
          String? activityId;
          if (csvActivity.isNotEmpty) {
            if (matchedProject.selectedPhases != null) {
              for (final phase in matchedProject.selectedPhases!) {
                if (phaseName != null &&
                    phase.phaseName.trim().toLowerCase() !=
                        phaseName.trim().toLowerCase()) {
                  continue;
                }
                final actMatch = phase.activities
                    .cast<ProjectActivity?>()
                    .firstWhere(
                      (a) =>
                          a?.name.trim().toLowerCase() ==
                          csvActivity.trim().toLowerCase(),
                      orElse: () => null,
                    );
                if (actMatch != null) {
                  activityName = actMatch.name;
                  activityId = actMatch.id;
                  if (phaseName == null) {
                    phaseName = phase.phaseName;
                    phaseId = phase.id;
                  }
                  break;
                }
              }
            }
            activityName ??= csvActivity;
          }
          final Map<String, dynamic> payload = {};
          if (detectedType == 'all') {
            final rowType = typeIdx != -1 && typeIdx < row.length
                ? parseString(row[typeIdx]).toLowerCase()
                : '';
            final name = nameIdx != -1 && nameIdx < row.length
                ? parseString(row[nameIdx])
                : '';
            var resolvedRowType = rowType;
            if (resolvedRowType.isEmpty) {
              final hasSubtype =
                  subtypeIdx != -1 &&
                  subtypeIdx < row.length &&
                  parseString(row[subtypeIdx]).isNotEmpty;
              final hasOvertime =
                  otIdx != -1 &&
                  otIdx < row.length &&
                  parseDouble(row[otIdx]) > 0;
              final hasOperator =
                  supplierOrOperatorIdx != -1 &&
                  supplierOrOperatorIdx < row.length &&
                  parseString(row[supplierOrOperatorIdx]).isNotEmpty;
              if (hasSubtype) {
                resolvedRowType = 'material';
              } else if (hasOvertime) {
                resolvedRowType = 'labour';
              } else if (hasOperator) {
                resolvedRowType = 'equipment';
              } else {
                resolvedRowType = 'material';
              }
            }
            var resolvedName = name;
            if (resolvedName.isEmpty) {
              resolvedName =
                  resolvedRowType == 'labour' || resolvedRowType == 'wages'
                  ? 'Labour Entry'
                  : (resolvedRowType == 'equipment' ||
                            resolvedRowType == 'expense'
                        ? 'Equipment Entry'
                        : 'Material Entry');
            }
            final unit = unitIdx != -1 && unitIdx < row.length
                ? parseString(row[unitIdx]).toLowerCase()
                : 'unit';
            final qty = qtyIdx != -1 && qtyIdx < row.length
                ? parseDouble(row[qtyIdx])
                : 1.0;
            final rate = rateIdx != -1 && rateIdx < row.length
                ? parseDouble(row[rateIdx])
                : 0.0;
            final brand = brandIdx != -1 && brandIdx < row.length
                ? parseString(row[brandIdx])
                : '';
            final category = catOrTradeIdx != -1 && catOrTradeIdx < row.length
                ? parseString(row[catOrTradeIdx])
                : '';
            final supplier =
                supplierOrOperatorIdx != -1 &&
                    supplierOrOperatorIdx < row.length
                ? parseString(row[supplierOrOperatorIdx])
                : '';
            final isWithGst = isWithGstIdx != -1 && isWithGstIdx < row.length
                ? parseBool(row[isWithGstIdx])
                : false;
            final gstPercentage = gstPctIdx != -1 && gstPctIdx < row.length
                ? parseDouble(row[gstPctIdx])
                : 0.0;
            final overtime = otIdx != -1 && otIdx < row.length
                ? parseDouble(row[otIdx])
                : 0.0;
            String resolvedStatus = 'Pending';
            if (paymentStatusIdx != -1 && paymentStatusIdx < row.length) {
              final statusStr = parseString(
                row[paymentStatusIdx],
              ).trim().toLowerCase();
              if (statusStr == 'fully paid' || statusStr == 'paid') {
                resolvedStatus = 'Paid';
              } else if (statusStr == 'partial' ||
                  statusStr == 'partially paid') {
                resolvedStatus = 'Partial';
              } else if (statusStr == 'not paid' ||
                  statusStr == 'unpaid' ||
                  statusStr == 'pending') {
                resolvedStatus = 'Pending';
              }
            }
            if (resolvedRowType == 'material' ||
                resolvedRowType == 'materials') {
              final subtypeVal = subtypeIdx != -1 && subtypeIdx < row.length
                  ? parseString(row[subtypeIdx])
                  : 'Purchase';
              final normalizedSubtype =
                  subtypeVal.trim().toLowerCase() == 'consumption'
                  ? 'Consumption'
                  : 'Purchase';
              final materialTypeVal = normalizedSubtype == 'Consumption'
                  ? 'usage'
                  : 'purchase';
              final normalizedUnit = (unit == 'bags' || unit == 'bag')
                  ? 'bag'
                  : (unit == 'sq.ft' || unit == 'sqft')
                  ? 'sqft'
                  : (unit == 'ton' || unit == 'tons')
                  ? 'ton'
                  : (unit == 'kg' || unit == 'kgs')
                  ? 'kg'
                  : 'unit';
              final double subtotal = qty * rate;
              final double gstAmount = isWithGst
                  ? (subtotal * gstPercentage / 100)
                  : 0.0;
              final double finalAmount = subtotal + gstAmount;
              final double paidAmt = resolvedStatus == 'Paid'
                  ? finalAmount
                  : (resolvedStatus == 'Partial' ? finalAmount / 2 : 0.0);
              payload.addAll({
                "title": resolvedName,
                "type": "Materials",
                "subType": normalizedSubtype,
                "materialType": materialTypeVal,
                "category": category,
                "brand": brand.isEmpty ? null : brand,
                "supplier": supplier,
                "quantity": qty,
                "rate": rate,
                "unit": normalizedUnit,
                "project": projectId,
                "notes": notes,
                "date": date.toUtc().toIso8601String(),
                "floor": resolvedFloor,
                "phase": ?phaseName,
                "phaseId": ?phaseId,
                "activity": ?activityName,
                "activityId": ?activityId,
                "gst": gstPercentage,
                "isWithGst": isWithGst,
                "amount": finalAmount,
                "paymentStatus": resolvedStatus,
                "paidAmount": paidAmt,
                "paymentMode": "Cash",
                if (resolvedFloor != null ||
                    phaseName != null ||
                    activityName != null)
                  "executionContext": {
                    "project": projectId,
                    "floor": ?resolvedFloor,
                    "phase": ?phaseName,
                    "phaseId": ?phaseId,
                    "activity": ?activityName,
                    "activityId": ?activityId,
                  },
              });
              bulkPayloads.add(payload);
              materialCount++;
            } else if (resolvedRowType == 'labour' ||
                resolvedRowType == 'wages') {
              final normalizedUnit = (unit == 'day' || unit == 'days')
                  ? 'day'
                  : (unit == 'hour' || unit == 'hours')
                  ? 'hour'
                  : (unit == 'sqft' || unit == 'sq.ft')
                  ? 'sqft'
                  : 'unit';
              final double finalAmount = (qty * rate) + overtime;
              final double paidAmt = resolvedStatus == 'Paid'
                  ? finalAmount
                  : (resolvedStatus == 'Partial' ? finalAmount / 2 : 0.0);
              payload.addAll({
                "title": resolvedName,
                "type": "Wages",
                "category": category.isNotEmpty ? category : 'General Labor',
                "quantity": qty,
                "rate": rate,
                "unit": normalizedUnit,
                "project": projectId,
                "date": date.toUtc().toIso8601String(),
                "floor": resolvedFloor,
                "phase": ?phaseName,
                "phaseId": ?phaseId,
                "activity": ?activityName,
                "activityId": ?activityId,
                "amount": finalAmount,
                "overtime": overtime,
                "remarks": notes,
                "notes": notes,
                "paymentStatus": resolvedStatus,
                "paidAmount": paidAmt,
                "paymentMode": "Cash",
                "worker": resolvedName,
              });
              bulkPayloads.add(payload);
              labourCount++;
            } else if (resolvedRowType == 'equipment' ||
                resolvedRowType == 'expense') {
              final normalizedUnit = (unit == 'day')
                  ? 'day'
                  : (unit == 'hour')
                  ? 'hour'
                  : (unit == 'trip' ||
                        unit == 'load' ||
                        unit == 'shift' ||
                        unit == 'truck')
                  ? 'truck'
                  : 'unit';
              final double subtotal = qty * rate;
              final double gstAmount = isWithGst
                  ? (subtotal * gstPercentage / 100)
                  : 0.0;
              final double finalAmount = subtotal + gstAmount;
              final double paidAmt = resolvedStatus == 'Paid'
                  ? finalAmount
                  : (resolvedStatus == 'Partial' ? finalAmount / 2 : 0.0);
              payload.addAll({
                "title": resolvedName,
                "type": "Expense",
                "category": resolvedName,
                "quantity": qty,
                "rate": rate,
                "unit": normalizedUnit,
                "project": projectId,
                "date": date.toUtc().toIso8601String(),
                "floor": resolvedFloor,
                "phase": ?phaseName,
                "phaseId": ?phaseId,
                "activity": ?activityName,
                "activityId": ?activityId,
                "gst": gstPercentage,
                "isWithGst": isWithGst,
                "gstPercentage": isWithGst ? gstPercentage : 0,
                "totalAmount": finalAmount,
                "amount": finalAmount,
                "brand": brand,
                "supplier": supplier,
                "notes": notes,
                "paymentStatus": resolvedStatus,
                "paidAmount": paidAmt,
                "paymentMode": "Cash",
              });
              bulkPayloads.add(payload);
              equipmentCount++;
            } else {
              throw Exception(
                "Row $rowNum: Unknown entry type '$resolvedRowType'. Must be Material, Labour, or Equipment.",
              );
            }
          } else if (detectedType == 'material') {
            final name = parseString(row[materialItemIdx]);
            if (name.isEmpty) {
              throw Exception("Row $rowNum: Material / Item name is empty");
            }
            final unit = matUnitIdx != -1 && matUnitIdx < row.length
                ? parseString(row[matUnitIdx]).toLowerCase()
                : 'unit';
            final normalizedUnit = (unit == 'bags' || unit == 'bag')
                ? 'bag'
                : (unit == 'sq.ft' || unit == 'sqft')
                ? 'sqft'
                : (unit == 'ton' || unit == 'tons')
                ? 'ton'
                : (unit == 'kg' || unit == 'kgs')
                ? 'kg'
                : 'unit';
            final qty = matQtyIdx != -1 && matQtyIdx < row.length
                ? parseDouble(row[matQtyIdx])
                : 1.0;
            final rate = matRateIdx != -1 && matRateIdx < row.length
                ? parseDouble(row[matRateIdx])
                : 0.0;
            final brand = matBrandIdx != -1 && matBrandIdx < row.length
                ? parseString(row[matBrandIdx])
                : '';
            final category = matCatIdx != -1 && matCatIdx < row.length
                ? parseString(row[matCatIdx])
                : '';
            final supplier = matSupplierIdx != -1 && matSupplierIdx < row.length
                ? parseString(row[matSupplierIdx])
                : '';
            final isWithGst =
                matIsWithGstIdx != -1 && matIsWithGstIdx < row.length
                ? parseBool(row[matIsWithGstIdx])
                : false;
            final gstPercentage =
                matGstPctIdx != -1 && matGstPctIdx < row.length
                ? parseDouble(row[matGstPctIdx])
                : 0.0;
            final double subtotal = qty * rate;
            final double gstAmount = isWithGst
                ? (subtotal * gstPercentage / 100)
                : 0.0;
            final double finalAmount = subtotal + gstAmount;
            payload.addAll({
              "title": name,
              "type": "Materials",
              "subType": "Purchase",
              "materialType": "purchase",
              "category": category,
              "brand": brand.isEmpty ? null : brand,
              "supplier": supplier,
              "quantity": qty,
              "rate": rate,
              "unit": normalizedUnit,
              "project": projectId,
              "notes": notes,
              "date": date.toUtc().toIso8601String(),
              "floor": resolvedFloor,
              "phase": ?phaseName,
              "phaseId": ?phaseId,
              "activity": ?activityName,
              "activityId": ?activityId,
              "gst": gstPercentage,
              "isWithGst": isWithGst,
              "amount": finalAmount,
              "paymentStatus": "Pending",
              "paymentMode": "Cash",
              if (resolvedFloor != null ||
                  phaseName != null ||
                  activityName != null)
                "executionContext": {
                  "project": projectId,
                  "floor": ?resolvedFloor,
                  "phase": ?phaseName,
                  "phaseId": ?phaseId,
                  "activity": ?activityName,
                  "activityId": ?activityId,
                },
            });
            bulkPayloads.add(payload);
            materialCount++;
          } else if (detectedType == 'labour') {
            final name = parseString(row[labourTypeIdx]);
            if (name.isEmpty) {
              throw Exception("Row $rowNum: Labour Type (name) is empty");
            }
            final unit = labUnitIdx != -1 && labUnitIdx < row.length
                ? parseString(row[labUnitIdx]).toLowerCase()
                : 'hour';
            final normalizedUnit = (unit == 'day' || unit == 'days')
                ? 'day'
                : (unit == 'hour' || unit == 'hours')
                ? 'hour'
                : (unit == 'sqft' || unit == 'sq.ft')
                ? 'sqft'
                : 'unit';
            final qty = labQtyIdx != -1 && labQtyIdx < row.length
                ? parseDouble(row[labQtyIdx])
                : 1.0;
            final rate = labRateIdx != -1 && labRateIdx < row.length
                ? parseDouble(row[labRateIdx])
                : 0.0;
            final trade = labTradeIdx != -1 && labTradeIdx < row.length
                ? parseString(row[labTradeIdx])
                : 'General Labor';
            final contractor =
                labContractorIdx != -1 && labContractorIdx < row.length
                ? parseString(row[labContractorIdx])
                : '';
            final overtime = labOvertimeIdx != -1 && labOvertimeIdx < row.length
                ? parseDouble(row[labOvertimeIdx])
                : 0.0;
            final double finalAmount = (qty * rate) + overtime;
            payload.addAll({
              "title": name,
              "type": "Wages",
              "category": trade,
              "quantity": qty,
              "rate": rate,
              "unit": normalizedUnit,
              "project": projectId,
              "date": date.toUtc().toIso8601String(),
              "floor": resolvedFloor,
              "phase": ?phaseName,
              "phaseId": ?phaseId,
              "activity": ?activityName,
              "activityId": ?activityId,
              "amount": finalAmount,
              "overtime": overtime,
              "remarks": contractor.isNotEmpty ? contractor : notes,
              "notes": notes,
              "paymentStatus": "Pending",
              "paymentMode": "Cash",
              "worker": name,
            });
            bulkPayloads.add(payload);
            labourCount++;
          } else if (detectedType == 'equipment') {
            final name = parseString(row[eqNameIdx]);
            if (name.isEmpty) {
              throw Exception("Row $rowNum: Equipment Name is empty");
            }
            final unit = eqUnitIdx != -1 && eqUnitIdx < row.length
                ? parseString(row[eqUnitIdx]).toLowerCase()
                : 'hour';
            final normalizedUnit = (unit == 'day')
                ? 'day'
                : (unit == 'hour')
                ? 'hour'
                : (unit == 'trip' ||
                      unit == 'load' ||
                      unit == 'shift' ||
                      unit == 'truck')
                ? 'truck'
                : 'unit';
            final qty = eqQtyIdx != -1 && eqQtyIdx < row.length
                ? parseDouble(row[eqQtyIdx])
                : 1.0;
            final rate = eqRateIdx != -1 && eqRateIdx < row.length
                ? parseDouble(row[eqRateIdx])
                : 0.0;
            final subclass = eqSubclassIdx != -1 && eqSubclassIdx < row.length
                ? parseString(row[eqSubclassIdx])
                : '';
            final operatorVal =
                eqOperatorIdx != -1 && eqOperatorIdx < row.length
                ? parseString(row[eqOperatorIdx])
                : '';
            final isWithGst =
                eqIsWithGstIdx != -1 && eqIsWithGstIdx < row.length
                ? parseBool(row[eqIsWithGstIdx])
                : false;
            final gstPercentage = eqGstPctIdx != -1 && eqGstPctIdx < row.length
                ? parseDouble(row[eqGstPctIdx])
                : 0.0;
            final double subtotal = qty * rate;
            final double gstAmount = isWithGst
                ? (subtotal * gstPercentage / 100)
                : 0.0;
            final double finalAmount = subtotal + gstAmount;
            payload.addAll({
              "title": name,
              "type": "Expense",
              "category": name,
              "quantity": qty,
              "rate": rate,
              "unit": normalizedUnit,
              "project": projectId,
              "date": date.toUtc().toIso8601String(),
              "floor": resolvedFloor,
              "phase": ?phaseName,
              "phaseId": ?phaseId,
              "activity": ?activityName,
              "activityId": ?activityId,
              "gst": gstPercentage,
              "isWithGst": isWithGst,
              "gstPercentage": isWithGst ? gstPercentage : 0,
              "totalAmount": finalAmount,
              "amount": finalAmount,
              "brand": subclass,
              "supplier": operatorVal,
              "notes": notes,
              "paymentStatus": "Pending",
              "paymentMode": "Cash",
            });
            bulkPayloads.add(payload);
            equipmentCount++;
          }
        } catch (e) {
          failedCount++;
          errorMessages.add(e.toString());
        }
      }
      if (bulkPayloads.isNotEmpty) {
        successCount = 0;
        failedCount = 0;
        updateProgress(
          "Uploading ${bulkPayloads.length} entries in bulk...",
          0.9,
        );
        try {
          final bulkResponse = await ApiService.addTransactionsBulk(
            bulkPayloads,
          );
          if (bulkResponse != null && bulkResponse['results'] != null) {
            final results = bulkResponse['results'];
            successCount = results['successCount'] ?? 0;
            failedCount = results['failedCount'] ?? 0;
            if (results['failures'] != null) {
              for (var f in results['failures']) {
                errorMessages.add(
                  "Row ${f['index'] + 1} (${f['title']}): ${f['reason']}",
                );
              }
            }
          } else {
            failedCount += bulkPayloads.length;
            errorMessages.add("Bulk upload failed completely.");
          }
        } catch (e) {
          failedCount += bulkPayloads.length;
          errorMessages.add("Bulk upload error: $e");
        }
      }
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        final activeProjId = projectProvider.selectedProject?.id;
        if (activeProjId != null) {
          context.read<InventoryProvider>().loadInventory(activeProjId);
        }
        context.read<ProjectProvider>().load();
      }
      if (mounted && successCount > 0) {
        await showBtSuccess(
          context,
          kind: BtSuccessKind.bags,
          title: 'Entries imported',
          message: '$successCount ${successCount == 1 ? 'entry' : 'entries'} added from your spreadsheet',
        );
        if (!mounted) return;
      }
      if (mounted) {
        showDialog(
          context: context,
          barrierColor: Bt.scrim,
          builder: (ctx) {
            return _ImportResultsDialog(
              successCount: successCount,
              failedCount: failedCount,
              materialCount: materialCount,
              labourCount: labourCount,
              equipmentCount: equipmentCount,
              errorMessages: errorMessages,
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        btToast(context, 'Upload failed: $e', error: true);
      }
    } finally {
      setState(() => _isUploadingCsv = false);
    }
  }
  Widget _buildCsvImportCard(BuildContext context) {
    final bt = context.bt;
    final visibleCols = _customColumns.where((c) => _columnVisibility[c] ?? true).toList();
    return Showcase(
      key: ShowcaseKeys.addEntryCSV,
      description: 'Upload bulk entries via CSV. Download templates and upload completed files here.',
      tooltipBackgroundColor: Bt.ink,
      textColor: Colors.white,
      tooltipBorderRadius: BorderRadius.circular(16),
      tooltipPadding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('IMPORT MANY', style: BtText.mono(context, color: bt.accentInk)),
          const SizedBox(height: 4),
          Text('From a\nspreadsheet.', style: BtText.d2(context)),
          const SizedBox(height: 8),
          Text(
            'Import Materials, Labour, or Equipment entries. Download the template, fill it, and upload the file — each row becomes an entry.',
            style: BtText.subhead(context),
          ),
          const SizedBox(height: 22),
          _Timeline(steps: [
            // 01 · Get the template
            _TimelineStep(
              number: 1,
              active: true,
              title: 'Get the template',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${visibleCols.length} of ${_customColumns.length} columns · consolidated (all entry types)', style: BtText.caption(context)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: BtButton(
                      label: 'Download template',
                      icon: Icons.download_rounded,
                      small: true,
                      onPressed: _isUploadingCsv ? null : () => _downloadCsvTemplate('all'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Showcase(
                    key: _csvKey,
                    title: 'Customize Template',
                    description: 'You can adjust which columns appear in the CSV.',
                    child: BtButton(
                      label: 'Columns',
                      icon: Icons.tune_rounded,
                      small: true,
                      expand: false,
                      variant: BtButtonVariant.secondary,
                      onPressed: _isUploadingCsv ? null : _openCustomizeColumnsSheet,
                    ),
                  ),
                ]),
              ]),
            ),
            // 02 · Fill one row per entry
            _TimelineStep(
              number: 2,
              title: 'Fill one row per entry',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _MiniSheet(columns: visibleCols),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.info_outline_rounded, size: 15, color: Bt.ink3)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'If you skip an optional column in a row, type "###" instead of leaving it blank so the file parses correctly.',
                      style: BtText.caption(context),
                    ),
                  ),
                ]),
              ]),
            ),
            // 03 · Upload it
            _TimelineStep(
              number: 3,
              title: 'Upload it',
              child: _UploadDrop(uploading: _isUploadingCsv, onTap: _isUploadingCsv ? null : _uploadCsv),
            ),
          ]),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final types = _entries;
    return Scaffold(
      backgroundColor: Bt.ground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            SizedBox(
              height: 56,
              child: Row(children: [
                const SizedBox(width: 4),
                if (canPop)
                  BtIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 19,
                    semantic: 'Back',
                    onTap: () => Navigator.pop(context),
                  ),
                const Spacer(),
                BtIconButton(
                  icon: Icons.help_outline_rounded,
                  semantic: 'Help',
                  color: Bt.ink2,
                  onTap: () => ShowCaseWidget.of(context).startShowCase([_csvKey]),
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
                const SizedBox(width: 12),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Bt.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  BtReveal(child: Text('ADD ENTRY', style: BtText.mono(context, color: context.bt.accentInk))),
                  const SizedBox(height: 4),
                  BtReveal(index: 1, child: Text('What are you\nadding?', style: BtText.d1(context))),
                  const SizedBox(height: 8),
                  BtReveal(index: 2, child: Text('Select the entry type to log for the current shift.', style: BtText.body(context, color: Bt.ink2))),
                  const SizedBox(height: 20),
                  if (types.isNotEmpty)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (var i = 0; i < types.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: _entryCard(context, i)),
                      ],
                    ]),
                  const SizedBox(height: 36),
                  _buildCsvImportCard(context),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(),
    );
  }
  Widget _entryCard(BuildContext context, int index) {
    final entry = _entries[index];
    final String type = entry['type'] as String;
    GlobalKey? showcaseKey;
    String description = '';
    if (type == 'material') {
      showcaseKey = ShowcaseKeys.addEntryMaterial;
      description = 'Log concrete, steel, lumber, or site-specific procurement items.';
    } else if (type == 'labour') {
      showcaseKey = ShowcaseKeys.addEntryLabour;
      description = 'Track crew hours, specialized trade performance, and site presence.';
    } else if (type == 'equipment') {
      showcaseKey = ShowcaseKeys.addEntryEquipment;
      description = 'Record heavy machinery runtime, fuel logs, and maintenance events.';
    }

    Widget cardContent = LogKindTile(
      type: type,
      title: entry['title'] as String,
      subtitle: entry['short'] as String,
      onTap: () => _navigateToContext(context, type),
    );

    if (showcaseKey != null) {
      return Showcase(
        key: showcaseKey,
        description: description,
        tooltipBackgroundColor: Bt.ink,
        textColor: Colors.white,
        tooltipBorderRadius: BorderRadius.circular(16),
        tooltipPadding: const EdgeInsets.all(16),
        child: cardContent,
      );
    }
    return cardContent;
  }
  Future<void> _openCustomizeColumnsSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CustomizeTemplateSheet(
          initialColumns: _customColumns,
          initialVisibility: _columnVisibility,
        );
      },
    );
    if (result != null) {
      setState(() {
        _customColumns = List<String>.from(result['columns'] as List);
        _columnVisibility = Map<String, bool>.from(result['visibility'] as Map);
      });
      if (mounted) {
        btToast(context, 'Template customization applied! Ready to download.');
      }
    }
  }
}
class CustomizeTemplateSheet extends StatefulWidget {
  final List<String> initialColumns;
  final Map<String, bool> initialVisibility;
  const CustomizeTemplateSheet({
    super.key,
    required this.initialColumns,
    required this.initialVisibility,
  });
  @override
  State<CustomizeTemplateSheet> createState() => _CustomizeTemplateSheetState();
}
class _CustomizeTemplateSheetState extends State<CustomizeTemplateSheet> {
  late List<String> _columns;
  late Map<String, bool> _visibility;
  @override
  void initState() {
    super.initState();
    _columns = List.from(widget.initialColumns);
    _visibility = Map.from(widget.initialVisibility);
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BtSheetHeader(
              title: 'Customize columns',
              subtitle: '${_visibility.values.where((v) => v).length} of ${_columns.length} shown · drag ≡ to reorder',
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Bt.rCard),
                    border: Border.all(color: Bt.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    itemCount: _columns.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final String item = _columns.removeAt(oldIndex);
                        _columns.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final col = _columns[index];
                      final isVisible = _visibility[col] ?? true;
                      return Material(
                        key: ValueKey(col),
                        color: Bt.card,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (index > 0) const Divider(height: 1, indent: 16, color: Bt.line),
                            SizedBox(
                              height: 52,
                              child: Row(children: [
                                const SizedBox(width: 16),
                                Expanded(child: Text(col, style: BtText.body(context, color: isVisible ? Bt.ink : Bt.ink3))),
                                BtSwitch(
                                  value: isVisible,
                                  onChanged: (val) => setState(() => _visibility[col] = val),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const SizedBox(width: 48, height: 52, child: Icon(Icons.drag_handle_rounded, color: Bt.ink3)),
                                ),
                              ]),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: BtButton(
                      label: 'Reset to default',
                      variant: BtButtonVariant.secondary,
                      onPressed: () {
                        setState(() {
                          _columns = [
                            'Date',
                            'Project',
                            'Floor',
                            'Phase',
                            'Activity',
                            'Type',
                            'Name',
                            'Category / Trade',
                            'Subtype',
                            'Brand',
                            'Supplier / Operator',
                            'Quantity',
                            'Unit',
                            'Rate',
                            'Overtime',
                            'IsWithGst',
                            'GstPercentage',
                            'Payment Status',
                            'Notes',
                          ];
                          _visibility = {for (var c in _columns) c: true};
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: BtButton(
                      label: 'Apply Changes',
                      onPressed: () {
                        Navigator.pop(context, {
                          'columns': _columns,
                          'visibility': _visibility,
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────── CSV import (Design V2 · CSV-Import board)

/// Vertical dashed timeline holding the three import steps.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});
  final List<Widget> steps;
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedRail(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 26),
          steps[i],
        ],
      ]),
    );
  }
}

class _DashedRail extends CustomPainter {
  const _DashedRail();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Bt.inputBorder
      ..strokeWidth = 1.5;
    const x = 14.0;
    for (double y = 32; y < size.height - 24; y += 8) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 4), p);
    }
  }

  @override
  bool shouldRepaint(_DashedRail oldDelegate) => false;
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.number, required this.title, required this.child, this.active = false});
  final int number;
  final String title;
  final Widget child;
  final bool active;
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Bt.ink : Bt.card,
          borderRadius: BorderRadius.circular(9),
          border: active ? null : Border.all(color: Bt.inputBorder, width: 1.5),
        ),
        child: Text(number.toString().padLeft(2, '0'), style: BtText.mono(context, color: active ? Bt.bone : Bt.ink2, size: 11)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(title, style: BtText.body(context, weight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    ]);
  }
}

/// Mini spreadsheet illustration: the first visible template columns as the
/// header, with empty rows sliding in (no fake data).
class _MiniSheet extends StatelessWidget {
  const _MiniSheet({required this.columns});
  final List<String> columns;
  @override
  Widget build(BuildContext context) {
    final cols = columns.take(4).toList();
    if (cols.isEmpty) return const SizedBox.shrink();
    final mono = BtText.mono(context, size: 9.5);
    Widget row(List<Widget> cells, {bool header = false}) => DecoratedBox(
          decoration: BoxDecoration(
            color: header ? Bt.ink.withValues(alpha: .05) : Bt.card,
            border: header ? null : const Border(top: BorderSide(color: Bt.line)),
          ),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < cells.length; i++)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(border: i < cells.length - 1 ? const Border(right: BorderSide(color: Bt.line)) : null),
                    child: cells[i],
                  ),
                ),
            ]),
          ),
        );
    return ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Bt.inputBorder)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          row([for (final c in cols) Text(c.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: mono.copyWith(color: Bt.ink))], header: true),
          for (var r = 0; r < 3; r++)
            BtReveal(
              index: r + 1,
              distance: 0,
              child: _SlideIn(
                delay: r,
                child: row([
                  for (var c = 0; c < cols.length; c++)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: const [.8, .55, .7, .45, .65][(r + c) % 5],
                        child: Container(height: 6, decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(3))),
                      ),
                    ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Slides a row in from the right once (CSV board `slideL`).
class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.child, required this.delay});
  final Widget child;
  final int delay;
  @override
  Widget build(BuildContext context) {
    if (Bt.reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + 150 * delay),
      curve: Bt.ease,
      child: child,
      builder: (_, t, c) => t >= 1 ? c! : Transform.translate(offset: Offset(24 * (1 - t), 0), child: c),
    );
  }
}

/// Dashed upload drop-zone (tap to pick a CSV).
class _UploadDrop extends StatelessWidget {
  const _UploadDrop({required this.uploading, required this.onTap});
  final bool uploading;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return BtPressable(
      onTap: onTap,
      scale: .98,
      semanticLabel: uploading ? 'Uploading' : 'Upload CSV File',
      child: CustomPaint(
        painter: const _DashedBox(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: bt.accentSoft, borderRadius: BorderRadius.circular(Bt.rTile)),
              alignment: Alignment.center,
              child: uploading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: bt.accentInk))
                  : Icon(Icons.upload_file_rounded, size: 22, color: bt.accentInk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(uploading ? 'Uploading…' : 'Upload CSV File', style: BtText.body(context, weight: FontWeight.w600)),
                Text("We'll show what imported and what didn't", style: BtText.caption(context, color: Bt.ink2)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DashedBox extends CustomPainter {
  const _DashedBox();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Bt.inputBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, (d + 5).clamp(0, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox oldDelegate) => false;
}

/// Non-dismissible progress dialog shown while rows are parsed/uploaded.
class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({required this.text, required this.value});
  final String text;
  final double value;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Bt.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: BtBrickLoader()),
          const SizedBox(height: 18),
          Text('Importing Entries', textAlign: TextAlign.center, style: BtText.d3(context)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: BtText.num(BtText.subhead(context))),
          const SizedBox(height: 16),
          BtProgress(value: value),
        ]),
      ),
    );
  }
}

/// Import results: totals, per-type breakdown and every detail/error line.
class _ImportResultsDialog extends StatelessWidget {
  const _ImportResultsDialog({
    required this.successCount,
    required this.failedCount,
    required this.materialCount,
    required this.labourCount,
    required this.equipmentCount,
    required this.errorMessages,
  });
  final int successCount;
  final int failedCount;
  final int materialCount;
  final int labourCount;
  final int equipmentCount;
  final List<String> errorMessages;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, int value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Bt.ground, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: BtText.mono(context)),
              const SizedBox(height: 4),
              Text('$value', style: BtText.d2(context, color: color)),
            ]),
          ),
        );
    return Dialog(
      backgroundColor: Bt.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Import Results', style: BtText.d3(context)),
                const SizedBox(height: 2),
                Text('Total rows processed: ${successCount + failedCount}', style: BtText.num(BtText.caption(context))),
                const SizedBox(height: 16),
                Row(children: [
                  stat('Imported', successCount, Bt.green),
                  const SizedBox(width: 8),
                  stat('Failed', failedCount, failedCount > 0 ? Bt.red : Bt.ink3),
                ]),
                const SizedBox(height: 12),
                BtValueRow(label: 'Materials', value: '$materialCount'),
                BtValueRow(label: 'Labour', value: '$labourCount'),
                BtValueRow(label: 'Equipment', value: '$equipmentCount'),
                if (errorMessages.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('DETAILS / ERRORS', style: BtText.mono(context, color: Bt.red)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Bt.redSoft, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final msg in errorMessages)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(msg, style: BtText.caption(context, color: Bt.red)),
                          ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
            child: BtButton(label: 'OK', onPressed: () => Navigator.pop(context)),
          ),
        ]),
      ),
    );
  }
}
