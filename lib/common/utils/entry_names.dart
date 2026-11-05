// Entry name grouping rules — shared by Insights ("By type") and the name
// cleanup script. Pure Dart (no Flutter) so it can be unit-tested and reused.
//
// 1. Match key: lowercase, keep only a–z and 0–9. "M sand", "M-Sand",
//    "Msand", "M.Sand" → "msand". Insights groups by this key only by
//    default (display = most common spelling) — the user's data as entered.
// 2. Material rules (Sand, Cement, Doors & Windows, …) are SUGGESTIONS only:
//    "Suggest groups" proposes them and the user ticks what to apply (stored
//    as the same per-user overrides as "Move to group"). First match wins.
// 3. Tidy spellings unifies spelling per key; it never applies rule names.

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

/// One material rule. [child] is the simple name every match gets (M-Sand,
/// Cement, …) or null = keep each item's own name as its child (grouped by
/// [entryNameKey], display = most common spelling) — for kinds whose items
/// differ meaningfully (UPVC door vs Teak door).
class MaterialRule {
  final String parent;
  final String? child;
  final List<String> keys;
  const MaterialRule(this.parent, this.child, this.keys);
}

/// Ordered — first match wins.
/// - Shuttering's own words before Doors & Windows ("shuttering" contains
///   "shutter"); its loose "plate" stays at the end ("door plate" → doors).
/// - Doors & Windows before Steel / Aggregate / Electrical / Plumbing / Wood
///   ("Steel door", "UPVC window", "Teak door" are doors & windows).
/// - Electrical before Plumbing ("PVC conduit pipe" → Electrical).
/// - Steel before Aggregate ("metal").
const List<MaterialRule> materialRules = [
  MaterialRule('Sand', 'M-Sand', ['msand', 'manufacturedsand', 'robosand']),
  MaterialRule('Sand', 'P-Sand', ['psand', 'plastersand', 'plasteringsand']),
  MaterialRule('Sand', 'River Sand', ['riversand']),
  MaterialRule('Sand', 'Sand', ['sand']),
  MaterialRule('Cement', 'Cement', ['cement', 'opc', 'ppc']),
  MaterialRule('Shuttering', null, ['shuttering', 'centering', 'centring']),
  MaterialRule('Doors & Windows', null, ['door', 'window', 'shutter', 'grill', 'grille']),
  MaterialRule('Steel', 'Binding Wire', ['bindingwire']),
  MaterialRule('Steel', 'Steel', ['tmt', 'steel', 'rebar', 'rod']),
  MaterialRule('Aggregate', 'Aggregate', ['jelly', 'jalli', 'jally', 'aggregate', 'bluemetal', 'gravel', 'stonechip', 'metal']),
  MaterialRule('Bricks & Blocks', 'Bricks', ['brick']),
  MaterialRule('Bricks & Blocks', 'Blocks', ['block', 'aac', 'flyash']),
  MaterialRule('Concrete', 'Ready-Mix Concrete', ['rmc', 'readymix', 'concrete']),
  MaterialRule('Electrical', null, ['wire', 'cable', 'conduit', 'switch', 'mcb', 'electrical', 'socket', 'light', 'fan']),
  MaterialRule('Plumbing', null, ['plumbing', 'cpvc', 'upvc', 'pvc', 'pipe', 'tap', 'valve', 'fitting', 'sanitary']),
  MaterialRule('Flooring', null, ['tile', 'granite', 'marble']),
  MaterialRule('Paint', null, ['putty', 'paint', 'primer', 'emulsion', 'enamel', 'distemper']),
  MaterialRule('Wood', null, ['wood', 'timber', 'plywood', 'ply', 'teak', 'frame']),
  MaterialRule('Chemicals', null, ['waterproof', 'admixture', 'chemical', 'sealant']),
  MaterialRule('Shuttering', null, ['plate']),
  MaterialRule('Water', 'Water', ['water', 'tanker']),
  MaterialRule('Hardware', null, ['nail', 'screw', 'bolt', 'hardware', 'hinge']),
];

/// Every parent the rules can give, in rule order, then Miscellaneous.
List<String> get materialRuleParents => [
  ...{for (final r in materialRules) r.parent},
  miscellaneousParent,
];

/// Common simple material names offered by autofill even before anyone has
/// used them (the fixed children of the rules).
const List<String> standardMaterialNames = [
  'M-Sand', 'P-Sand', 'River Sand', 'Cement', 'Steel', 'Binding Wire',
  'Aggregate', 'Bricks', 'Blocks', 'Ready-Mix Concrete',
];

/// Where a material name belongs.
/// [childKey] groups entries inside the parent: the rule's child name, or the
/// name's own key for keep-own-name children. [child] is the child's display
/// name, or null = use the most common original spelling among its entries.
typedef MaterialPlace = ({String parent, String? child, String childKey});

/// Rule placement (kept in sync with the backend cleanup script). Insights no
/// longer applies it automatically — see [materialRuleFor] for suggestions.
/// [overrides] (nameKey → parent) win over the rules and keep the own name.
MaterialPlace classifyMaterial(String name, {Map<String, String>? overrides}) {
  final k = entryNameKey(name);
  final own = 'n:$k';
  final o = overrides == null || k.isEmpty ? null : overrides[k];
  if (o != null && o.trim().isNotEmpty) return (parent: entryNameDisplay(o), child: null, childKey: own);
  final r = materialRuleFor(name);
  if (r == null) return (parent: miscellaneousParent, child: null, childKey: own);
  final child = r.child;
  return (parent: r.parent, child: child, childKey: child == null ? own : 'c:$child');
}

/// The first rule [name] matches, or null (Miscellaneous).
MaterialRule? materialRuleFor(String name) {
  final k = entryNameKey(name);
  if (k.isEmpty) return null;
  // Long needles may appear anywhere ("msand" in "M-Sand"); short ones (< 5)
  // must start a word, so "product" isn't Steel ("rod") and "laptop" isn't Plumbing.
  final words = name.toLowerCase().split(_nonAlnum).where((w) => w.isNotEmpty).toList();
  // ≤ 3 letters must be the whole word (or its plural): "fan"/"fans", not "fancy".
  bool hit(String needle) => needle.length >= 5
      ? k.contains(needle)
      : needle.length <= 3
          ? words.any((w) => w == needle || w == '${needle}s')
          : words.any((w) => w.startsWith(needle));
  for (final r in materialRules) {
    if (r.keys.any(hit)) return r;
  }
  return null;
}

/// The name to save for [typed]: an existing spelling from [known] with the
/// same [entryNameKey] ("msand" → "M-Sand"), else [typed] with spaces
/// collapsed. Stops new spelling variants of the same thing being created.
String canonicalEntryName(String typed, Iterable<String> known) {
  final d = entryNameDisplay(typed);
  final k = entryNameKey(d);
  if (k.isEmpty) return d;
  for (final n in known) {
    if (entryNameKey(n) == k) {
      final e = entryNameDisplay(n);
      if (e.isNotEmpty) return e;
    }
  }
  return d;
}

/// Autofill pool for materials: [past] suggestions (records with a 'title')
/// plus the [standardMaterialNames] not already there by key. Standard rows
/// carry `$standard: true` (no rate / unit to prefill).
List<Map<String, dynamic>> withStandardMaterialNames(List<Map<String, dynamic>> past) {
  final have = {for (final s in past) entryNameKey('${s['title'] ?? s['name'] ?? ''}')};
  return [
    ...past,
    for (final n in standardMaterialNames)
      if (!have.contains(entryNameKey(n))) {'title': n, r'$standard': true},
  ];
}
