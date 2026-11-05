import 'package:buildtrack_mobile/common/widgets/log_sheet.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:flutter/material.dart';

class _EntryType {
  final String id;
  final String title;
  final String subtitle;
  final String route;
  const _EntryType({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

const _entryTypes = [
  _EntryType(
    id: 'material',
    title: 'Material',
    subtitle: 'Concrete, steel, timber & raw materials',
    route: '/add-material',
  ),
  _EntryType(
    id: 'labour',
    title: 'Labour',
    subtitle: 'Worker hours, headcount, wages',
    route: '/add-labour',
  ),
  _EntryType(
    id: 'equipment',
    title: 'Equipment',
    subtitle: 'Machinery usage, fuel, running costs',
    route: '/add-equipment',
  ),
];

void showAddEntryPopup(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Bt.card,
    barrierColor: Bt.scrim,
    sheetAnimationStyle: btSheetStyle(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
    ),
    builder: (_) => _AddEntrySheet(parentContext: context),
  );
}

class _AddEntrySheet extends StatefulWidget {
  final BuildContext parentContext;
  const _AddEntrySheet({required this.parentContext});
  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  String? _selectedId;
  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Bt.inputBorder, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),
              Text('NEW ENTRY', style: BtText.mono(context, color: context.bt.accentInk)),
              const SizedBox(height: 4),
              Text('What are you adding?', style: BtText.d2(context)),
              const SizedBox(height: 4),
              Text('Select the entry type to log for the current shift.', style: BtText.subhead(context)),
              const SizedBox(height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < _entryTypes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: BtReveal(
                      index: i,
                      child: LogKindTile(
                        type: _entryTypes[i].id,
                        title: _entryTypes[i].title,
                        subtitle: _entryTypes[i].subtitle,
                        selected: _selectedId == _entryTypes[i].id,
                        onTap: () {
                          final type = _entryTypes[i];
                          setState(() => _selectedId = type.id);
                          Future.delayed(const Duration(milliseconds: 150), () {
                            if (!mounted) return;
                            Navigator.pop(context);
                            Navigator.pushNamed(widget.parentContext, type.route);
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
