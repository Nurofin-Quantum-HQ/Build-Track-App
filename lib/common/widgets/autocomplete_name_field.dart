import 'package:buildtrack_mobile/design/design.dart';
import 'package:flutter/material.dart';
class AutocompleteNameField extends StatefulWidget {
  const AutocompleteNameField({
    super.key,
    required this.controller,
    required this.hint,
    required this.suggestions,
    required this.onChanged,
    required this.onSuggestionSelected,
    this.errorText,
  });
  final TextEditingController controller;
  final String hint;
  final List<Map<String, dynamic>> suggestions;
  final ValueChanged<String> onChanged;
  final void Function(Map<String, dynamic> tx) onSuggestionSelected;
  final String? errorText;
  @override
  State<AutocompleteNameField> createState() => _AutocompleteNameFieldState();
}
class _AutocompleteNameFieldState extends State<AutocompleteNameField> {
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _filtered = [];
  bool _showSuggestions = false;
  static const int _maxSuggestions = 10;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    debugPrint(
      '[AutocompleteNameField] initState — '
      'suggestions pool: ${widget.suggestions.length}',
    );
  }
  @override
  void didUpdateWidget(AutocompleteNameField old) {
    super.didUpdateWidget(old);
    if (old.suggestions != widget.suggestions) {
      debugPrint(
        '[AutocompleteNameField] suggestions updated: '
        '${widget.suggestions.length} records',
      );
      if (widget.controller.text.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _computeFiltered(widget.controller.text);
          }
        });
      }
    }
  }
  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }
  void _onTextChanged() {
    final text = widget.controller.text;
    debugPrint(
      '[AutocompleteNameField] text changed → "$text" '
      '(pool: ${widget.suggestions.length})',
    );
    _computeFiltered(text);
  }
  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      debugPrint(
        '[AutocompleteNameField] focus lost — scheduling suggestion collapse',
      );
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() {
            _showSuggestions = false;
          });
        }
      });
    } else {
      debugPrint('[AutocompleteNameField] focus gained');
      if (widget.controller.text.isNotEmpty) {
        _computeFiltered(widget.controller.text);
      }
    }
  }
  void _computeFiltered(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _filtered = [];
        _showSuggestions = false;
      });
      debugPrint('[AutocompleteNameField] query empty — suggestions hidden');
      return;
    }
    final startsWith = <Map<String, dynamic>>[];
    final contains = <Map<String, dynamic>>[];
    for (final s in widget.suggestions) {
      final title = (s['title'] ?? s['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (title.startsWith(q)) {
        startsWith.add(s);
      } else if (title.contains(q)) {
        contains.add(s);
      }
      if (startsWith.length + contains.length >= _maxSuggestions) break;
    }
    setState(() {
      _filtered = [...startsWith, ...contains].take(_maxSuggestions).toList();
      _showSuggestions = _focusNode.hasFocus;
    });
    debugPrint(
      '[AutocompleteNameField] query="$q" '
      '→ ${_filtered.length} matches '
      '(${startsWith.length} starts-with, ${contains.length} contains)',
    );
  }
  void _onSelectSuggestion(Map<String, dynamic> tx) {
    setState(() {
      _showSuggestions = false;
    });
    widget.controller.removeListener(_onTextChanged);
    final name = (tx['title'] ?? tx['name'] ?? '').toString().trim();
    widget.controller.text = name;
    widget.controller.selection = TextSelection.collapsed(offset: name.length);
    widget.controller.addListener(_onTextChanged);
    debugPrint('[AutocompleteNameField] selected: "$name"');
    widget.onSuggestionSelected(tx);
  }
  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim();
    final items = List<Map<String, dynamic>>.from(_filtered);
    final hasExactMatch = items.any(
      (s) =>
          (s['title'] ?? '').toString().trim().toLowerCase() ==
          query.toLowerCase(),
    );
    final showAddNew = !hasExactMatch && query.isNotEmpty;
    final totalRows = items.length + (showAddNew ? 1 : 0);
    final showDropdown = _showSuggestions && totalRows > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: (v) {
            widget.onChanged(v);
          },
          decoration: btInput(context, hint: widget.hint).copyWith(
            enabledBorder: widget.errorText != null
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: const BorderSide(color: Bt.red))
                : null,
            focusedBorder: widget.errorText != null
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: const BorderSide(color: Bt.red, width: 2))
                : null,
            suffixIcon: widget.suggestions.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: context.bt.accentInk,
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
          ),
          style: BtText.body(context, weight: FontWeight.w500),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.errorText!,
              style: BtText.caption(context, color: Bt.red),
            ),
          ),
        AnimatedSwitcher(
          duration: Bt.fast,
          switchInCurve: Bt.ease,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SizeTransition(sizeFactor: anim, axisAlignment: -1, child: child),
          ),
          child: !showDropdown
              ? const SizedBox(width: double.infinity)
              : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _SuggestionDropdown(
            items: items,
            query: query,
            showAddNew: showAddNew,
            onSelect: _onSelectSuggestion,
            onAddNew: () {
              setState(() {
                _showSuggestions = false;
              });
            },
          ),
                ),
        ),
      ],
    );
  }
}
class _SuggestionDropdown extends StatelessWidget {
  const _SuggestionDropdown({
    required this.items,
    required this.query,
    required this.showAddNew,
    required this.onSelect,
    required this.onAddNew,
  });
  final List<Map<String, dynamic>> items;
  final String query;
  final bool showAddNew;
  final void Function(Map<String, dynamic>) onSelect;
  final VoidCallback onAddNew;
  static String _relativeDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) {
        final w = (diff.inDays / 7).floor();
        return w == 1 ? '1 week ago' : '$w weeks ago';
      }
      if (diff.inDays < 365) {
        final m = (diff.inDays / 30).floor();
        return m == 1 ? '1 month ago' : '$m months ago';
      }
      final y = (diff.inDays / 365).floor();
      return y == 1 ? '1 year ago' : '$y years ago';
    } catch (_) {
      return '';
    }
  }
  static String _rateLabel(Map<String, dynamic> tx) {
    final rate = (tx['rate'] as num?)?.toDouble() ?? 0.0;
    if (rate <= 0) return '';
    final unit = (tx['unit'] ?? '').toString().trim();
    final rateStr = rate % 1 == 0
        ? '₹${rate.toInt()}'
        : '₹${rate.toStringAsFixed(2)}';
    return (unit.isNotEmpty && unit != 'unit' && unit != 'units')
        ? '$rateStr / $unit'
        : rateStr;
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.circular(Bt.rInput),
        boxShadow: Bt.shadowLg,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Bt.rInput),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  Text('RECENT ENTRIES', style: BtText.mono(context)),
                  const Spacer(),
                  Text(
                    items.isEmpty
                        ? 'No matches'
                        : '${items.length} match${items.length == 1 ? '' : 'es'}',
                    style: BtText.caption(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: items.length + (showAddNew ? 1 : 0),
                separatorBuilder: (_, p1) => const Divider(
                  height: 1,
                  color: Bt.line,
                  indent: 62,
                  endIndent: 14,
                ),
                itemBuilder: (ctx, index) {
                  if (showAddNew && index == items.length) {
                    return _AddNewRow(query: query, onTap: onAddNew);
                  }
                  final tx = items[index];
                  final title = (tx['title'] ?? tx['name'] ?? '')
                      .toString()
                      .trim();
                  final unit = (tx['unit'] ?? '').toString().trim();
                  final rateLabel = _rateLabel(tx);
                  final dateLabel = _relativeDate(tx['date']?.toString());
                  final isCurrentProject =
                      tx['\$isCurrentProject'] as bool? ?? false;
                  return _SuggestionRow(
                    title: title,
                    unit: unit,
                    rateLabel: rateLabel,
                    dateLabel: dateLabel,
                    isCurrentProject: isCurrentProject,
                    onTap: () => onSelect(tx),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.title,
    required this.unit,
    required this.rateLabel,
    required this.dateLabel,
    required this.isCurrentProject,
    required this.onTap,
  });
  final String title;
  final String unit;
  final String rateLabel;
  final String dateLabel;
  final bool isCurrentProject;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BtTile(
                icon: isCurrentProject ? Icons.inventory_2_outlined : Icons.history_rounded,
                size: 36,
                fg: isCurrentProject ? Bt.ink : Bt.ink3,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BtText.body(context, weight: FontWeight.w600),
                    ),
                    if (rateLabel.isNotEmpty || dateLabel.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          if (rateLabel.isNotEmpty)
                            Text(
                              rateLabel,
                              style: BtText.num(BtText.caption(context, color: Bt.green, weight: FontWeight.w600)),
                            ),
                          if (rateLabel.isNotEmpty && dateLabel.isNotEmpty)
                            Text('  ·  ', style: BtText.caption(context)),
                          if (dateLabel.isNotEmpty)
                            Flexible(
                              child: Text(
                                'Used $dateLabel',
                                overflow: TextOverflow.ellipsis,
                                style: BtText.caption(context),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (unit.isNotEmpty && unit != 'unit' && unit != 'units') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Bt.fill,
                    borderRadius: BorderRadius.circular(Bt.rChip),
                  ),
                  child: Text(
                    unit,
                    style: BtText.caption(context, color: Bt.ink, weight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
class _AddNewRow extends StatelessWidget {
  const _AddNewRow({required this.query, required this.onTap});
  final String query;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              const BtTile(
                icon: Icons.add_rounded,
                size: 36,
                bg: Bt.greenSoft,
                fg: Bt.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BtText.body(context, weight: FontWeight.w600),
                    ),
                    Text(
                      'Add as new entry',
                      style: BtText.caption(context, color: Bt.green, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Bt.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
