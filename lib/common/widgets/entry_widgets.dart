import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_gradients.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/models/construction_models.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/models/phase_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
const Map<String, List<String>> kInventoryUnits = {
  'Weight': ['kg', 'ton', 'gram'],
  'Volume': ['litre', 'm³', 'cum'],
  'Count': ['pcs', 'nos', 'bags', 'boxes', 'rolls', 'sheets'],
  'Length': ['ft', 'sq.ft', 'meter', 'rmt'],
  'Construction': ['bundle', 'drum', 'pallet', 'set', 'coil'],
};
const Map<String, List<String>> kLabourUnits = {
  'Time Based': ['Day', 'Hour', 'Week', 'Month'],
  'Area Based': ['Sq ft', 'Sq meter', 'Rmt'],
  'Job Based': ['Job Basis', 'Contract', 'Lump Sum'],
};
const Map<String, List<String>> kEquipmentUnits = {
  'Time Based': ['Hour', 'Day', 'Week', 'Month'],
  'Trip Based': ['Trip', 'Load', 'Shift'],
  'Fixed': ['Job Basis', 'Lump Sum'],
};
const List<String> kAllInventoryUnits = [
  'kg',
  'ton',
  'gram',
  'litre',
  'm³',
  'cum',
  'pcs',
  'nos',
  'bags',
  'boxes',
  'rolls',
  'sheets',
  'ft',
  'sq.ft',
  'meter',
  'rmt',
  'bundle',
  'drum',
  'pallet',
  'set',
  'coil',
];
String normalizeUnit(String raw) {
  final s = raw.trim().toLowerCase();
  const aliases = <String, String>{
    'kgs': 'kg',
    'kilo': 'kg',
    'kilos': 'kg',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'tons': 'ton',
    'tonne': 'ton',
    'tonnes': 'ton',
    'grams': 'gram',
    'gm': 'gram',
    'ltr': 'litre',
    'lts': 'litre',
    'litres': 'litre',
    'liter': 'litre',
    'liters': 'litre',
    'cbm': 'm³',
    'cu.m': 'm³',
    'cu m': 'm³',
    'cum': 'cum',
    'piece': 'pcs',
    'pieces': 'pcs',
    'pc': 'pcs',
    'number': 'nos',
    'numbers': 'nos',
    'no': 'nos',
    'bag': 'bags',
    'box': 'boxes',
    'roll': 'rolls',
    'sheet': 'sheets',
    'feet': 'ft',
    'foot': 'ft',
    'sqft': 'sq.ft',
    'sq ft': 'sq.ft',
    'sft': 'sq.ft',
    'mtr': 'meter',
    'meters': 'meter',
    'metres': 'meter',
    'metre': 'meter',
    'rm': 'rmt',
    'running meter': 'rmt',
    'bundles': 'bundle',
    'drums': 'drum',
    'pallets': 'pallet',
    'sets': 'set',
    'coils': 'coil',
  };
  return aliases[s] ?? s;
}
const _kBlue = AppColors.primary;
const _kGray = AppColors.textLight;
const _kDark = AppColors.textDark;
const _kRed = AppColors.error;
class EntrySectionCard extends StatelessWidget {
  const EntrySectionCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 16),
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEBF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
class EntryCardHeader extends StatelessWidget {
  const EntryCardHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _kBlue, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _kDark,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: _kGray),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
class EntryFieldLabel extends StatelessWidget {
  const EntryFieldLabel(this.label, {super.key, this.required = false});
  final String label;
  final bool required;
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: _kBlue,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          letterSpacing: 0.4,
          fontFamily: 'Roboto',
        ),
        children: required
            ? [
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: _kRed),
                ),
              ]
            : [],
      ),
    );
  }
}
class EntryUnderlineField extends StatelessWidget {
  const EntryUnderlineField({
    super.key,
    required this.controller,
    this.hint = '',
    this.prefix,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.error,
  });
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final String? suffix;
  final TextInputType keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final String? error;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: error != null ? _kRed : _kBlue, width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (prefix != null) ...[
                Text(
                  prefix!,
                  style: const TextStyle(
                    color: _kGray,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  readOnly: readOnly,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(color: _kGray),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _kDark,
                  ),
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Text(
                  suffix!,
                  style: const TextStyle(
                    color: _kGray,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          if (error != null) EntryErrorText(error!),
        ],
      ),
    );
  }
}
class EntryNotesField extends StatelessWidget {
  const EntryNotesField({super.key, required this.controller, this.hint});
  final TextEditingController controller;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCCFE8), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: hint ?? 'Add any site notes or remarks...',
          hintStyle: const TextStyle(color: _kGray, fontSize: 13.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _kDark,
        ),
      ),
    );
  }
}
class EntryDropdownField<T> extends StatelessWidget {
  const EntryDropdownField({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.error,
  });
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final String? error;
  @override
  Widget build(BuildContext context) {
    final bool hasValue = items.any((item) => item.value == value);
    final T? safeValue = hasValue ? value : null;
    final borderColor = error != null
        ? _kRed
        : enabled
        ? _kBlue
        : _kGray;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: safeValue,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: enabled ? _kBlue : _kGray,
                ),
                hint: Text(
                  hint,
                  style: const TextStyle(
                    color: _kGray,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kDark,
                ),
                items: enabled ? items : <DropdownMenuItem<T>>[],
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
        if (error != null) EntryErrorText(error!),
      ],
    );
  }
}
class UnitSelectorField extends StatelessWidget {
  const UnitSelectorField({
    super.key,
    required this.value,
    required this.onChanged,
    this.units,
    this.hint = 'Select Unit',
    this.error,
  });
  final String? value;
  final ValueChanged<String?> onChanged;
  final Map<String, List<String>>? units;
  final String hint;
  final String? error;
  @override
  Widget build(BuildContext context) {
    final bool hasValue = value != null && value!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _showUnitSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: error != null ? _kRed : _kBlue,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value! : hint,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                      color: hasValue ? _kDark : _kGray,
                    ),
                  ),
                ),
                if (hasValue)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.close_rounded, size: 18, color: _kGray),
                    ),
                  )
                else
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _kBlue,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
        if (error != null) EntryErrorText(error!),
      ],
    );
  }
  void _showUnitSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UnitPickerSheet(
        currentValue: value,
        units: units ?? kInventoryUnits,
        onSelected: (u) => onChanged(u),
      ),
    );
  }
}
class _UnitPickerSheet extends StatefulWidget {
  const _UnitPickerSheet({
    required this.currentValue,
    required this.onSelected,
    required this.units,
  });
  final String? currentValue;
  final ValueChanged<String> onSelected;
  final Map<String, List<String>> units;
  @override
  State<_UnitPickerSheet> createState() => _UnitPickerSheetState();
}
class _UnitPickerSheetState extends State<_UnitPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
  Map<String, List<String>> get _filtered {
    if (_query.isEmpty) return widget.units;
    final q = _query.toLowerCase();
    final result = <String, List<String>>{};
    widget.units.forEach((cat, units) {
      final matched = units.where((u) => u.toLowerCase().contains(q)).toList();
      if (matched.isNotEmpty) result[cat] = matched;
    });
    return result;
  }
  void _pick(BuildContext ctx, String unit) {
    Navigator.pop(ctx);
    widget.onSelected(unit);
  }
  Future<void> _addCustom(BuildContext ctx) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Custom Unit',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. coil, container, machine-hrs',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty && ctx.mounted) {
      _pick(ctx, normalizeUnit(ctrl.text.trim()));
    }
    ctrl.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final botPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F5FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: botPad),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFBDBEE8),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Unit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _kDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addCustom(context),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: _kBlue,
                    ),
                    label: const Text(
                      'Custom',
                      style: TextStyle(
                        color: _kBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search units...',
                  hintStyle: const TextStyle(color: _kGray, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: _kGray, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.search_off, color: _kGray, size: 36),
                          const SizedBox(height: 8),
                          const Text(
                            'No matching unit found.',
                            style: TextStyle(color: _kGray),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => _addCustom(context),
                            icon: const Icon(
                              Icons.add,
                              color: _kBlue,
                              size: 18,
                            ),
                            label: const Text(
                              'Add Custom Unit',
                              style: TextStyle(
                                color: _kBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        for (final entry in filtered.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 6),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _kGray,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.value.map((unit) {
                              final isSelected = widget.currentValue == unit;
                              return GestureDetector(
                                onTap: () => _pick(context, unit),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected ? _kBlue : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? _kBlue
                                          : const Color(0xFFDDE0F0),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    unit,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : _kDark,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
class ExecutionContextCard extends StatelessWidget {
  const ExecutionContextCard({
    super.key,
    required this.selectedProjectId,
    required this.selectedFloor,
    required this.selectedPhase,
    required this.selectedActivity,
    required this.onProjectChanged,
    required this.onFloorChanged,
    required this.onPhaseChanged,
    required this.onActivityChanged,
    this.projectError,
    this.floorError,
    this.phaseError,
    this.activityError,
  });
  final String? selectedProjectId;
  final String? selectedFloor;
  final dynamic selectedPhase;
  final String? selectedActivity;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String?> onFloorChanged;
  final ValueChanged<dynamic> onPhaseChanged;
  final ValueChanged<String?> onActivityChanged;
  final String? projectError;
  final String? floorError;
  final String? phaseError;
  final String? activityError;
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) {
        final provider = ctx.watch<ProjectProvider>();
        final projects = provider.projects;
        final ProjectModel? selProject = selectedProjectId == null
            ? null
            : projects.cast<ProjectModel?>().firstWhere(
                (p) => p?.id == selectedProjectId,
                orElse: () => null,
              );
        const List<String> defaultFloors = [
          'Basement',
          'Ground Floor',
          '1st Floor',
          '2nd Floor',
          '3rd Floor',
          'Terrace',
        ];
        final List<String> floors = (selProject?.floors?.isNotEmpty == true)
            ? List<String>.from(selProject!.floors!)
            : (selProject != null ? defaultFloors : <String>[]);
        if (selectedFloor != null && !floors.contains(selectedFloor)) {
          floors.insert(0, selectedFloor!);
        }
        String? selPhaseName;
        if (selectedPhase is String) {
          selPhaseName = selectedPhase as String;
        } else if (selectedPhase is ProjectPhase) {
          selPhaseName = selectedPhase.phaseName;
        } else if (selectedPhase is PhaseModel) {
          selPhaseName = selectedPhase.name;
        } else if (selectedPhase is Map) {
          selPhaseName =
              (selectedPhase['phaseName'] ??
                      selectedPhase['name'] ??
                      selectedPhase['title'] ??
                      selectedPhase['id'] ??
                      selectedPhase['_id'] ??
                      '')
                  .toString();
        } else if (selectedPhase != null) {
          try {
            selPhaseName =
                (selectedPhase.phaseName ??
                        selectedPhase.name ??
                        selectedPhase.title)
                    .toString();
          } catch (_) {
            selPhaseName = selectedPhase.toString();
          }
        }
        final List<String> projectPhaseNames = (selProject?.selectedPhases ??
                const <ProjectPhase>[])
            .where((p) => p.activities.isNotEmpty)
            .map((p) => p.phaseName)
            .toList();
        final List<String> legacyPhaseNames =
            List<String>.from(selProject?.selectedPhaseNames ?? const []);
        final Set<String> mergedPhaseNames = <String>{
          ...projectPhaseNames,
          ...legacyPhaseNames,
        };
        if (mergedPhaseNames.isEmpty) {
          mergedPhaseNames
              .addAll(buildDefaultPhases().map((p) => p.name));
        }
        List<String> visiblePhaseNames = mergedPhaseNames.toList();
        List<String> activities;
        final ProjectPhase? selPhase = selPhaseName != null
            ? (selProject?.selectedPhases ?? const <ProjectPhase>[])
                  .cast<ProjectPhase?>()
                  .firstWhere(
                    (p) => p?.phaseName == selPhaseName,
                    orElse: () => null,
                  )
            : null;
        if (selPhase != null) {
          activities = selPhase.activities.map((a) => a.name).toList();
        } else {
          final ConstructionPhase? defaultSelPhase = selPhaseName != null
              ? buildDefaultPhases().cast<ConstructionPhase?>().firstWhere(
                  (p) => p?.name == selPhaseName,
                  orElse: () => null,
                )
              : null;
          activities = defaultSelPhase != null
              ? defaultSelPhase.allActivities
                    .map<String>((a) => a.name)
                    .toList()
              : <String>[];
        }
        if (selPhaseName != null && !visiblePhaseNames.contains(selPhaseName)) {
          visiblePhaseNames.insert(0, selPhaseName);
        }
        if (selectedActivity != null &&
            !activities.contains(selectedActivity)) {
          activities.insert(0, selectedActivity!);
        }
        return EntrySectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EntryCardHeader(
                icon: Icons.location_on_outlined,
                title: 'Execution Context',
                subtitle: 'Where is this work happening?',
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFF0EEF8), thickness: 1),
              const SizedBox(height: 16),
              const EntryFieldLabel('Project', required: true),
              const SizedBox(height: 8),
              EntryDropdownField<String>(
                value: selectedProjectId,
                hint: 'Select project',
                items: projects
                    .map(
                      (p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(p.name),
                      ),
                    )
                    .toList(),
                onChanged: onProjectChanged,
                error: projectError,
              ),
              if (projectError != null) EntryErrorText(projectError!),
              const SizedBox(height: 18),
              const EntryFieldLabel('Floor / Zone', required: true),
              const SizedBox(height: 8),
              EntryDropdownField<String>(
                value: selectedFloor,
                hint: selectedProjectId == null
                    ? 'Select project first'
                    : 'Select floor',
                enabled: selectedProjectId != null,
                items: floors
                    .map(
                      (f) => DropdownMenuItem<String>(value: f, child: Text(f)),
                    )
                    .toList(),
                onChanged: onFloorChanged,
                error: floorError,
              ),
              if (floorError != null) EntryErrorText(floorError!),
              const SizedBox(height: 18),
              const EntryFieldLabel('Phase', required: true),
              const SizedBox(height: 8),
              EntryDropdownField<String>(
                value: visiblePhaseNames.contains(selPhaseName)
                    ? selPhaseName
                    : null,
                hint: selectedFloor == null
                    ? 'Select floor first'
                    : visiblePhaseNames.isEmpty
                    ? 'No phases configured for this project'
                    : 'Select phase',
                enabled: selectedFloor != null && visiblePhaseNames.isNotEmpty,
                items: visiblePhaseNames
                    .map(
                      (n) => DropdownMenuItem<String>(value: n, child: Text(n)),
                    )
                    .toList(),
                onChanged: onPhaseChanged,
                error: phaseError,
              ),
              if (phaseError != null) EntryErrorText(phaseError!),
              const SizedBox(height: 18),
              const EntryFieldLabel('Activity', required: true),
              const SizedBox(height: 8),
              EntryDropdownField<String>(
                value: activities.contains(selectedActivity)
                    ? selectedActivity
                    : null,
                hint: selPhaseName == null
                    ? 'Select phase first'
                    : activities.isEmpty
                    ? 'No activities in this phase'
                    : 'Select activity',
                enabled: selPhaseName != null && activities.isNotEmpty,
                items: activities
                    .map(
                      (a) => DropdownMenuItem<String>(value: a, child: Text(a)),
                    )
                    .toList(),
                onChanged: onActivityChanged,
                error: activityError,
              ),
              if (activityError != null) EntryErrorText(activityError!),
            ],
          ),
        );
      },
    );
  }
}
class CostSummaryCard extends StatelessWidget {
  const CostSummaryCard({
    super.key,
    required this.totalAmount,
    required this.label,
    required this.subtotals,
  });
  final double totalAmount;
  final String label;
  final List<(String, String)> subtotals;
  @override
  Widget build(BuildContext context) {
    return EntrySectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EntryCardHeader(
            icon: Icons.calculate_outlined,
            title: 'Cost Summary',
            subtitle: 'Live calculated estimate',
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF0EEF8), thickness: 1),
          const SizedBox(height: 16),
          ...subtotals.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.$1,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      entry.$2,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _kDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFF0EEF8), thickness: 1),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF173EEA).withValues(alpha: 0.08),
                  const Color(0xFFB137FF).withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _kBlue.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kGray,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatCurrency(totalAmount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kBlue,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _kBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.calculate_outlined,
                    color: _kBlue,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class VoiceParseCard extends StatelessWidget {
  const VoiceParseCard({
    super.key,
    required this.transcript,
    this.confidence = 98.4,
    this.timestamp,
    this.entryTypeLabel = 'Material',
  });
  final String transcript;
  final double confidence;
  final String? timestamp;
  final String entryTypeLabel;
  @override
  Widget build(BuildContext context) {
    final ts = timestamp ?? TimeOfDay.now().format(context);
    return EntrySectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF173EEA), Color(0xFFB137FF)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Parsed from Voice',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Confidence: ${confidence.toStringAsFixed(1)}%  â€¢  $ts',
                      style: const TextStyle(fontSize: 12, color: _kGray),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F9F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF15803D),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entryTypeLabel.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF0EEF8), thickness: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.format_align_left, color: _kBlue, size: 14),
              const SizedBox(width: 6),
              const Text(
                'VOICE TRANSCRIPT',
                style: TextStyle(
                  color: _kBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E5FF)),
            ),
            child: Text(
              '"$transcript"',
              style: const TextStyle(
                color: _kDark,
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                height: 1.65,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 13, color: _kGray),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Fields have been auto-filled from voice. Review and edit before confirming.',
                  style: TextStyle(fontSize: 11.5, color: _kGray),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class EntrySubmitButton extends StatelessWidget {
  const EntrySubmitButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedOpacity(
        opacity: isLoading ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            gradient: AppGradients.primaryButton,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: _kBlue.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: Colors.white, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}
class EntryErrorText extends StatelessWidget {
  const EntryErrorText(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: const TextStyle(
          color: _kRed,
          fontSize: 11.5,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
enum PaymentStatus { paid, partial, pending, overdue }
class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({super.key, required this.status});
  final PaymentStatus status;
  String get _label {
    switch (status) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.partial:
        return 'Partial';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.overdue:
        return 'Overdue';
    }
  }
  Color get _fg {
    switch (status) {
      case PaymentStatus.paid:
        return const Color(0xFF15803D);
      case PaymentStatus.partial:
        return const Color(0xFF1D4ED8);
      case PaymentStatus.pending:
        return const Color(0xFFDC2626);
      case PaymentStatus.overdue:
        return const Color(0xFFDC2626);
    }
  }
  Color get _bg {
    switch (status) {
      case PaymentStatus.paid:
        return const Color(0xFFDCFCE7);
      case PaymentStatus.partial:
        return const Color(0xFFEFF6FF);
      case PaymentStatus.pending:
        return const Color(0xFFFEE2E2);
      case PaymentStatus.overdue:
        return const Color(0xFFFEE2E2);
    }
  }
  IconData get _icon {
    switch (status) {
      case PaymentStatus.paid:
        return Icons.check_circle_outline;
      case PaymentStatus.partial:
        return Icons.pie_chart_outline;
      case PaymentStatus.pending:
        return Icons.hourglass_empty_outlined;
      case PaymentStatus.overdue:
        return Icons.warning_amber_outlined;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, color: _fg, size: 16),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              color: _fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
class PaymentSummaryBanner extends StatelessWidget {
  const PaymentSummaryBanner({
    super.key,
    required this.totalBilled,
    required this.totalPaid,
    required this.pendingCount,
    required this.onSettle,
  });
  final double totalBilled;
  final double totalPaid;
  final int pendingCount;
  final VoidCallback onSettle;
  @override
  Widget build(BuildContext context) {
    final outstanding = (totalBilled - totalPaid).clamp(0.0, double.infinity);
    final paidRatio = totalBilled > 0
        ? (totalPaid / totalBilled).clamp(0.0, 1.0)
        : 0.0;
    final pctLabel = '${(paidRatio * 100).toStringAsFixed(0)}%';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173EEA), Color(0xFFB137FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173EEA).withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PAYMENT OVERVIEW',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(totalPaid),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of ${formatCurrency(totalBilled)} billed · $pctLabel settled',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onSettle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.payment_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Settle',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: paidRatio,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip(Icons.check_circle_outline, '$pctLabel paid'),
              const SizedBox(width: 8),
              _chip(
                Icons.schedule_outlined,
                '${formatCurrency(outstanding)} due',
              ),
              if (pendingCount > 0) ...[
                const SizedBox(width: 8),
                _chip(Icons.receipt_outlined, '$pendingCount pending'),
              ],
            ],
          ),
        ],
      ),
    );
  }
  Widget _chip(IconData icon, String label) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
Future<Map<String, dynamic>?> showPaymentSheet(
  BuildContext context, {
  required String entryTitle,
  required String entryRef,
  double totalAmount = 0,
  double alreadyPaid = 0,
  String vendorName = '',
  String category = '',
  double? initialAmount,
  String? initialMethod,
  String? initialNote,
  DateTime? initialDate,
}) {
  final amountCtrl = TextEditingController(text: initialAmount != null ? initialAmount.toString() : '');
  final noteCtrl = TextEditingController(text: initialNote ?? '');
  final outstanding = (totalAmount - alreadyPaid).clamp(0.0, double.infinity);
  PaymentStatus selectedStatus = outstanding > 0
      ? (alreadyPaid > 0 ? PaymentStatus.partial : PaymentStatus.pending)
      : PaymentStatus.paid;
  String selectedMethod = initialMethod ?? 'UPI';
  String? amountError;
  String? uploadedReceipt;
  String? uploadedReceiptDataUri;
  DateTime selectedPaymentDate = initialDate ?? DateTime.now();
  bool requestEsign = false;
  final emailCtrl = TextEditingController();
  bool isEsignPolling = false;
  bool isEsignCompleted = false;
  String esignStatusText = '';
  Future<void> startEsignFlow(StateSetter ss) async {
    final amt = double.tryParse(amountCtrl.text);
    if (amt == null || amt <= 0) {
      ss(() => amountError = 'Please enter a valid amount before requesting an E-Signature.');
      return;
    }
    if (emailCtrl.text.isEmpty) return;
    ss(() {
      isEsignPolling = true;
      esignStatusText = 'Sending request...';
    });
    final meta = {
      'projectName': entryTitle,
      'type': category,
      'amount': double.tryParse(amountCtrl.text) ?? 0.0,
      'paymentMethod': selectedMethod,
      'notes': noteCtrl.text.trim(),
      'date': selectedPaymentDate.toUtc().toIso8601String(),
    };
    final res = await ApiService.requestEsignature(emailCtrl.text.trim(), meta);
    if (res == null || res['requestId'] == null) {
      ss(() {
        isEsignPolling = false;
        esignStatusText = 'Failed to send request';
      });
      return;
    }
    ss(() {
      esignStatusText = 'Waiting for client to sign...';
    });
    final reqId = res['requestId'];
    while (isEsignPolling) {
      await Future.delayed(const Duration(seconds: 3));
      if (!isEsignPolling) break;
      final statusRes = await ApiService.checkEsignatureStatus(reqId);
      if (statusRes != null && statusRes['status'] == 'signed') {
        ss(() {
          isEsignPolling = false;
          isEsignCompleted = true;
          uploadedReceiptDataUri = statusRes['signatureData'];
          esignStatusText = 'Signature captured!';
        });
        break;
      }
    }
  }
  const pMethods = [
    {'label': 'UPI', 'icon': Icons.phone_android_outlined},
    {'label': 'Cash', 'icon': Icons.money_outlined},
    {'label': 'Bank Transfer', 'icon': Icons.account_balance_outlined},
    {'label': 'Card', 'icon': Icons.credit_card_outlined},
    {'label': 'Cheque', 'icon': Icons.description_outlined},
  ];
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) {
        final inset = MediaQuery.of(ctx).viewInsets.bottom;
        final botPad = MediaQuery.of(ctx).padding.bottom;
        String helperText;
        if (selectedStatus == PaymentStatus.paid) {
          helperText = 'Full settlement — ${formatCurrency(outstanding)}';
          if (amountCtrl.text.isEmpty || amountCtrl.text == '0') {
            amountCtrl.text = outstanding.toStringAsFixed(0);
          }
        } else if (selectedStatus == PaymentStatus.pending) {
          helperText = 'No payment recorded';
          amountCtrl.text = '0';
        } else {
          final entered = parseAmount(amountCtrl.text) ?? 0;
          final rem = (outstanding - entered).clamp(0.0, double.infinity);
          helperText = rem > 0
              ? 'Remaining: ${formatCurrency(rem)}'
              : 'Full settlement via partial recording';
        }
        return LayoutBuilder(
          builder: (ctx, constraints) {
            final parentW = constraints.maxWidth;
            final chipW = (parentW - 40) / 2;
            final fullW = parentW - 32;
            return Padding(
              padding: EdgeInsets.only(bottom: inset),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F5FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFBDBEE8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEEFFF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Color(0xFF173EEA),
                                  size: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Fulfillment & Payment',
                                style: TextStyle(
                                  color: Color(0xFF1E1E2E),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF173EEA), Color(0xFF6B2FD9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'FULFILLMENT & PAYMENT',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entryTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (category.isNotEmpty ||
                                      vendorName.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        [category, vendorName]
                                            .where((s) => s.isNotEmpty)
                                            .join(' · '),
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'OUTSTANDING',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatCurrency(
                                    outstanding > 0 ? outstanding : totalAmount,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (alreadyPaid > 0)
                                  Text(
                                    '${formatCurrency(alreadyPaid)} paid',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            botPad > 0 ? 8 : 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SheetSectionLabel('PAYMENT STATUS'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _pStatusCard(
                                    ss,
                                    selectedStatus,
                                    PaymentStatus.paid,
                                    'Fully Paid',
                                    const Color(0xFF15803D),
                                    const Color(0xFFDCFCE7),
                                    (v) => ss(() {
                                      selectedStatus = v;
                                      amountError = null;
                                      amountCtrl.text = outstanding > 0
                                          ? outstanding.toStringAsFixed(0)
                                          : totalAmount.toStringAsFixed(0);
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  _pStatusCard(
                                    ss,
                                    selectedStatus,
                                    PaymentStatus.partial,
                                    'Partial',
                                    const Color(0xFFB45309),
                                    const Color(0xFFFEF3C7),
                                    (v) => ss(() {
                                      selectedStatus = v;
                                      amountError = null;
                                      final tText = outstanding > 0
                                          ? outstanding.toStringAsFixed(0)
                                          : totalAmount.toStringAsFixed(0);
                                      if (amountCtrl.text == '0' ||
                                          amountCtrl.text == tText) {
                                        amountCtrl.clear();
                                      }
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  _pStatusCard(
                                    ss,
                                    selectedStatus,
                                    PaymentStatus.pending,
                                    'Not Paid',
                                    const Color(0xFFDC2626),
                                    const Color(0xFFFEE2E2),
                                    (v) => ss(() {
                                      selectedStatus = v;
                                      amountError = null;
                                      amountCtrl.text = '0';
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const _SheetSectionLabel(
                                'ACTUAL AMOUNT PAID (₹)',
                              ),
                              const SizedBox(height: 8),
                              AnimatedOpacity(
                                opacity: selectedStatus == PaymentStatus.pending
                                    ? 0.4
                                    : 1.0,
                                duration: const Duration(milliseconds: 180),
                                child: SizedBox(
                                  height: 60,
                                  child: TextField(
                                    controller: amountCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (val) {
                                      if (val.length > 1 &&
                                          val.startsWith('0') &&
                                          !val.startsWith('0.')) {
                                        final stripped = val.replaceFirst(
                                          RegExp(r'^0+'),
                                          '',
                                        );
                                        if (stripped.isNotEmpty &&
                                            stripped != '.') {
                                          amountCtrl.text = stripped;
                                          amountCtrl.selection =
                                              TextSelection.collapsed(
                                                offset: stripped.length,
                                              );
                                          val = stripped;
                                        }
                                      }
                                      ss(() {
                                        amountError = null;
                                        final amt = parseAmount(val);
                                        if (amt == null || amt == 0) {
                                          selectedStatus =
                                              PaymentStatus.pending;
                                        } else if (outstanding > 0 &&
                                            amt >= outstanding) {
                                          selectedStatus = PaymentStatus.paid;
                                        } else if (outstanding == 0 &&
                                            amt >= totalAmount) {
                                          selectedStatus = PaymentStatus.paid;
                                        } else {
                                          selectedStatus =
                                              PaymentStatus.partial;
                                        }
                                      });
                                    },
                                    textAlignVertical: TextAlignVertical.center,
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      prefixStyle: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: _kGray,
                                      ),
                                      hintText: '0.00',
                                      hintStyle: const TextStyle(color: _kGray),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: amountError != null
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFFE2E4F6),
                                          width: 1.0,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: amountError != null
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF173EEA),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: _kDark,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 5, left: 2),
                                child: Text(
                                  amountError ?? helperText,
                                  style: TextStyle(
                                    color: amountError != null
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF6B7280),
                                    fontSize: 11,
                                    fontStyle: amountError != null
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const _SheetSectionLabel('PAYMENT METHOD'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...pMethods.take(4).map((m) {
                                    final lbl = m['label'] as String;
                                    final ico = m['icon'] as IconData;
                                    final sel = selectedMethod == lbl;
                                    return _pMethodChip(
                                      lbl,
                                      ico,
                                      sel,
                                      chipW,
                                      46,
                                      () => ss(() => selectedMethod = lbl),
                                    );
                                  }),
                                  Builder(
                                    builder: (_) {
                                      const lbl = 'Cheque';
                                      const ico = Icons.description_outlined;
                                      final sel = selectedMethod == lbl;
                                      return _pMethodChip(
                                        lbl,
                                        ico,
                                        sel,
                                        fullW,
                                        46,
                                        () => ss(() => selectedMethod = lbl),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              if (selectedMethod == 'Cash') ...[
                                const SizedBox(height: 16),
                                CheckboxListTile(
                                  title: const Text(
                                    'Request E-Signature for Cash Receipt',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark),
                                  ),
                                  value: requestEsign,
                                  onChanged: (val) => ss(() => requestEsign = val ?? false),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: const Color(0xFF173EEA),
                                ),
                                if (requestEsign)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                    child: TextField(
                                      controller: emailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: 'Client Email Address',
                                        labelStyle: const TextStyle(color: _kGray, fontSize: 13),
                                        prefixIcon: const Icon(Icons.email_outlined, color: _kGray, size: 20),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFE2E4F6)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF173EEA), width: 1.5),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 14, color: _kDark, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                            if (requestEsign && !isEsignCompleted) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: isEsignPolling ? () {
                                    ss(() => isEsignPolling = false);
                                  } : () => startEsignFlow(ss),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isEsignPolling ? Colors.red : const Color(0xFF173EEA),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(isEsignPolling ? 'Cancel Polling' : 'Send for E-Signature', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              if (esignStatusText.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(esignStatusText, style: TextStyle(color: isEsignPolling ? Colors.orange : (isEsignCompleted ? Colors.green : Colors.red), fontWeight: FontWeight.bold)),
                                )
                            ],
                            if (isEsignCompleted) ...[
                               const SizedBox(height: 8),
                               Container(
                                 padding: const EdgeInsets.all(12),
                                 decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                                 child: const Row(
                                   children: [
                                     Icon(Icons.check_circle, color: Colors.green),
                                     SizedBox(width: 8),
                                     Text('Signature successfully captured!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                   ]
                                 )
                               )
                            ],
                              ],
                              const SizedBox(height: 16),
                              const _SheetSectionLabel('PAYMENT RECEIPT'),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final attachment = await pickAttachmentDirect(
                                    ctx,
                                  );
                                  if (attachment != null) {
                                    ss(() {
                                      uploadedReceipt = attachment.name;
                                      uploadedReceiptDataUri =
                                          attachment.dataUri;
                                    });
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: uploadedReceipt != null
                                        ? const Color(0xFFF0FDF4)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: uploadedReceipt != null
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFFCCCFE8),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: uploadedReceipt != null
                                      ? Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_outline,
                                              color: Color(0xFF15803D),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                uploadedReceipt!,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFF15803D),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => ss(() {
                                                uploadedReceipt = null;
                                                uploadedReceiptDataUri = null;
                                              }),
                                              child: const Icon(
                                                Icons.close,
                                                color: Color(0xFF6B7280),
                                                size: 15,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEEEFFF),
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                              ),
                                              child: const Icon(
                                                Icons.upload_outlined,
                                                color: Color(0xFF173EEA),
                                                size: 17,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Upload Payment Receipt',
                                                  style: TextStyle(
                                                    color: _kDark,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                SizedBox(height: 1),
                                                Text(
                                                  'PNG, JPG, PDF — UPI / Bank / Cheque proof',
                                                  style: TextStyle(
                                                    color: _kGray,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const _SheetSectionLabel('PAYMENT DATE'),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: selectedPaymentDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                    builder: (c, child) => Theme(
                                      data: Theme.of(c).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF173EEA),
                                          onPrimary: Colors.white,
                                          onSurface: _kDark,
                                        ),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    ss(() => selectedPaymentDate = picked);
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFCCCFE8),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month_outlined,
                                        color: Color(0xFF173EEA),
                                        size: 19,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${selectedPaymentDate.day}/${selectedPaymentDate.month}/${selectedPaymentDate.year}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: _kDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              EntryNotesField(
                                controller: noteCtrl,
                                hint:
                                    'Transaction ID, cheque number, or remarks…',
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          botPad > 0 ? botPad : 18,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Color(0xFFE8EAFF), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(ctx),
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                      color: const Color(0xFFDDE0F0),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: _kGray,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: GestureDetector(
                                onTap: () {
                                  if (selectedStatus != PaymentStatus.pending) {
                                    final raw = amountCtrl.text.trim();
                                    final amt = parseAmount(raw);
                                    if (raw.isEmpty ||
                                        amt == null ||
                                        amt <= 0) {
                                      ss(
                                        () => amountError =
                                            'Enter a valid amount paid',
                                      );
                                      return;
                                    }
                                    if (outstanding > 0 && amt > outstanding) {
                                      ss(
                                        () => amountError =
                                            'Payment amount cannot exceed the outstanding amount.',
                                      );
                                      return;
                                    }
                                    if (outstanding <= 0) {
                                      ss(
                                        () => amountError =
                                            'No outstanding amount to pay',
                                      );
                                      return;
                                    }
                                  }
                                  final amount =
                                      selectedStatus == PaymentStatus.paid
                                      ? outstanding
                                      : selectedStatus == PaymentStatus.pending
                                      ? 0.0
                                      : (parseAmount(amountCtrl.text.trim()) ?? 0);
                                  Navigator.pop(ctx, {
                                    'amount': amount,
                                    'method': selectedMethod,
                                    'note': noteCtrl.text.trim(),
                                    'status': selectedStatus,
                                    'receipt': uploadedReceipt,
                                    'receiptDataUri': uploadedReceiptDataUri,
                                    'paymentDate': selectedPaymentDate,
                                    'requestEsign': requestEsign,
                                    'clientEmail': emailCtrl.text.trim(),
                                  });
                                },
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF173EEA),
                                        Color(0xFF6B2FD9),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF173EEA,
                                        ).withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Confirm Payment & Update Inventory',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF6B7280),
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    ),
  );
}
Widget _pStatusCard(
  StateSetter ss,
  PaymentStatus current,
  PaymentStatus value,
  String label,
  Color dotColor,
  Color bgColor,
  ValueChanged<PaymentStatus> onSelect,
) {
  final sel = current == value;
  return Expanded(
    child: GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 46,
        decoration: BoxDecoration(
          color: sel ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? dotColor : const Color(0xFFE2E4F6),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: sel ? dotColor : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
Widget _pMethodChip(
  String label,
  IconData icon,
  bool selected,
  double width,
  double height,
  VoidCallback onTap,
) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF173EEA) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF173EEA) : const Color(0xFFE2E4F6),
          width: 1.5,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF173EEA).withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: selected ? Colors.white : const Color(0xFF6B7280),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    ),
  );
}
class InvoiceAttachmentCard extends StatelessWidget {
  final PickedAttachment? attachment;
  final String? fileName;
  const InvoiceAttachmentCard({super.key, this.attachment, this.fileName});
  @override
  Widget build(BuildContext context) {
    final name = attachment?.name ?? fileName;
    final hasDoc = name != null && name.isNotEmpty;
    if (!hasDoc) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E5FF), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.upload_file_outlined,
                color: AppColors.textLight,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No document attached',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Upload invoice or bill to view',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    IconData iconData = Icons.insert_drive_file_outlined;
    Color iconColor = const Color(0xFF546E7A);
    Color iconBg = const Color(0xFFECEFF1);
    final lowerName = name.toLowerCase();
    if (attachment != null) {
      iconData = attachment!.icon;
      iconColor = attachment!.iconColor;
      iconBg = attachment!.iconBg;
    } else {
      if (lowerName.endsWith('.pdf')) {
        iconData = Icons.picture_as_pdf_outlined;
        iconColor = const Color(0xFFE53935);
        iconBg = const Color(0xFFFFEBEE);
      } else if (lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.png')) {
        iconData = Icons.image_outlined;
        iconColor = const Color(0xFF4A6CF7);
        iconBg = const Color(0xFFEEF0FF);
      } else if (lowerName.endsWith('.doc') || lowerName.endsWith('.docx')) {
        iconData = Icons.description_outlined;
        iconColor = const Color(0xFF1565C0);
        iconBg = const Color(0xFFE3F2FD);
      } else if (lowerName.endsWith('.xls') || lowerName.endsWith('.xlsx')) {
        iconData = Icons.table_chart_outlined;
        iconColor = const Color(0xFF2E7D32);
        iconBg = const Color(0xFFE8F5E9);
      }
    }
    return GestureDetector(
      onTap: () {
        if (hasDoc) {
          final String receiptData = attachment != null
              ? attachment!.dataUri
              : name;
          Navigator.pushNamed(
            context,
            '/receipt-viewer',
            arguments: {'receipt': receiptData},
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E5FF), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  (attachment == null &&
                      (name.startsWith('http://') ||
                          name.startsWith('https://')) &&
                      (lowerName.contains('.jpg') ||
                          lowerName.contains('.jpeg') ||
                          lowerName.contains('.png')))
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        name,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Icon(iconData, color: iconColor, size: 22),
                      ),
                    )
                  : Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Successfully attached',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class PaymentReceiptCard extends StatelessWidget {
  final String? fileName;
  const PaymentReceiptCard({super.key, this.fileName});
  @override
  Widget build(BuildContext context) {
    final hasDoc = fileName != null && fileName!.isNotEmpty;
    if (!hasDoc) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E5FF), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: Color(0xFF6B7280),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No payment receipt attached',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Receipt uploads via Fulfillment & Payment',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final lowerName = fileName!.toLowerCase();
    IconData iconData = Icons.receipt_long_outlined;
    Color iconColor = const Color(0xFF15803D);
    Color iconBg = const Color(0xFFDCFCE7);
    if (lowerName.endsWith('.pdf')) {
      iconData = Icons.picture_as_pdf_outlined;
      iconColor = const Color(0xFFE53935);
      iconBg = const Color(0xFFFFEBEE);
    } else if (lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png')) {
      iconData = Icons.image_outlined;
      iconColor = const Color(0xFF15803D);
      iconBg = const Color(0xFFDCFCE7);
    }
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/receipt-viewer',
        arguments: {'receipt': fileName},
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName!,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.verified,
                        color: Colors.green.shade600,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Payment proof attached',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'View',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
