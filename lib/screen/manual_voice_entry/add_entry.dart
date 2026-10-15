import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
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
      });
    }
    if (RoleManager.canAddEntries) {
      items.add({
        'icon': Icons.people,
        'title': 'Labour',
        'subtitle':
            'Track crew hours, specialized trade performance, and site presence.',
        'type': 'labour',
      });
    }
    if (RoleManager.canManageEquipmentMaster) {
      items.add({
        'icon': Icons.precision_manufacturing,
        'title': 'Equipment',
        'subtitle':
            'Record heavy machinery runtime, fuel logs, and maintenance events.',
        'type': 'equipment',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${type == "all" ? "All" : type[0].toUpperCase() + type.substring(1)} template downloaded successfully!',
            ),
            backgroundColor: const Color(0xFF067647),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: const Color(0xFFC01048),
          ),
        );
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
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Row(
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(width: 16),
                    Text(
                      'Importing Entries',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(progressText, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: const Color(0xFFEEF1F5),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ],
                ),
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Import Results',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total rows processed: ${successCount + failedCount}'),
                    const SizedBox(height: 8),
                    Text(
                      'Successfully imported: $successCount',
                      style: const TextStyle(
                        color: Color(0xFF067647),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• Materials: $materialCount'),
                          Text('• Labour: $labourCount'),
                          Text('• Equipment: $equipmentCount'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed: $failedCount',
                      style: TextStyle(
                        color: failedCount > 0 ? const Color(0xFFC01048) : const Color(0xFF667085),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (errorMessages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Details/Errors:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.maxFinite,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Bt.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: errorMessages
                              .map(
                                (msg) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    msg,
                                    style: TextStyle(
                                      color: Colors.red[800],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: const Color(0xFFC01048),
          ),
        );
      }
    } finally {
      setState(() => _isUploadingCsv = false);
    }
  }
  Widget _buildCsvImportCard(BuildContext context) {
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
          const BtSectionHeader(title: 'Import many from a spreadsheet'),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Import Materials, Labour, or Equipment entries. Download the template, fill it, and upload the file.',
              style: BtText.subhead(context),
            ),
          ),
          BtGroup(
            children: [
              BtRow(
                leading: const BtTile(icon: Icons.download_rounded),
                title: 'Download Template',
                subtitle: 'CSV with the columns you chose',
                showChevron: true,
                onTap: _isUploadingCsv ? null : () => _downloadCsvTemplate('all'),
              ),
              Showcase(
                key: _csvKey,
                title: 'Customize Template',
                description: 'You can adjust which columns appear in the CSV.',
                child: BtRow(
                  leading: const BtTile(icon: Icons.view_column_outlined),
                  title: 'Customize Template Columns',
                  subtitle: 'Choose, hide and reorder columns',
                  showChevron: true,
                  onTap: _isUploadingCsv ? null : _openCustomizeColumnsSheet,
                ),
              ),
              BtRow(
                leading: _isUploadingCsv
                    ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                    : const BtTile(icon: Icons.upload_file_rounded),
                title: _isUploadingCsv ? 'Uploading…' : 'Upload CSV File',
                titleColor: context.bt.brand,
                titleWeight: FontWeight.w600,
                subtitle: 'Each row becomes an entry',
                onTap: _isUploadingCsv ? null : _uploadCsv,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Bt.ink3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'If you skip an optional column in a row, type "###" instead of leaving it blank so the file parses correctly.',
                    style: BtText.caption(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: Bt.ground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (canPop)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BtIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    semantic: 'Back',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ),
            BtLargeHeader(
              title: 'Add entry',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Bt.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Select the entry type to log for the current shift.', style: BtText.body(context, color: Bt.ink2)),
                  const SizedBox(height: 16),
                  BtGroup(
                    children: List.generate(_entries.length, (i) => _entryCard(context, i)),
                  ),
                  const SizedBox(height: 32),
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

    Widget cardContent = BtRow(
      leading: BtTypeTile(type: type),
      title: entry['title'] as String,
      subtitle: entry['subtitle'] as String,
      subtitleMaxLines: 2,
      titleWeight: FontWeight.w600,
      minHeight: 72,
      showChevron: true,
      onTap: () => _navigateToContext(context, type),
    );

    if (showcaseKey != null) {
      return Showcase(
        key: showcaseKey,
        description: description,
        tooltipBackgroundColor: const Color(0xFF1E1E2C),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template customization applied! Ready to download.'),
            backgroundColor: AppColors.primary,
          ),
        );
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
                      label: 'Reset',
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

