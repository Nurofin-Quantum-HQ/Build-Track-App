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
import 'dart:convert';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
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
        boxShadow: Bt.shadow,
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
    // V2: 13px medium ink2 label above the field, red star when required.
    return Text.rich(
      TextSpan(
        text: label,
        style: BtText.caption(context, color: Bt.ink2, weight: FontWeight.w500),
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
      barrierColor: Bt.scrim,
      builder: (_) => AlertDialog(
        backgroundColor: Bt.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: Text('Add custom unit', style: BtText.d3(ctx)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: BtText.body(ctx, weight: FontWeight.w500),
          decoration: btInput(ctx, hint: 'e.g. coil, container, machine-hrs'),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: BtButton(
                label: 'Cancel',
                variant: BtButtonVariant.secondary,
                small: true,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BtButton(
                label: 'Add',
                small: true,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ),
          ]),
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
        color: Bt.ground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
      ),
      padding: EdgeInsets.only(bottom: botPad),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Bt.inputBorder, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Select unit', style: BtText.d3(context))),
                  BtButton(
                    label: 'Custom',
                    icon: Icons.add_rounded,
                    variant: BtButtonVariant.quiet,
                    small: true,
                    expand: false,
                    onPressed: () => _addCustom(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: BtText.body(context),
                decoration: btInput(
                  context,
                  hint: 'Search units…',
                  prefix: const Icon(Icons.search_rounded, color: Bt.ink3, size: 20),
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
                          const BtTile(icon: Icons.search_off_rounded),
                          const SizedBox(height: 10),
                          Text('No matching unit found.', style: BtText.subhead(context)),
                          const SizedBox(height: 12),
                          BtButton(
                            label: 'Add custom unit',
                            icon: Icons.add_rounded,
                            variant: BtButtonVariant.secondary,
                            small: true,
                            expand: false,
                            onPressed: () => _addCustom(context),
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
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Text(entry.key.toUpperCase(), style: BtText.mono(context)),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.value
                                .map((unit) => BtChip(
                                      label: unit,
                                      selected: widget.currentValue == unit,
                                      onTap: () => _pick(context, unit),
                                    ))
                                .toList(),
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
                    style: BtText.subhead(context, color: Bt.ink2, weight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      entry.$2,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: BtText.subhead(context, color: Bt.ink, weight: FontWeight.w600),
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
    final bt = context.bt;
    return EntrySectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BtTile(icon: Icons.mic, size: 44, bg: bt.accentSoft, fg: bt.accentInk),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parsed from Voice',
                      style: BtText.headline(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Confidence: ${confidence.toStringAsFixed(1)}% · $ts',
                      style: BtText.caption(context),
                    ),
                  ],
                ),
              ),
              BtBadge(label: entryTypeLabel, tone: BtTone.green),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Bt.line, thickness: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.format_align_left, color: bt.accentInk, size: 14),
              const SizedBox(width: 6),
              Text(
                'Voice transcript',
                style: BtText.subhead(context, color: bt.accentInk, weight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Bt.fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Bt.line),
            ),
            child: Text(
              '"$transcript"',
              style: BtText.body(context, color: Bt.ink).copyWith(fontStyle: FontStyle.italic, height: 1.65),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 13, color: Bt.ink3),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Fields have been auto-filled from voice. Review and edit before confirming.',
                  style: BtText.caption(context),
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
        return Bt.green;
      case PaymentStatus.partial:
        return Bt.ink;
      case PaymentStatus.pending:
        return Bt.amber;
      case PaymentStatus.overdue:
        return Bt.red;
    }
  }
  Color get _bg {
    switch (status) {
      case PaymentStatus.paid:
        return Bt.greenSoft;
      case PaymentStatus.partial:
        return Bt.fill;
      case PaymentStatus.pending:
        return Bt.amberSoft;
      case PaymentStatus.overdue:
        return Bt.redSoft;
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
        borderRadius: BorderRadius.circular(Bt.rChip),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, color: _fg, size: 16),
          const SizedBox(width: 4),
          Text(
            _label,
            style: BtText.caption(context, color: _fg, weight: FontWeight.w600),
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
  // Polling can outlive the sheet (drag-dismiss, Back, Cancel, Confirm): it stops
  // when the sheet closes and never calls the sheet's setState after that.
  bool sheetOpen = true;
  Future<void> startEsignFlow(StateSetter setSheet) async {
    void ss(VoidCallback f) => sheetOpen ? setSheet(f) : f();
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
    int attempts = 0;
    const maxAttempts = 60; // 3 minutes (60 × 3 s), same as the payment screen
    while (isEsignPolling && sheetOpen && attempts < maxAttempts) {
      attempts++;
      await Future.delayed(const Duration(seconds: 3));
      if (!isEsignPolling || !sheetOpen) break;
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
    if (isEsignPolling) {
      ss(() {
        isEsignPolling = false;
        esignStatusText = sheetOpen ? 'Signing timed out. You can retry or proceed.' : '';
      });
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
    barrierColor: Bt.scrim,
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
                  color: Bt.ground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Bt.inputBorder,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            BtIconButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              semantic: 'Back',
                              onTap: () => Navigator.pop(ctx),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Fulfillment & Payment',
                                style: BtText.navTitle(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Noir summary card — what is being paid and what's still due.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: BtCard(
                          variant: BtCardVariant.ink,
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FULFILLMENT & PAYMENT',
                                      style: BtText.mono(ctx, color: Bt.onNoir2),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      entryTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: BtText.headline(ctx).copyWith(color: Bt.bone),
                                    ),
                                    if (category.isNotEmpty ||
                                        vendorName.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          [category, vendorName]
                                              .where((s) => s.isNotEmpty)
                                              .join(' · '),
                                          style: BtText.caption(ctx, color: Bt.onNoir2),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'OUTSTANDING',
                                    style: BtText.mono(ctx, color: Bt.onNoir2),
                                  ),
                                  const SizedBox(height: 6),
                                  BtCountUp(
                                    value: outstanding > 0 ? outstanding : totalAmount,
                                    format: (v) => formatCurrency(v),
                                    style: BtText.d3(ctx, color: ctx.bt.accent),
                                  ),
                                  if (alreadyPaid > 0)
                                    Text(
                                      '${formatCurrency(alreadyPaid)} paid',
                                      style: BtText.num(BtText.caption(ctx, color: Bt.onNoir2)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            20,
                            16,
                            botPad > 0 ? 8 : 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SheetSectionLabel('PAYMENT STATUS'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Bt.fill,
                                  borderRadius: BorderRadius.circular(Bt.rInput),
                                ),
                                child: Row(
                                  children: [
                                    _pStatusCard(
                                      ss,
                                      selectedStatus,
                                      PaymentStatus.paid,
                                      'Fully Paid',
                                      Bt.green,
                                      Bt.card,
                                      (v) => ss(() {
                                        selectedStatus = v;
                                        amountError = null;
                                        amountCtrl.text = outstanding > 0
                                            ? outstanding.toStringAsFixed(0)
                                            : totalAmount.toStringAsFixed(0);
                                      }),
                                    ),
                                    const SizedBox(width: 4),
                                    _pStatusCard(
                                      ss,
                                      selectedStatus,
                                      PaymentStatus.partial,
                                      'Partial',
                                      Bt.amber,
                                      Bt.card,
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
                                    const SizedBox(width: 4),
                                    _pStatusCard(
                                      ss,
                                      selectedStatus,
                                      PaymentStatus.pending,
                                      'Not Paid',
                                      Bt.red,
                                      Bt.card,
                                      (v) => ss(() {
                                        selectedStatus = v;
                                        amountError = null;
                                        amountCtrl.text = '0';
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              const _SheetSectionLabel(
                                'ACTUAL AMOUNT PAID (₹)',
                              ),
                              const SizedBox(height: 8),
                              AnimatedOpacity(
                                opacity: selectedStatus == PaymentStatus.pending
                                    ? 0.4
                                    : 1.0,
                                duration: Bt.fast,
                                child: SizedBox(
                                  height: 76,
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
                                    decoration: btInput(ctx, hint: '0.00').copyWith(
                                      prefixText: '₹ ',
                                      prefixStyle: BtText.d2(ctx, color: Bt.ink3).copyWith(fontWeight: FontWeight.w500),
                                      hintStyle: BtText.d2(ctx, color: Bt.placeholder),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 18,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(Bt.rInput),
                                        borderSide: BorderSide(
                                          color: amountError != null ? Bt.red : Bt.inputBorder,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(Bt.rInput),
                                        borderSide: BorderSide(
                                          color: amountError != null ? Bt.red : Bt.ink,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    style: BtText.num(BtText.d2(ctx)),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 2, bottom: 20),
                                child: Text(
                                  amountError ?? helperText,
                                  style: BtText.num(BtText.caption(
                                    ctx,
                                    color: amountError != null ? Bt.red : Bt.ink2,
                                    weight: FontWeight.w500,
                                  )),
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
                                      50,
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
                                        50,
                                        () => ss(() => selectedMethod = lbl),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              if (selectedMethod == 'Cash') ...[
                                const SizedBox(height: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Bt.card,
                                    borderRadius: BorderRadius.circular(Bt.rCard),
                                    boxShadow: Bt.shadow,
                                  ),
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Semantics(
                                        toggled: requestEsign,
                                        label: 'Request E-Signature for Cash Receipt',
                                        child: InkWell(
                                          onTap: () => ss(() => requestEsign = !requestEsign),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(minHeight: 60),
                                            child: Row(
                                              children: [
                                                BtTile(
                                                  icon: Icons.draw_outlined,
                                                  bg: ctx.bt.accentSoft,
                                                  fg: ctx.bt.accentInk,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('Request E-Signature for Cash Receipt', style: BtText.body(ctx, weight: FontWeight.w600)),
                                                      Text('Client signs on their phone', style: BtText.caption(ctx)),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                BtSwitch(
                                                  value: requestEsign,
                                                  onChanged: (val) => ss(() => requestEsign = val),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (requestEsign)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0, bottom: 12.0),
                                          child: TextField(
                                            controller: emailCtrl,
                                            keyboardType: TextInputType.emailAddress,
                                            style: BtText.body(ctx, weight: FontWeight.w500),
                                            decoration: btInput(
                                              ctx,
                                              hint: 'Client Email Address',
                                              prefix: const Icon(Icons.email_outlined, color: Bt.ink3, size: 20),
                                            ),
                                          ),
                                        ),
                                      if (requestEsign && !isEsignCompleted) ...[
                                        BtButton(
                                          label: isEsignPolling ? 'Cancel Polling' : 'Send for E-Signature',
                                          icon: isEsignPolling ? Icons.close_rounded : Icons.send_rounded,
                                          variant: isEsignPolling ? BtButtonVariant.destructive : BtButtonVariant.primary,
                                          small: true,
                                          onPressed: isEsignPolling
                                              ? () {
                                                  ss(() => isEsignPolling = false);
                                                }
                                              : () => startEsignFlow(ss),
                                        ),
                                        if (esignStatusText.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Row(
                                              children: [
                                                if (isEsignPolling) ...[
                                                  const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Bt.amber),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    esignStatusText,
                                                    style: BtText.subhead(
                                                      ctx,
                                                      weight: FontWeight.w600,
                                                      color: isEsignPolling ? Bt.amber : (isEsignCompleted ? Bt.green : Bt.red),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                      ],
                                      if (isEsignCompleted) ...[
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Bt.greenSoft,
                                            borderRadius: BorderRadius.circular(Bt.rTile),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.check_circle_rounded, color: Bt.green, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Signature successfully captured!',
                                                  style: BtText.subhead(ctx, color: Bt.green, weight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              const _SheetSectionLabel('PAYMENT RECEIPT'),
                              const SizedBox(height: 8),
                              BtPressable(
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
                                  duration: Bt.fast,
                                  curve: Bt.ease,
                                  width: double.infinity,
                                  constraints: const BoxConstraints(minHeight: 64),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: uploadedReceipt != null ? Bt.greenSoft : Bt.card,
                                    borderRadius: BorderRadius.circular(Bt.rCard),
                                    boxShadow: uploadedReceipt != null ? null : Bt.shadow,
                                  ),
                                  child: uploadedReceipt != null
                                      ? Row(
                                          children: [
                                            const BtTile(
                                              icon: Icons.check_circle_outline_rounded,
                                              bg: Bt.card,
                                              fg: Bt.green,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Receipt attached', style: BtText.body(ctx, weight: FontWeight.w600, color: Bt.green)),
                                                  Text(
                                                    uploadedReceipt!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: BtText.caption(ctx, color: Bt.green),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            BtIconButton(
                                              icon: Icons.close_rounded,
                                              size: 18,
                                              color: Bt.ink2,
                                              semantic: 'Remove receipt',
                                              onTap: () => ss(() {
                                                uploadedReceipt = null;
                                                uploadedReceiptDataUri = null;
                                              }),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            const BtTile(icon: Icons.upload_outlined),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Upload Payment Receipt',
                                                    style: BtText.body(ctx, weight: FontWeight.w600),
                                                  ),
                                                  Text(
                                                    'PNG, JPG, PDF — UPI / Bank / Cheque proof',
                                                    style: BtText.caption(ctx),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.add_rounded, color: Bt.ink3, size: 20),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const _SheetSectionLabel('PAYMENT DATE'),
                              const SizedBox(height: 8),
                              BtPickerField(
                                text: '${selectedPaymentDate.day}/${selectedPaymentDate.month}/${selectedPaymentDate.year}',
                                icon: Icons.calendar_today_outlined,
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: selectedPaymentDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                    builder: (c, child) => Theme(
                                      data: Theme.of(c).copyWith(
                                        colorScheme: Theme.of(c).colorScheme.copyWith(
                                          primary: Bt.ink,
                                          onPrimary: Bt.card,
                                          onSurface: Bt.ink,
                                        ),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    ss(() => selectedPaymentDate = picked);
                                  }
                                },
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
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          botPad > 0 ? botPad : 18,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BtButton(
                                label: 'Confirm Payment & Update Inventory',
                                onPressed: () {
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
                            ),
                            const SizedBox(height: 4),
                            BtButton(
                              label: 'Cancel',
                              variant: BtButtonVariant.quiet,
                              onPressed: () => Navigator.pop(ctx),
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
  ).whenComplete(() {
    sheetOpen = false;
    isEsignPolling = false;
  });
}
class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(label, style: BtText.mono(context));
}
/// One segment of the 3-way payment status control (sliding-pill look).
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
    child: Semantics(
      button: true,
      selected: sel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(value),
        child: AnimatedContainer(
          duration: Bt.fast,
          curve: Bt.ease,
          height: 44,
          decoration: BoxDecoration(
            color: sel ? bgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: sel ? Bt.shadow : null,
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
              const SizedBox(width: 6),
              Flexible(
                child: Builder(
                  builder: (c) => Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BtText.subhead(c, weight: FontWeight.w600, color: sel ? Bt.ink : Bt.ink2),
                  ),
                ),
              ),
            ],
          ),
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
  return Semantics(
    button: true,
    selected: selected,
    child: BtPressable(
      onTap: onTap,
      scale: .96,
      child: AnimatedContainer(
        duration: Bt.fast,
        curve: Bt.ease,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: selected ? Bt.ink : Bt.card,
          borderRadius: BorderRadius.circular(Bt.rTile),
          border: Border.all(color: selected ? Bt.ink : Bt.inputBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Bt.bone : Bt.ink2,
              size: 18,
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (c) => Text(
                label,
                style: BtText.subhead(c, weight: FontWeight.w600, color: selected ? Bt.bone : Bt.ink),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
/// Shared shell for the attachment rows (white card, soft shadow, tile + text + trailing).
class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.tile,
    required this.title,
    required this.subtitle,
    this.subtitleIcon,
    this.subtitleColor = Bt.ink3,
    this.trailing,
    this.onTap,
    this.background = Bt.card,
  });
  final Widget tile;
  final String title;
  final String subtitle;
  final IconData? subtitleIcon;
  final Color subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color background;
  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Bt.rCard),
        boxShadow: background == Bt.card ? Bt.shadow : null,
      ),
      child: Row(
        children: [
          tile,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (subtitleIcon != null) ...[
                      Icon(subtitleIcon, color: subtitleColor, size: 13),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: subtitleColor, weight: FontWeight.w500)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    if (onTap == null) return body;
    return BtPressable(onTap: onTap, scale: .98, child: body);
  }
}
class _ViewPill extends StatelessWidget {
  const _ViewPill();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(Bt.rChip)),
      child: Text('View', style: BtText.caption(context, color: Bt.ink, weight: FontWeight.w600)),
    );
  }
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
      return const _AttachmentRow(
        tile: BtTile(icon: Icons.upload_file_outlined, fg: Bt.ink3),
        title: 'No document attached',
        subtitle: 'Upload invoice or bill to view',
      );
    }
    IconData iconData = Icons.insert_drive_file_outlined;
    Color iconColor = Bt.ink2;
    Color iconBg = Bt.fill;
    final lowerName = name.toLowerCase();
    if (attachment != null) {
      iconData = attachment!.icon;
      iconColor = attachment!.iconColor;
      iconBg = attachment!.iconBg;
    } else {
      if (lowerName.endsWith('.pdf')) {
        iconData = Icons.picture_as_pdf_outlined;
        iconColor = Bt.red;
        iconBg = Bt.redSoft;
      } else if (lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.png')) {
        iconData = Icons.image_outlined;
        iconColor = Bt.ink;
        iconBg = Bt.fill;
      } else if (lowerName.endsWith('.doc') || lowerName.endsWith('.docx')) {
        iconData = Icons.description_outlined;
        iconColor = Bt.ink;
        iconBg = Bt.fill;
      } else if (lowerName.endsWith('.xls') || lowerName.endsWith('.xlsx')) {
        iconData = Icons.table_chart_outlined;
        iconColor = Bt.green;
        iconBg = Bt.greenSoft;
      }
    }
    final Widget tile = (attachment == null &&
            (name.startsWith('http://') || name.startsWith('https://')) &&
            (lowerName.contains('.jpg') ||
                lowerName.contains('.jpeg') ||
                lowerName.contains('.png')))
        ? ClipRRect(
            borderRadius: BorderRadius.circular(Bt.rTile),
            child: Image.network(
              name,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => BtTile(icon: iconData, bg: iconBg, fg: iconColor),
            ),
          )
        : BtTile(icon: iconData, bg: iconBg, fg: iconColor);
    return _AttachmentRow(
      tile: tile,
      title: name,
      subtitle: 'Successfully attached',
      subtitleIcon: Icons.check_circle_rounded,
      subtitleColor: Bt.green,
      trailing: const _ViewPill(),
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
      return const _AttachmentRow(
        tile: BtTile(icon: Icons.receipt_long_outlined, fg: Bt.ink3),
        title: 'No payment receipt attached',
        subtitle: 'Add one when you record a payment',
      );
    }
    final lowerName = fileName!.toLowerCase();
    IconData iconData = Icons.receipt_long_outlined;
    Color iconColor = Bt.green;
    Color iconBg = Bt.card;
    if (lowerName.endsWith('.pdf')) {
      iconData = Icons.picture_as_pdf_outlined;
      iconColor = Bt.red;
      iconBg = Bt.redSoft;
    } else if (lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png')) {
      iconData = Icons.image_outlined;
      iconColor = Bt.green;
      iconBg = Bt.card;
    }
    return _AttachmentRow(
      background: Bt.greenSoft,
      tile: BtTile(icon: iconData, bg: iconBg, fg: iconColor),
      title: fileName!,
      subtitle: 'Payment proof attached',
      subtitleIcon: Icons.verified_rounded,
      subtitleColor: Bt.green,
      trailing: const _ViewPill(),
      onTap: () => Navigator.pushNamed(
        context,
        '/receipt-viewer',
        arguments: {'receipt': fileName},
      ),
    );
  }
}

// ───────────────────────────────────────── form building blocks (Design V2 "Blueprint Noir")

/// Read-only context strip at the top of an entry form:
/// "📍 **Project** · Floor · Phase · Activity" on a faint ink tint.
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
    final parts = [floor, phase, activity].where((v) => v != null && v.trim().isNotEmpty).cast<String>().toList();
    if (project == null && parts.isEmpty) return const SizedBox.shrink();
    final rest = parts.join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        label: 'Where: ${[if (project != null) project.name, ...parts].join(', ')}',
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Bt.ink.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(Bt.rTile),
          ),
          child: Row(children: [
            const Icon(Icons.location_on_outlined, size: 16, color: Bt.ink2),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  if (project != null) TextSpan(text: project.name, style: BtText.subhead(context, color: Bt.ink, weight: FontWeight.w600)),
                  if (project != null && rest.isNotEmpty) const TextSpan(text: ' · '),
                  if (rest.isNotEmpty) TextSpan(text: rest),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BtText.subhead(context, color: Bt.ink2),
              ),
            ),
          ]),
        ),
      ),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Bt.amberSoft, borderRadius: BorderRadius.circular(Bt.rInput)),
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
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: title, style: BtText.headline(context)),
                  if (caption != null) TextSpan(text: '  ·  $caption', style: BtText.caption(context)),
                ])),
              ),
              ?trailing,
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
      const SizedBox(height: 7),
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

/// "Includes GST" row in a white card: label + inline % field (when on) + switch.
class EntryGstToggle extends StatelessWidget {
  const EntryGstToggle({super.key, required this.withGst, required this.onChanged, required this.gstCtrl, this.onPercentChanged});
  final bool withGst;
  final ValueChanged<bool> onChanged;
  final TextEditingController gstCtrl;
  final ValueChanged<String>? onPercentChanged;
  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
    return Container(
      decoration: BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(Bt.rCard), boxShadow: Bt.shadow),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Semantics(
            toggled: withGst,
            button: true,
            label: 'Includes GST',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!withGst),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Bt.touch),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Includes GST', style: BtText.body(context, weight: FontWeight.w600)),
                  Text(withGst ? 'Enter the GST percentage' : 'Bill includes tax', style: BtText.caption(context)),
                ]),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: Bt.fast,
          curve: Bt.ease,
          child: withGst
              ? Padding(
                  padding: const EdgeInsets.only(left: 8, right: 10),
                  child: SizedBox(
                    width: 84,
                    height: 44,
                    child: Semantics(
                      label: 'GST percentage',
                      textField: true,
                      child: TextField(
                        controller: gstCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: onPercentChanged,
                        textAlign: TextAlign.left,
                        style: BtText.num(BtText.body(context, weight: FontWeight.w600)),
                        decoration: InputDecoration(
                          hintText: '18',
                          hintStyle: BtText.body(context, color: Bt.placeholder),
                          suffixText: '%',
                          suffixStyle: BtText.body(context, color: Bt.ink3),
                          isDense: true,
                          filled: true,
                          fillColor: Bt.card,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          border: b(Bt.inputBorder),
                          enabledBorder: b(Bt.inputBorder),
                          focusedBorder: b(Bt.ink, 2),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: 10),
        ),
        BtSwitch(value: withGst, onChanged: onChanged),
      ]),
    );
  }
}

/// The total — noir "ink" card on a faint blueprint grid: the maths
/// (qty × rate, GST…) on top and the total rolling up in the display face.
class EntryTotalCard extends StatelessWidget {
  const EntryTotalCard({super.key, required this.total, required this.label, this.lines = const []});
  final double total;
  final String label;
  final List<(String, String)> lines;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      label: '$label ${total > 0 ? formatInr(total) : '₹0'}',
      container: true,
      child: BtCard(
        variant: BtCardVariant.ink,
        padding: EdgeInsets.zero,
        child: Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _InkGridPainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(l.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, color: Bt.onNoir2))),
                    const SizedBox(width: 10),
                    Text(l.$2, style: BtText.num(BtText.subhead(context, color: Bt.bone, weight: FontWeight.w500))),
                  ]),
                ),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: Bt.noirLine),
                const SizedBox(height: 12),
              ],
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(label, style: BtText.body(context, color: Bt.bone, weight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: BtCountUp(
                      value: total > 0 ? total : 0,
                      duration: const Duration(milliseconds: 700),
                      format: (v) => v > 0 ? formatInr(v) : '₹0',
                      style: BtText.d2(context, color: bt.accent),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Faint 18px blueprint grid behind the ink total card.
class _InkGridPainter extends CustomPainter {
  const _InkGridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0BFFFFFF)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Recent / repeat entries shortcut row.
class EntryRecentRow extends StatelessWidget {
  const EntryRecentRow({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return BtGroup(children: [
      BtRow(
        leading: BtTile(icon: Icons.history_rounded, bg: bt.accentSoft, fg: bt.accentInk),
        title: 'Recent entries',
        titleWeight: FontWeight.w600,
        subtitle: '$count similar entr${count == 1 ? "y" : "ies"} · tap to repeat one',
        showChevron: true,
        onTap: onTap,
      ),
    ]);
  }
}

/// Collapsible "More details" list row (white card + tile + chevron). The
/// fields stay mounted-on-demand below it; [autoExpand] opens it when the
/// optional fields already hold data (edit / repeat flows), so nothing the
/// user entered is ever hidden behind a closed row.
class EntryMoreDetails extends StatefulWidget {
  const EntryMoreDetails({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.icon = Icons.notes_rounded,
    this.autoExpand = false,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool autoExpand;
  final List<Widget> children;
  @override
  State<EntryMoreDetails> createState() => _EntryMoreDetailsState();
}
class _EntryMoreDetailsState extends State<EntryMoreDetails> {
  late bool _open = widget.autoExpand;
  bool _touched = false;
  @override
  void didUpdateWidget(covariant EntryMoreDetails old) {
    super.didUpdateWidget(old);
    if (!_touched && widget.autoExpand && !_open) _open = true;
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BtGroup(children: [
          Semantics(
            expanded: _open,
            child: BtRow(
              leading: BtTile(icon: widget.icon),
              title: widget.title,
              titleWeight: FontWeight.w600,
              subtitle: widget.subtitle,
              onTap: () => setState(() {
                _touched = true;
                _open = !_open;
              }),
              trailing: AnimatedRotation(
                turns: _open ? .5 : 0,
                duration: Bt.fast,
                curve: Bt.ease,
                child: const Icon(Icons.expand_more_rounded, color: Bt.ink3),
              ),
            ),
          ),
        ]),
        AnimatedSize(
          duration: Bt.medium,
          curve: Bt.ease,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (var i = 0; i < widget.children.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      widget.children[i],
                    ],
                  ]),
                ),
        ),
      ]),
    );
  }
}

/// Sticky bottom action area for forms — the page fades out under it
/// (no hairline) so the CTA floats on the bone ground, like BtCtaBar.
class EntryBottomBar extends StatelessWidget {
  const EntryBottomBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, stops: const [.72, 1], colors: [bg, bg.withValues(alpha: 0)]),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: child,
      ),
    );
  }
}

// ─── Entry save helpers (shared by add material / labour / equipment + voice) ───

enum EntrySaveOutcome { saved, offline, failed }

class EntrySaveResult {
  const EntrySaveResult(this.outcome, {this.body, this.message});
  final EntrySaveOutcome outcome;
  final Map<String, dynamic>? body;
  final String? message;
  bool get saved => outcome == EntrySaveOutcome.saved;
  bool get offline => outcome == EntrySaveOutcome.offline;
  static const offlineMessage = ApiService.offlineSavedMessage;
}

/// POST /transactions. Distinguishes a real save (200/201), a request queued by
/// the offline queue (202 or `{offline: true}`) and a failure (server message).
Future<EntrySaveResult> postTransaction(Map<String, dynamic> payload) async {
  try {
    final res = await ApiService.post('/transactions', payload);
    Map<String, dynamic>? body;
    try {
      final d = jsonDecode(res.body);
      if (d is Map<String, dynamic>) body = d;
    } catch (_) {}
    if (ApiService.isOfflineQueued(res) || body?['offline'] == true) {
      return EntrySaveResult(
        EntrySaveOutcome.offline,
        body: body,
        message: body?['message']?.toString() ?? EntrySaveResult.offlineMessage,
      );
    }
    if (res.statusCode == 200 || res.statusCode == 201) {
      return EntrySaveResult(EntrySaveOutcome.saved, body: body);
    }
    return EntrySaveResult(EntrySaveOutcome.failed, body: body, message: body?['message']?.toString());
  } catch (e) {
    debugPrint('postTransaction error: $e');
    return const EntrySaveResult(EntrySaveOutcome.failed);
  }
}

/// How an add / edit screen leaves after a successful save (route arg `entryExit`):
/// * `'dock'`   — started from the + sheet / Add Entry tab → the Add Entry tab.
/// * `'origin'` — started from a screen (e.g. a project's activity) via
///   /execution-context → back to that screen.
/// * anything else (edit, Add More, repeat…) → `Navigator.pop(context, true)` so the
///   caller reloads; only when nothing can pop does it fall back to the Add Entry tab.
void finishEntrySave(BuildContext context, {String? exit}) {
  final nav = Navigator.of(context);
  if (exit == 'origin') {
    var passed = false;
    nav.popUntil((r) {
      if (passed || r.isFirst) return true;
      if (r.settings.name == '/execution-context') passed = true;
      return false;
    });
    return;
  }
  if (exit != 'dock' && nav.canPop()) {
    nav.pop(true);
    return;
  }
  final navCtl = context.read<NavController>();
  navCtl.setRoute(navCtl.isRouteEnabled('/add-entry') ? '/add-entry' : '/home', context);
}
