import 'package:buildtrack_mobile/design/design.dart';
import 'package:flutter/material.dart';

/// "Log an entry" sheet opened by the centre + (SCREEN-PLAN B05).
/// Same choices as the Add Entry page: Material / Labour / Equipment go to the
/// existing flow (where → voice or manual); bulk CSV import lives on /add-entry.
Future<void> showLogSheet(BuildContext context) {
  return showBtSheet(
    context,
    title: 'Log an entry',
    subtitle: 'Choose what you are adding',
    builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BtGroup(children: [
        _row(ctx, 'material', 'Material', 'Log concrete, steel, lumber, or site-specific procurement items.', Icons.inventory_2_outlined),
        _row(ctx, 'labour', 'Labour', 'Track crew hours, specialized trade performance, and site presence.', Icons.groups_outlined),
        _row(ctx, 'equipment', 'Equipment', 'Record heavy machinery runtime, fuel logs, and maintenance events.', Icons.local_shipping_outlined),
      ]),
      const SizedBox(height: 8),
      BtButton(
        label: 'Import many from a spreadsheet',
        icon: Icons.upload_file_outlined,
        variant: BtButtonVariant.quiet,
        onPressed: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pushNamed('/add-entry');
        },
      ),
    ]),
  );
}

Widget _row(BuildContext ctx, String type, String title, String subtitle, IconData icon) {
  return BtRow(
    leading: BtTile(icon: icon),
    title: title,
    subtitle: subtitle,
    subtitleMaxLines: 2,
    showChevron: true,
    minHeight: 64,
    onTap: () {
      final nav = Navigator.of(ctx);
      nav.pop();
      nav.pushNamed('/execution-context', arguments: {'type': type});
    },
  );
}
