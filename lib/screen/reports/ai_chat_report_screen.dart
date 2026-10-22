import 'package:buildtrack_mobile/design/design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controller/ai_chat_report_provider.dart';
import '../../controller/project_provider.dart';
import '../../services/auth_service.dart';
import '../../config/api_config.dart';
class AiChatReportScreen extends StatefulWidget {
  const AiChatReportScreen({super.key});
  @override
  State<AiChatReportScreen> createState() => _AiChatReportScreenState();
}
class _AiChatReportScreenState extends State<AiChatReportScreen> {
  String? token;
  bool loading = true;
  static String get baseUrl => ApiConfig.baseUrl.replaceAll('/api', '');
  @override
  void initState() {
    super.initState();
    loadToken();
  }
  Future<void> loadToken() async {
    final t = await AuthService.getToken();
    if (mounted) {
      setState(() {
        token = t;
        loading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Bt.noir,
        body: Center(child: BtBrickLoader(onDark: true)),
      );
    }
    if (token == null || token!.isEmpty) {
      return Scaffold(
        backgroundColor: Bt.ground,
        body: SafeArea(
          child: Center(
            child: BtEmpty(
              icon: Icons.lock_outline,
              title: 'Session expired. Please log in again.',
              action: 'Go back',
              onAction: () => Navigator.maybePop(context),
            ),
          ),
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (ctx) => AiChatReportProvider(
        projectProvider: ctx.read<ProjectProvider>(),
        authToken: token!,
        baseUrl: baseUrl,
      ),
      child: const _AiDashboardView(),
    );
  }
}
class _AiDashboardView extends StatefulWidget {
  const _AiDashboardView();
  @override
  State<_AiDashboardView> createState() => _AiDashboardViewState();
}
class _AiDashboardViewState extends State<_AiDashboardView> {
  final _searchController = TextEditingController();
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  void _submitSearch(BuildContext context, String query) {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    context.read<AiChatReportProvider>().sendQuery(query);
  }
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiChatReportProvider>();
    final bt = context.bt;
    final asked = _searchController.text.trim();
    final initial = provider.state == AiReportState.initial;
    final empty = _searchController.text.trim().isEmpty;
    final topInset = MediaQuery.paddingOf(context).top;

    // Bone pill input (floats on noir on the start screen, on bone elsewhere).
    final askBar = Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
        decoration: BoxDecoration(
          color: initial ? Bt.bone : Bt.card,
          borderRadius: BorderRadius.circular(26),
          border: initial ? null : Border.all(color: Bt.inputBorder),
          boxShadow: initial
              ? const [BoxShadow(color: Color(0xCC000000), blurRadius: 40, spreadRadius: -16, offset: Offset(0, 20))]
              : Bt.shadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (val) => _submitSearch(context, val),
                onChanged: (_) => setState(() {}),
                style: BtText.body(context),
                cursorColor: Bt.ink,
                decoration: InputDecoration(
                  hintText: 'Ask about materials, costs, projects…',
                  hintStyle: BtText.body(context, color: Bt.ink3).copyWith(fontSize: 15),
                  prefixIcon: Icon(Icons.auto_awesome, color: bt.accentInk, size: 19),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.cancel_rounded, color: Bt.placeholder, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 4),
            BtPressable(
              onTap: empty ? () {} : () => _submitSearch(context, _searchController.text),
              scale: .9,
              semanticLabel: 'Ask',
              child: AnimatedContainer(
                duration: Bt.fast,
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: empty ? Bt.ink.withValues(alpha: .12) : Bt.noir, shape: BoxShape.circle),
                child: Icon(Icons.arrow_upward_rounded, size: 22, color: empty ? Bt.ink3 : bt.accent),
              ),
            ),
          ],
        ),
      ),
    );

    if (initial) {
      return Scaffold(
        backgroundColor: Bt.noir,
        resizeToAvoidBottomInset: true,
        body: BtHero(
          overlap: 0,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 0),
                child: Row(children: [
                  BtIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    semantic: 'Back',
                    color: Bt.bone,
                    background: Colors.white.withValues(alpha: .09),
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ]),
              ),
              Expanded(
                child: _InitialState(
                  onPromptSelected: (prompt) {
                    _searchController.text = prompt;
                    _submitSearch(context, prompt);
                  },
                ),
              ),
              askBar,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: 'Ask AI',
        subtitle: 'Ask about your costs',
        trailing: provider.state == AiReportState.results
            ? BtIconButton(
                icon: Icons.refresh_rounded,
                semantic: 'New question',
                color: Bt.ink2,
                onTap: () {
                  _searchController.clear();
                  provider.resetToInitial();
                },
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (asked.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 4, 16, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: BtReveal(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Bt.ink,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: Text(asked, style: BtText.subhead(context, color: Bt.bone)),
                  ),
                ),
              ),
            ),
          Expanded(child: _buildContent(provider)),
          askBar,
        ],
      ),
    );
  }
  Widget _buildContent(AiChatReportProvider provider) {
    switch (provider.state) {
      case AiReportState.initial:
        return _InitialState(
          onPromptSelected: (prompt) {
            _searchController.text = prompt;
            _submitSearch(context, prompt);
          },
        );
      case AiReportState.loading:
        return const _LoadingState();
      case AiReportState.error:
        return _ErrorState(
          error: provider.errorMessage ?? 'An unknown error occurred.',
          onRetry: () => _submitSearch(context, _searchController.text),
        );
      case AiReportState.results:
        return _ResultsState(
          result: provider.result!,
          onActionTap: (action) {
            _searchController.text = action;
            _submitSearch(context, action);
          },
        );
    }
  }
}
class _InitialState extends StatelessWidget {
  const _InitialState({required this.onPromptSelected});
  final ValueChanged<String> onPromptSelected;
  final List<String> quickPrompts = const [
    'Show material usage',
    'Compare project costs',
    'Low stock materials',
    'Labour summary',
    'Equipment usage',
    'Monthly spending',
  ];
  static const _icons = [
    Icons.inventory_2_outlined,
    Icons.compare_arrows_rounded,
    Icons.warning_amber_rounded,
    Icons.groups_outlined,
    Icons.local_shipping_outlined,
    Icons.calendar_month_outlined,
  ];
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiChatReportProvider>();
    final bt = context.bt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: BtReveal(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: RadialGradient(
                  center: const Alignment(-.4, -.5),
                  colors: [Color.lerp(bt.accent, Colors.white, .3)!, bt.accent],
                ),
                boxShadow: [BoxShadow(color: bt.accent.withValues(alpha: .35), blurRadius: 60, spreadRadius: 6)],
              ),
              child: Icon(Icons.auto_awesome, color: bt.onAccent, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 16),
        BtReveal(index: 1, child: Text('Ask about\nyour costs.', style: BtText.d1(context, color: Bt.bone))),
        const SizedBox(height: 10),
        BtReveal(
          index: 2,
          child: Text('Ask anything about your entries, costs and stock.', style: BtText.body(context, color: Bt.onNoir2)),
        ),
        const SizedBox(height: 28),
        BtReveal(index: 3, child: Text('QUICK INSIGHTS', style: BtText.mono(context, color: Bt.onNoir3))),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < quickPrompts.length; i++)
                SizedBox(
                  width: w,
                  child: BtReveal(
                    index: 4 + i,
                    child: _PromptCard(prompt: quickPrompts[i], icon: _icons[i], onTap: () => onPromptSelected(quickPrompts[i])),
                  ),
                ),
            ],
          );
        }),
        if (provider.recentSearches.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('RECENT SEARCHES', style: BtText.mono(context, color: Bt.onNoir3)),
          const SizedBox(height: 4),
          for (final s in provider.recentSearches)
            InkWell(
              onTap: () => onPromptSelected(s),
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(children: [
                  const Icon(Icons.history_rounded, color: Bt.onNoir3, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, color: const Color(0xC7F2F0EB))),
                  ),
                  const Icon(Icons.north_west_rounded, color: Bt.onNoir3, size: 16),
                ]),
              ),
            ),
        ],
      ],
    );
  }
}
class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.prompt, required this.icon, required this.onTap});
  final String prompt;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return BtPressable(
      onTap: onTap,
      scale: .96,
      semanticLabel: prompt,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: bt.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(prompt, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, color: Bt.bone, weight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }
}
class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: BtBrickLoader(label: 'Working it out…'))),
        SizedBox(height: 8),
        BtSkeleton(height: 120, radius: Bt.rCard),
        SizedBox(height: 12),
        BtSkeleton(height: 180, radius: Bt.rCard),
      ],
    );
  }
}
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: BtCard(
          child: BtEmpty(
            icon: Icons.error_outline_rounded,
            title: 'Failed to generate report',
            message: error,
            action: 'Try Again',
            onAction: onRetry,
          ),
        ),
      ),
    );
  }
}
class _ResultsState extends StatefulWidget {
  const _ResultsState({required this.result, required this.onActionTap});
  final AiReportResult result;
  final ValueChanged<String> onActionTap;
  @override
  State<_ResultsState> createState() => _ResultsStateState();
}
class _ResultsStateState extends State<_ResultsState> {
  late List<String> _visibleColumns;
  /// Details table expanded (was an ExpansionTile, open by default).
  bool _tableOpen = true;
  @override
  void initState() {
    super.initState();
    _visibleColumns = List.from(widget.result.columns);
  }
  @override
  void didUpdateWidget(covariant _ResultsState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _visibleColumns = List.from(widget.result.columns);
    }
  }
  void _showCustomizeColumnsDialog() {
    List<String> tempActive = List.from(_visibleColumns);
    List<String> tempAll = List.from(widget.result.columns);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Bt.card,
      barrierColor: Bt.scrim,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BtSheetHeader(
                    title: 'Customize Columns',
                    subtitle: 'Drag items to reorder. Toggle checkbox to show/hide columns.',
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .5),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Bt.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Bt.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          buildDefaultDragHandles: false,
                          itemCount: tempAll.length,
                          onReorder: (oldIndex, newIndex) {
                            setDialogState(() {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final item = tempAll.removeAt(oldIndex);
                              tempAll.insert(newIndex, item);
                              final newTempActive = <String>[];
                              for (final col in tempAll) {
                                if (tempActive.contains(col)) {
                                  newTempActive.add(col);
                                }
                              }
                              tempActive = newTempActive;
                            });
                          },
                          itemBuilder: (context, index) {
                            final col = tempAll[index];
                            final isChecked = tempActive.contains(col);
                            return Material(
                              key: ValueKey(col),
                              color: Bt.card,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (index > 0) const Divider(height: 1, indent: 52, color: Bt.line),
                                  SizedBox(
                                    height: 48,
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 6),
                                        Checkbox(
                                          activeColor: Bt.ink,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          value: isChecked,
                                          onChanged: (val) {
                                            setDialogState(() {
                                              if (val == true) {
                                                tempActive.add(col);
                                                final newTempActive = <String>[];
                                                for (final c in tempAll) {
                                                  if (tempActive.contains(c)) {
                                                    newTempActive.add(c);
                                                  }
                                                }
                                                tempActive = newTempActive;
                                              } else {
                                                if (tempActive.length > 1) {
                                                  tempActive.remove(col);
                                                } else {
                                                  btToast(context, 'At least one column must be visible.', error: true);
                                                }
                                              }
                                            });
                                          },
                                        ),
                                        Expanded(
                                          child: Text(col, style: BtText.body(context, weight: FontWeight.w500, color: isChecked ? Bt.ink : Bt.ink3)),
                                        ),
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: const SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: Icon(Icons.drag_handle_rounded, size: 22, color: Bt.ink3),
                                          ),
                                        ),
                                      ],
                                    ),
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
                        SizedBox(
                          width: 110,
                          child: BtButton(
                            label: 'Reset',
                            variant: BtButtonVariant.secondary,
                            onPressed: () {
                              setDialogState(() {
                                tempActive = List.from(widget.result.columns);
                                tempAll = List.from(widget.result.columns);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: BtButton(
                            label: 'Save',
                            onPressed: () {
                              setState(() {
                                _visibleColumns = tempActive;
                              });
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiChatReportProvider>();
    final result = widget.result;
    final bt = context.bt;
    final sections = <Widget>[
      if (result.alerts.isNotEmpty)
        Column(
          children: result.alerts.map((alert) {
            final isCritical = alert['type'] == 'critical';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BtCard(
                variant: isCritical ? BtCardVariant.danger : BtCardVariant.notice,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(isCritical ? Icons.warning_amber_rounded : Icons.info_outline_rounded, color: isCritical ? Bt.red : Bt.amber, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        alert['message'] ?? '',
                        style: BtText.subhead(context, color: isCritical ? Bt.red : Bt.amber, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      BtCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: bt.accent, shape: BoxShape.circle),
                  child: Icon(Icons.auto_awesome, color: bt.onAccent, size: 16),
                ),
                const SizedBox(width: 10),
                Text('EXECUTIVE SUMMARY', style: BtText.mono(context, color: bt.accentInk)),
              ],
            ),
            const SizedBox(height: 12),
            Text(result.summary, style: BtText.body(context).copyWith(height: 1.5, fontSize: 15)),
            if (result.totalAmount != null || result.rowCount != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (result.totalAmount != null)
                    Expanded(
                      child: _MetricCard(
                        title: 'Total Amount',
                        value: _formatCurrency(result.totalAmount!),
                        icon: Icons.currency_rupee,
                      ),
                    ),
                  if (result.totalAmount != null && result.rowCount != null)
                    const SizedBox(width: 12),
                  if (result.rowCount != null)
                    Expanded(
                      child: _MetricCard(
                        title: result.tableType == 'inventory'
                            ? 'Items Tracked'
                            : 'Total Entries',
                        value: result.rowCount.toString(),
                        icon: Icons.format_list_numbered,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BtChip(label: 'Share', icon: Icons.ios_share_rounded, onTap: () => provider.shareSummary()),
            if (result.tableRows.isNotEmpty)
              BtChip(label: 'Export CSV', icon: Icons.file_download_outlined, onTap: () => provider.exportCsv()),
          ],
        ),
      ),
      if (result.projectBreakdown.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BtSectionHeader(title: 'By Project', caption: true),
              BtGroup(
                children: List.generate(result.projectBreakdown.length, (index) {
                  final item = result.projectBreakdown[index];
                  final isTop = index == 0;
                  final val = (item['totalAmount'] as num?)?.toDouble() ?? 0;
                  final valStr = val > 0
                      ? _formatCurrency(val)
                      : '${item['totalQty'] ?? 0} units';
                  return ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 50),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: isTop
                                ? const Text('🏆', style: TextStyle(fontSize: 14))
                                : Text('${index + 1}', style: BtText.num(BtText.mono(context))),
                          ),
                          Expanded(
                            child: Text(
                              item['projectName']?.toString() ?? 'Unknown',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BtText.body(context, weight: isTop ? FontWeight.w600 : FontWeight.w400),
                            ),
                          ),
                          Text(valStr, style: BtText.num(BtText.body(context, weight: isTop ? FontWeight.w700 : FontWeight.w500))),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      if (result.tableRows.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (result.tableType == 'inventory' ? 'Inventory Details' : 'Transaction Details').toUpperCase(),
                        style: BtText.mono(context),
                      ),
                    ),
                    if (result.tableType != 'inventory')
                      TextButton.icon(
                        onPressed: _showCustomizeColumnsDialog,
                        icon: const Icon(Icons.view_column_outlined, size: 16),
                        label: const Text('Customize'),
                        style: TextButton.styleFrom(foregroundColor: bt.accentInk, minimumSize: const Size(44, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
                      ),
                    BtIconButton(
                      icon: _tableOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      semantic: _tableOpen ? 'Collapse table' : 'Expand table',
                      color: Bt.ink2,
                      onTap: () => setState(() => _tableOpen = !_tableOpen),
                    ),
                  ],
                ),
              ),
              if (_tableOpen)
              Container(
                decoration: BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(16), boxShadow: Bt.shadow),
                clipBehavior: Clip.antiAlias,
                child: result.tableType == 'inventory'
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildInventoryTable(),
                      )
                    : _buildTransactionTable(),
              ),
            ],
          ),
        ),
      if (result.actions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BtSectionHeader(title: 'Suggested Explorations', caption: true),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in result.actions)
                    BtChip(label: a, icon: Icons.north_east_rounded, onTap: () => widget.onActionTap(a)),
                ],
              ),
            ],
          ),
        ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: btStagger(sections),
    );
  }
  String _formatCurrency(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
  Widget _buildTransactionTable() {
    final result = widget.result;
    final bt = context.bt;
    double grandTotal = 0;
    for (final r in result.tableRows) {
      final p = r['Amount (INR)'] ?? r['price'];
      grandTotal += (p is num)
          ? p.toDouble()
          : (double.tryParse(p?.toString() ?? '') ?? 0);
    }
    const double colHash = 30;
    const double rowPadH = 12;
    double getColWidth(String colName) {
      if (colName == 'Amount (INR)') return 104;
      if (colName == 'Description' ||
          colName == 'Project' ||
          colName == 'Material') {
        return 160;
      }
      if (colName == 'Purchased Date' ||
          colName == 'Payment Date' ||
          colName == 'Qty') {
        return 96;
      }
      return 120;
    }
    double tableWidth = colHash + (rowPadH * 2);
    for (final col in _visibleColumns) {
      tableWidth += getColWidth(col);
    }
    const headerBg = Color(0xFFF3F3F3);
    final headerTextStyle = BtText.mono(context, size: 9.5, color: Bt.ink2);
    final cellTextStyle = BtText.caption(context, color: Bt.ink).copyWith(fontSize: 12.5, height: 1.3);
    const dividerColor = Color(0x14111317);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: headerBg,
                border: Border(bottom: BorderSide(color: Color(0x24111317), width: 1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: rowPadH, vertical: 11),
              child: Row(
                children: [
                  SizedBox(
                    width: colHash,
                    child: Text('#', style: headerTextStyle, softWrap: false, maxLines: 1),
                  ),
                  ..._visibleColumns.map((colName) {
                    final isAmount = colName == 'Amount (INR)';
                    final width = getColWidth(colName);
                    return SizedBox(
                      width: width,
                      child: Align(
                        alignment: isAmount ? Alignment.centerRight : Alignment.centerLeft,
                        child: Text(colName.toUpperCase(), style: headerTextStyle, softWrap: false, maxLines: 1),
                      ),
                    );
                  }),
                ],
              ),
            ),
            ...List.generate(result.tableRows.length, (index) {
              final r = result.tableRows[index];
              final isEven = index.isEven;
              return Container(
                decoration: BoxDecoration(
                  color: isEven ? Bt.card : const Color(0xFFFAFAFA),
                  border: const Border(bottom: BorderSide(color: dividerColor, width: 1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: rowPadH, vertical: 11),
                child: Row(
                  children: [
                    SizedBox(
                      width: colHash,
                      child: Text(
                        (r['number'] ?? (index + 1)).toString(),
                        style: BtText.num(BtText.mono(context, size: 10)),
                        softWrap: false,
                        maxLines: 1,
                      ),
                    ),
                    ..._visibleColumns.map((colName) {
                      final isAmount = colName == 'Amount (INR)';
                      final width = getColWidth(colName);
                      final val = r[colName];
                      String displayVal;
                      TextStyle style = cellTextStyle;
                      if (isAmount) {
                        final parsed = (val is num)
                            ? val.toDouble()
                            : (double.tryParse(val?.toString() ?? '') ?? 0);
                        displayVal = _formatCurrency(parsed);
                        style = BtText.num(style.copyWith(fontWeight: FontWeight.w700));
                      } else {
                        displayVal = (val ?? '-').toString();
                        if (colName == 'Description' || colName == 'Project') {
                          style = style.copyWith(fontWeight: FontWeight.w600);
                        } else if (colName == 'Brand' || colName == 'Type') {
                          style = style.copyWith(color: Bt.ink2);
                        }
                      }
                      return SizedBox(
                        width: width,
                        child: Align(
                          alignment: isAmount ? Alignment.centerRight : Alignment.centerLeft,
                          child: Text(displayVal, style: style, softWrap: false, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
            Container(
              color: headerBg,
              padding: const EdgeInsets.symmetric(horizontal: rowPadH, vertical: 13),
              child: Row(
                children: [
                  const SizedBox(width: colHash),
                  Builder(
                    builder: (context) {
                      double spanWidth = 0;
                      double amountWidth = 0;
                      bool hasAmount = false;
                      for (final col in _visibleColumns) {
                        if (col == 'Amount (INR)') {
                          hasAmount = true;
                          amountWidth = getColWidth(col);
                        } else {
                          spanWidth += getColWidth(col);
                        }
                      }
                      return Row(
                        children: [
                          SizedBox(
                            width: spanWidth,
                            child: Text(
                              'TOTAL (${result.tableRows.length} entries)'.toUpperCase(),
                              style: BtText.num(BtText.mono(context, color: Bt.ink)),
                              softWrap: false,
                              maxLines: 1,
                            ),
                          ),
                          if (hasAmount)
                            SizedBox(
                              width: amountWidth,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _formatCurrency(grandTotal),
                                  style: BtText.num(BtText.subhead(context, color: bt.accentInk, weight: FontWeight.w700)),
                                  softWrap: false,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildInventoryTable() {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F3F3)),
      headingRowHeight: 40,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 48,
      dividerThickness: 1,
      horizontalMargin: 14,
      columnSpacing: 20,
      headingTextStyle: BtText.mono(context, size: 9.5, color: Bt.ink2),
      dataTextStyle: BtText.caption(context, color: Bt.ink).copyWith(fontSize: 12.5),
      columns: const [
        DataColumn(label: Text('MATERIAL')),
        DataColumn(label: Text('TYPE')),
        DataColumn(label: Text('QUANTITY')),
        DataColumn(label: Text('STATUS')),
      ],
      rows: widget.result.tableRows.map((r) {
        final severity = r['severity']?.toString() ?? 'ok';
        BtTone tone = BtTone.green;
        if (severity == 'critical') tone = BtTone.red;
        if (severity == 'low') tone = BtTone.amber;
        return DataRow(
          cells: [
            DataCell(Text(r['name']?.toString() ?? '-')),
            DataCell(Text(r['category']?.toString().toUpperCase() ?? '-')),
            DataCell(Text('${r['quantity'] ?? 0} ${r['unit'] ?? ''}', style: const TextStyle(fontFeatures: BtText.tnum))),
            DataCell(BtBadge(label: severity.toUpperCase(), tone: tone)),
          ],
        );
      }).toList(),
    );
  }
}
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: Bt.ground, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: Bt.ink3, size: 14),
            const SizedBox(width: 4),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: Bt.ink2).copyWith(fontSize: 12))),
          ]),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: BtText.num(BtText.title(context, size: 21))),
          ),
        ],
      ),
    );
  }
}
