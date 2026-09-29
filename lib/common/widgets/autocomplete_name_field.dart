import 'package:buildtrack_mobile/common/themes/app_colors.dart';
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
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.errorText != null
                    ? AppColors.error
                    : AppColors.primary,
                width: 2,
              ),
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            onChanged: (v) {
              widget.onChanged(v);
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: widget.hint,
              hintStyle: const TextStyle(color: AppColors.textLight),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
              suffixIcon: widget.suggestions.isNotEmpty
                  ? Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (showDropdown) ...[
          const SizedBox(height: 8),
          _SuggestionDropdown(
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
        ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E5FF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: const BoxDecoration(
                color: Color(0xFFF4F5FF),
                border: Border(bottom: BorderSide(color: Color(0xFFE0E5FF))),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Recent Entries',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    items.isEmpty
                        ? 'No matches'
                        : '${items.length} match${items.length == 1 ? '' : 'es'}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                    ),
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
                  color: Color(0xFFF0EEF8),
                  indent: 14,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCurrentProject
                    ? const Color(0xFFEEF0FF)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCurrentProject
                    ? Icons.inventory_2_outlined
                    : Icons.history_outlined,
                size: 17,
                color: isCurrentProject
                    ? AppColors.primary
                    : AppColors.textLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (rateLabel.isNotEmpty || dateLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (rateLabel.isNotEmpty)
                          Text(
                            rateLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        if (rateLabel.isNotEmpty && dateLabel.isNotEmpty)
                          const Text(
                            '  ·  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        if (dateLabel.isNotEmpty)
                          Flexible(
                            child: Text(
                              'Used $dateLabel',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textLight,
                              ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_circle_outline_rounded,
                size: 18,
                color: Color(0xFF15803D),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Text(
                    'Add as new entry',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: Color(0xFF15803D),
            ),
          ],
        ),
      ),
    );
  }
}
