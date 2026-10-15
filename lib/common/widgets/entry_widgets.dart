import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/models/construction_models.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/models/phase_model.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/design/design.dart';
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
var _kBlue = AppColors.primary;
const _kGray = AppColors.textLight;
const _kDark = AppColors.textDark;
class EntrySectionCard extends StatelessWidget {
  const EntrySectionCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 16),
    this.padding = const EdgeInsets.all(16),
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
        color: Bt.card,
        borderRadius: BorderRadius.circular(Bt.rCard),
        border: Border.all(color: Bt.line),
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
        BtTile(icon: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: BtText.headline(context)),
              if (subtitle.isNotEmpty) Text(subtitle, style: BtText.caption(context)),
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
    return Text.rich(
      TextSpan(
        text: label,
        style: BtText.subhead(context, weight: FontWeight.w500),
        children: required ? [const TextSpan(text: ' *', style: TextStyle(color: Bt.red))] : [],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          onChanged: onChanged,
          style: BtText.num(BtText.body(context, weight: FontWeight.w500)),
          decoration: btInput(
            context,
            hint: hint,
            prefixText: prefix != null ? '$prefix ' : null,
            suffixText: suffix,
          ).copyWith(
            fillColor: readOnly ? Bt.fill : Bt.card,
            enabledBorder: error != null
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: const BorderSide(color: Bt.red))
                : null,
          ),
        ),
        if (error != null) EntryErrorText(error!),
      ],
    );
  }
}
class EntryNotesField extends StatelessWidget {
  const EntryNotesField({super.key, required this.controller, this.hint});
  final TextEditingController controller;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 3,
      style: BtText.body(context),
      decoration: btInput(context, hint: hint ?? 'Add any site notes or remarks...'),
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
    final borderColor = error != null ? Bt.red : Bt.inputBorder;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: Bt.fieldH,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: enabled ? Bt.card : Bt.fill,
            borderRadius: BorderRadius.circular(Bt.rInput),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: safeValue,
              isExpanded: true,
              borderRadius: BorderRadius.circular(14),
              dropdownColor: Bt.card,
              icon: Icon(Icons.expand_more_rounded, color: enabled ? Bt.ink2 : Bt.placeholder),
              hint: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, color: Bt.placeholder)),
              style: BtText.body(context, weight: FontWeight.w500),
              items: enabled ? items : <DropdownMenuItem<T>>[],
              onChanged: enabled ? onChanged : null,
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
        Material(
          color: Bt.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rInput), side: BorderSide(color: error != null ? Bt.red : Bt.inputBorder)),
          child: InkWell(
            borderRadius: BorderRadius.circular(Bt.rInput),
            onTap: () => _showUnitSheet(context),
            child: SizedBox(
              height: Bt.fieldH,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Expanded(child: Text(hasValue ? value! : hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: hasValue ? FontWeight.w500 : FontWeight.w400, color: hasValue ? Bt.ink : Bt.placeholder))),
                  if (hasValue)
                    IconButton(
                      tooltip: 'Clear unit',
                      onPressed: () => onChanged(null),
                      icon: const Icon(Icons.close_rounded, size: 18, color: Bt.ink3),
                    )
                  else
                    const Icon(Icons.expand_more_rounded, color: Bt.ink2, size: 22),
                ]),
              ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rCard)),
        title: const Text(
          'Add Custom Unit',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
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
        color: Bt.card,
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
                  color: Bt.inputBorder,
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
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addCustom(context),
                    icon: Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: _kBlue,
                    ),
                    label: Text(
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
                  fillColor: Bt.fill,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
                            icon: Icon(
                              Icons.add,
                              color: _kBlue,
                              size: 18,
                            ),
                            label: Text(
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
                              entry.key,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _kGray,
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
                                          : const Color(0xFFE4E7EC),
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
    this.showHeader = true,
  });
  /// Hide the card's own title when the screen already asks "Where is this work happening?".
  final bool showHeader;
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
              );        final List<String> floors = (selProject?.floors?.isNotEmpty == true)
            ? List<String>.from(selProject!.floors!)
            : <String>[];
        if (floors.isNotEmpty &&
            selectedFloor != null &&
            selectedFloor!.isNotEmpty &&
            !floors.contains(selectedFloor)) {
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
              if (showHeader) ...[
                const EntryCardHeader(
                  icon: Icons.location_on_outlined,
                  title: 'Where',
                  subtitle: 'Where is this work happening?',
                ),
                const SizedBox(height: 16),
              ],
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
              const EntryFieldLabel('Floor / Zone', required: false),
              const SizedBox(height: 8),
              EntryDropdownField<String>(
                value: floors.isEmpty ? null : selectedFloor,
                hint: floors.isEmpty
                    ? ''
                    : (selectedProjectId == null
                        ? 'Select project first'
                        : 'Select floor'),
                enabled: selectedProjectId != null && floors.isNotEmpty,
                items: floors.isEmpty
                    ? const []
                    : floors
                        .map(
                          (f) => DropdownMenuItem<String>(
                            value: f,
                            child: Text(f),
                          ),
                        )
                        .toList(),
                onChanged: (selectedProjectId == null || floors.isEmpty)
                    ? null
                    : onFloorChanged,
                error: floors.isEmpty ? null : floorError,
              ),
              if (floors.isNotEmpty && floorError != null)
                EntryErrorText(floorError!),
              const SizedBox(height: 18),
              const EntryFieldLabel('Phase', required: true),
              const SizedBox(height: 8),
              EntryDropdownField<String>(
                value: visiblePhaseNames.contains(selPhaseName)
                    ? selPhaseName
                    : null,
                hint: (floors.isNotEmpty && selectedFloor == null)
                    ? 'Select floor first'
                    : visiblePhaseNames.isEmpty
                    ? 'No phases configured for this project'
                    : 'Select phase',
                enabled: (floors.isEmpty || selectedFloor != null) && visiblePhaseNames.isNotEmpty,
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
          const SizedBox(height: 14),
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
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.subhead(context))),
            const SizedBox(width: 12),
            Text(formatInr(totalAmount), style: BtText.amount(context, size: 26)),
          ]),
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
                    colors: [Color(0xFF0B63CE), Color(0xFF0B63CE)],
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
                    Text(
                      'Parsed from Voice',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Confidence: ${confidence.toStringAsFixed(1)}% · $ts',
                      style: const TextStyle(fontSize: 13, color: _kGray),
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
                  color: const Color(0xFFE7F6EE),
                  borderRadius: BorderRadius.circular(Bt.rCard),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF067647),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entryTypeLabel,
                      style: const TextStyle(
                        color: Color(0xFF067647),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFEEF1F5), thickness: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.format_align_left, color: _kBlue, size: 14),
              const SizedBox(width: 6),
              Text(
                'Voice transcript',
                style: TextStyle(
                  color: _kBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Bt.line),
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
                  style: TextStyle(fontSize: 13, color: _kGray),
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
    return BtButton(label: label, icon: icon, loading: isLoading, onPressed: onTap);
  }
}
class EntryErrorText extends StatelessWidget {
  const EntryErrorText(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(message, style: BtText.caption(context, color: Bt.red)),
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
        return const Color(0xFF067647);
      case PaymentStatus.partial:
        return const Color(0xFF0B63CE);
      case PaymentStatus.pending:
        return const Color(0xFFB54708);
      case PaymentStatus.overdue:
        return const Color(0xFFC01048);
    }
  }
  Color get _bg {
    switch (status) {
      case PaymentStatus.paid:
        return const Color(0xFFE7F6EE);
      case PaymentStatus.partial:
        return const Color(0xFFE8F1FC);
      case PaymentStatus.pending:
        return const Color(0xFFFEF3E7);
      case PaymentStatus.overdue:
        return const Color(0xFFFDECEF);
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
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BtCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Payment overview', style: BtText.subhead(context)),
                Text(formatInr(totalPaid), style: BtText.amount(context, size: 28)),
                Text('of ${formatInr(totalBilled)} billed · $pctLabel settled', style: BtText.num(BtText.caption(context))),
              ]),
            ),
            BtButton(label: 'Settle', icon: Icons.payment_outlined, small: true, expand: false, onPressed: onSettle),
          ]),
          const SizedBox(height: 12),
          BtProgress(value: paidRatio.toDouble(), color: Bt.green),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            BtBadge(label: '$pctLabel paid', tone: BtTone.green),
            BtBadge(label: '${formatInr(outstanding)} due', tone: outstanding > 0 ? BtTone.amber : BtTone.neutral),
            if (pendingCount > 0) BtBadge(label: '$pendingCount pending', tone: BtTone.amber),
          ]),
        ]),
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
                            color: Bt.inputBorder,
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
                                  color: const Color(0xFFE8F1FC),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Color(0xFF0B63CE),
                                  size: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Fulfillment & Payment',
                                style: TextStyle(
                                  color: Color(0xFF101828),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
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
                            colors: [Color(0xFF0B63CE), Color(0xFF6B2FD9)],
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
                                    'Fulfillment & payment',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
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
                                      fontWeight: FontWeight.w700,
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
                                          fontSize: 12,
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
                                  'Outstanding',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
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
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (alreadyPaid > 0)
                                  Text(
                                    '${formatCurrency(alreadyPaid)} paid',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
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
                                    const Color(0xFF067647),
                                    const Color(0xFFE7F6EE),
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
                                    const Color(0xFFB54708),
                                    const Color(0xFFFEF3E7),
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
                                    const Color(0xFFC01048),
                                    const Color(0xFFFDECEF),
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
                                              ? const Color(0xFFC01048)
                                              : const Color(0xFFE4E7EC),
                                          width: 1.0,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: amountError != null
                                              ? const Color(0xFFC01048)
                                              : const Color(0xFF0B63CE),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
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
                                        ? const Color(0xFFC01048)
                                        : const Color(0xFF667085),
                                    fontSize: 13,
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
                                  activeColor: const Color(0xFF0B63CE),
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
                                          borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF0B63CE), width: 1.5),
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
                                    backgroundColor: isEsignPolling ? const Color(0xFFC01048) : const Color(0xFF0B63CE),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(isEsignPolling ? 'Cancel Polling' : 'Send for E-Signature', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              if (esignStatusText.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(esignStatusText, style: TextStyle(color: isEsignPolling ? const Color(0xFFB54708) : (isEsignCompleted ? const Color(0xFF067647) : const Color(0xFFC01048)), fontWeight: FontWeight.bold)),
                                )
                            ],
                            if (isEsignCompleted) ...[
                               const SizedBox(height: 8),
                               Container(
                                 padding: const EdgeInsets.all(12),
                                 decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF067647))),
                                 child: const Row(
                                   children: [
                                     Icon(Icons.check_circle, color: Color(0xFF067647)),
                                     SizedBox(width: 8),
                                     Text('Signature successfully captured!', style: TextStyle(color: Color(0xFF067647), fontWeight: FontWeight.bold)),
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
                                        ? const Color(0xFFE7F6EE)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: uploadedReceipt != null
                                          ? const Color(0xFF067647)
                                          : const Color(0xFFD0D5DD),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: uploadedReceipt != null
                                      ? Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_outline,
                                              color: Color(0xFF067647),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                uploadedReceipt!,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFF067647),
                                                  fontSize: 13,
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
                                                color: Color(0xFF667085),
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
                                                color: const Color(0xFFE8F1FC),
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                              ),
                                              child: const Icon(
                                                Icons.upload_outlined,
                                                color: Color(0xFF0B63CE),
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
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                SizedBox(height: 1),
                                                Text(
                                                  'PNG, JPG, PDF — UPI / Bank / Cheque proof',
                                                  style: TextStyle(
                                                    color: _kGray,
                                                    fontSize: 12,
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
                                          primary: Color(0xFF0B63CE),
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
                                      color: const Color(0xFFD0D5DD),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month_outlined,
                                        color: Color(0xFF0B63CE),
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
                                    border: Border.all(color: Bt.line),
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
                                        Color(0xFF0B63CE),
                                        Color(0xFF6B2FD9),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(11),
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
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
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
      color: Color(0xFF667085),
      fontSize: 12,
      fontWeight: FontWeight.w700,
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
            color: sel ? dotColor : const Color(0xFFE4E7EC),
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
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sel ? dotColor : const Color(0xFF475467),
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
        color: selected ? const Color(0xFF0B63CE) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF0B63CE) : const Color(0xFFE4E7EC),
          width: 1.5,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF0B63CE).withValues(alpha: 0.18),
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
            color: selected ? Colors.white : const Color(0xFF667085),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF475467),
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
          border: Border.all(color: Bt.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FC),
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
                      fontSize: 13,
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
        iconColor = const Color(0xFFC01048);
        iconBg = const Color(0xFFFDECEF);
      } else if (lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.png')) {
        iconData = Icons.image_outlined;
        iconColor = const Color(0xFF0B63CE);
        iconBg = const Color(0xFFE8F1FC);
      } else if (lowerName.endsWith('.doc') || lowerName.endsWith('.docx')) {
        iconData = Icons.description_outlined;
        iconColor = const Color(0xFF1565C0);
        iconBg = const Color(0xFFE3F2FD);
      } else if (lowerName.endsWith('.xls') || lowerName.endsWith('.xlsx')) {
        iconData = Icons.table_chart_outlined;
        iconColor = const Color(0xFF067647);
        iconBg = const Color(0xFFE7F6EE);
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
          border: Border.all(color: Bt.line),
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
                          fontSize: 13,
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
              child: Text(
                'View',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
          border: Border.all(color: Bt.line),
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
                color: Color(0xFF667085),
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
                    'Add one when you record a payment',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 13,
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
    Color iconColor = const Color(0xFF067647);
    Color iconBg = const Color(0xFFE7F6EE);
    if (lowerName.endsWith('.pdf')) {
      iconData = Icons.picture_as_pdf_outlined;
      iconColor = const Color(0xFFC01048);
      iconBg = const Color(0xFFFDECEF);
    } else if (lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png')) {
      iconData = Icons.image_outlined;
      iconColor = const Color(0xFF067647);
      iconBg = const Color(0xFFE7F6EE);
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
          color: const Color(0xFFE7F6EE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
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
                          fontSize: 13,
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
                color: const Color(0xFFE7F6EE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'View',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




// ───────────────────────────────────────── redesigned form building blocks (B08–B10)

/// Read-only "Where" summary at the top of an entry form (project · floor · phase · activity).
class EntryWhereSummary extends StatelessWidget {
  const EntryWhereSummary({super.key, this.projectId, this.floor, this.phase, this.activity});
  final String? projectId;
  final String? floor;
  final String? phase;
  final String? activity;
  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectProvider>().projects;
    final project = projects.where((p) => p.id == projectId).firstOrNull;
    final parts = [phase, activity, floor].where((v) => v != null && v.trim().isNotEmpty).cast<String>().toList();
    if (project == null && parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: BtGroup(children: [
        BtRow(
          leading: const BtTile(icon: Icons.place_outlined),
          title: parts.isEmpty ? (project?.name ?? '') : parts.join(' · '),
          subtitle: parts.isEmpty ? null : project?.name,
          minHeight: 60,
        ),
      ]),
    );
  }
}

/// Amber inline notice (warnings that don't block saving).
class EntryNotice extends StatelessWidget {
  const EntryNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Bt.amberSoft, borderRadius: BorderRadius.circular(Bt.rTile)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded, color: Bt.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: BtText.subhead(context, color: Bt.amber, weight: FontWeight.w500))),
        ]),
      ),
    );
  }
}

/// Titled block of fields with consistent rhythm: title, 12px, children separated by 16px.
class EntryFormSection extends StatelessWidget {
  const EntryFormSection({super.key, this.title, this.caption, required this.children, this.trailing});
  final String? title;
  final String? caption;
  final Widget? trailing;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: title, style: BtText.headline(context)),
                  if (caption != null) TextSpan(text: '  $caption', style: BtText.caption(context)),
                ])),
              ),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 12),
          ],
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Label above a field (with required star) — wraps any field widget.
class EntryLabeled extends StatelessWidget {
  const EntryLabeled({super.key, required this.label, required this.child, this.required = false});
  final String label;
  final bool required;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      EntryFieldLabel(label, required: required),
      const SizedBox(height: 8),
      child,
    ]);
  }
}

/// Date picker field in the form style.
class EntryDateField extends StatelessWidget {
  const EntryDateField({super.key, required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return BtPickerField(
      text: formatDate(date),
      icon: Icons.calendar_today_outlined,
      onTap: onTap,
    );
  }
}

/// "Includes GST" switch + optional percentage field.
class EntryGstToggle extends StatelessWidget {
  const EntryGstToggle({super.key, required this.withGst, required this.onChanged, required this.gstCtrl, this.onPercentChanged});
  final bool withGst;
  final ValueChanged<bool> onChanged;
  final TextEditingController gstCtrl;
  final ValueChanged<String>? onPercentChanged;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        toggled: withGst,
        label: 'Includes GST',
        child: InkWell(
          borderRadius: BorderRadius.circular(Bt.rTile),
          onTap: () => onChanged(!withGst),
          child: SizedBox(
            height: Bt.touch,
            child: Row(children: [
              Expanded(child: Text('Includes GST', style: BtText.body(context))),
              BtSwitch(value: withGst, onChanged: onChanged),
            ]),
          ),
        ),
      ),
      if (withGst) ...[
        const SizedBox(height: 8),
        EntryLabeled(
          label: 'GST percentage',
          child: EntryUnderlineField(
            controller: gstCtrl,
            hint: 'e.g. 18',
            suffix: '%',
            keyboardType: TextInputType.number,
            onChanged: onPercentChanged,
          ),
        ),
      ],
    ]);
  }
}

/// Big total with the maths underneath (qty × rate, subtotal, GST).
class EntryTotalCard extends StatelessWidget {
  const EntryTotalCard({super.key, required this.total, required this.label, this.lines = const []});
  final double total;
  final String label;
  final List<(String, String)> lines;
  @override
  Widget build(BuildContext context) {
    return BtCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: BtText.subhead(context)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(total > 0 ? formatInr(total) : '₹0', style: BtText.amount(context)),
        ),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, color: Bt.line),
          const SizedBox(height: 8),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(l.$1, style: BtText.subhead(context))),
                Text(l.$2, style: BtText.num(BtText.subhead(context, color: Bt.ink, weight: FontWeight.w500))),
              ]),
            ),
        ],
      ]),
    );
  }
}

/// Recent / repeat entries shortcut row.
class EntryRecentRow extends StatelessWidget {
  const EntryRecentRow({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return BtGroup(children: [
      BtRow(
        leading: const BtTile(icon: Icons.history_rounded),
        title: 'Recent entries',
        subtitle: '$count similar entr${count == 1 ? "y" : "ies"} · tap to repeat one',
        showChevron: true,
        onTap: onTap,
      ),
    ]);
  }
}

/// Sticky bottom action area for forms.
class EntryBottomBar extends StatelessWidget {
  const EntryBottomBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Bt.card, border: Border(top: BorderSide(color: Bt.line))),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: child,
    );
  }
}
