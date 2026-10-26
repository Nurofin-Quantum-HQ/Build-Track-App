// Entry name grouping rules — shared by Insights ("By type") and the name
// cleanup script. Pure Dart (no Flutter) so it can be unit-tested and reused.
//
// 1. Match key: lowercase, keep only a–z and 0–9. "M sand", "M-Sand",
//    "Msand", "M.Sand" → "msand".
// 2. Materials get a parent (Sand, Cement, Steel, …, Miscellaneous) and a
//    simple child name; first matching rule wins (order matters).
// 3. Labour / equipment: no parents, group by key only.

final RegExp _nonAlnum = RegExp(r'[^a-z0-9]');
final RegExp _spaces = RegExp(r'\s+');

/// Match key for an entry name: same thing = same key.
String entryNameKey(String name) => name.toLowerCase().replaceAll(_nonAlnum, '');

/// A spelling cleaned for display: trimmed, inner whitespace collapsed.
String entryNameDisplay(String name) => name.trim().replaceAll(_spaces, ' ');

/// The most common display spelling among [names] (ties: first seen).
/// Empty names are ignored; returns null when none is left.
String? mostCommonSpelling(Iterable<String> names) {
  final counts = <String, int>{};
  for (final n in names) {
    final d = entryNameDisplay(n);
    if (d.isEmpty) continue;
    counts[d] = (counts[d] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

const String miscellaneousParent = 'Miscellaneous';

/// One material rule: [child] is null only for Miscellaneous (keep the
/// entry's own name).
class MaterialRule {
  final String parent;
  final String? child;
  final List<String> keys;
  const MaterialRule(this.parent, this.child, this.keys);
}

/// Ordered — first match wins. Electrical before Plumbing ("PVC conduit
/// pipe" → Electrical); Steel before Aggregate ("metal").
const List<MaterialRule> materialRules = [
  MaterialRule('Sand', 'M-Sand', ['msand', 'manufacturedsand', 'robosand']),
  MaterialRule('Sand', 'P-Sand', ['psand', 'plastersand', 'plasteringsand']),
  MaterialRule('Sand', 'River Sand', ['riversand']),
  MaterialRule('Sand', 'Sand', ['sand']),
  MaterialRule('Cement', 'Cement', ['cement', 'opc', 'ppc']),
  MaterialRule('Steel', 'Binding Wire', ['bindingwire']),
  MaterialRule('Steel', 'Steel', ['tmt', 'steel', 'rebar', 'rod']),
  MaterialRule('Aggregate', 'Aggregate', ['jelly', 'jalli', 'jally', 'aggregate', 'bluemetal', 'gravel', 'stonechip', 'metal']),
  MaterialRule('Bricks & Blocks', 'Bricks', ['brick']),
  MaterialRule('Bricks & Blocks', 'Blocks', ['block', 'aac', 'flyash']),
  MaterialRule('Concrete', 'Ready-Mix Concrete', ['rmc', 'readymix', 'concrete']),
  MaterialRule('Electrical', 'Electrical', ['wire', 'cable', 'conduit', 'switch', 'mcb', 'electrical', 'socket', 'light', 'fan']),
  MaterialRule('Plumbing', 'Plumbing', ['plumbing', 'cpvc', 'upvc', 'pvc', 'pipe', 'tap', 'valve', 'fitting', 'sanitary']),
  MaterialRule('Flooring', 'Tiles', ['tile']),
  MaterialRule('Flooring', 'Granite', ['granite']),
  MaterialRule('Flooring', 'Marble', ['marble']),
  MaterialRule('Paint', 'Putty', ['putty']),
  MaterialRule('Paint', 'Paint', ['paint', 'primer', 'emulsion', 'enamel', 'distemper']),
  MaterialRule('Wood', 'Wood', ['wood', 'timber', 'plywood', 'ply', 'teak', 'door', 'frame']),
  MaterialRule('Chemicals', 'Waterproofing', ['waterproof', 'admixture', 'chemical', 'sealant']),
  MaterialRule('Shuttering', 'Shuttering', ['shuttering', 'centering', 'centring', 'plate']),
  MaterialRule('Water', 'Water', ['water', 'tanker']),
  MaterialRule('Hardware', 'Hardware', ['nail', 'screw', 'bolt', 'hardware', 'hinge']),
];

/// Where a material name belongs.
/// [childKey] groups entries inside the parent: the rule's child name, or the
/// name's own key for Miscellaneous. [child] is the child's display name, or
/// null for Miscellaneous (use the most common original spelling).
typedef MaterialPlace = ({String parent, String? child, String childKey});

MaterialPlace classifyMaterial(String name) {
  final k = entryNameKey(name);
  // Long needles may appear anywhere ("msand" in "M-Sand"); short ones (< 5)
  // must start a word, so "product" isn't Steel ("rod") and "laptop" isn't Plumbing.
  final words = name.toLowerCase().split(_nonAlnum).where((w) => w.isNotEmpty).toList();
  // ≤ 3 letters must be the whole word (or its plural): "fan"/"fans", not "fancy".
  bool hit(String needle) => needle.length >= 5
      ? k.contains(needle)
      : needle.length <= 3
          ? words.any((w) => w == needle || w == '${needle}s')
          : words.any((w) => w.startsWith(needle));
  if (k.isNotEmpty) {
    for (final r in materialRules) {
      for (final needle in r.keys) {
        if (hit(needle)) return (parent: r.parent, child: r.child, childKey: 'c:${r.child}');
      }
    }
  }
  return (parent: miscellaneousParent, child: null, childKey: 'n:$k');
}
