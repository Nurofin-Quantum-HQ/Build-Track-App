import 'package:buildtrack_mobile/design/design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../common/themes/app_colors.dart';
import '../../common/themes/app_theme.dart';
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
      return Scaffold(
        backgroundColor: AppColors.gradientStart,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (token == null || token!.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.gradientStart,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                color: AppColors.textLight,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Session expired. Please log in again.',
                style: AppTheme.body.copyWith(color: AppColors.textLight),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Go back'),
              ),
            ],
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
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: 'Ask about your costs',
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
          if (provider.state != AiReportState.initial && asked.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Bt.ink,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(asked, style: BtText.body(context, color: Colors.white)),
                ),
              ),
            ),
          Expanded(child: _buildContent(provider)),
          Container(
            decoration: const BoxDecoration(color: Bt.card, border: Border(top: BorderSide(color: Bt.line))),
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (val) => _submitSearch(context, val),
                    onChanged: (_) => setState(() {}),
                    style: BtText.body(context),
                    decoration: InputDecoration(
                      hintText: 'Ask about materials, costs, projects…',
                      hintStyle: BtText.body(context, color: Bt.placeholder),
                      prefixIcon: Icon(Icons.auto_awesome, color: bt.brand, size: 20),
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
                      filled: true,
                      fillColor: Bt.ground,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Bt.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Bt.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: bt.brand, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BtIconButton(
                  icon: Icons.arrow_upward_rounded,
                  semantic: 'Ask',
                  color: _searchController.text.trim().isEmpty ? Bt.placeholder : bt.brand,
                  filled: true,
                  onTap: _searchController.text.trim().isEmpty ? () {} : () => _submitSearch(context, _searchController.text),
                ),
              ],
            ),
          ),
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
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiChatReportProvider>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(children: [
          const BtTile(icon: Icons.auto_awesome),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Ask anything about your entries, costs and stock.', style: BtText.body(context, color: Bt.ink2)),
          ),
        ]),
        const SizedBox(height: 24),
        const BtSectionHeader(title: 'Quick insights', caption: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickPrompts.map((p) => _PromptCard(prompt: p, onTap: () => onPromptSelected(p))).toList(),
        ),
        if (provider.recentSearches.isNotEmpty) ...[
          const SizedBox(height: 28),
          const BtSectionHeader(title: 'Recent searches', caption: true),
          BtGroup(
            children: [
              for (final s in provider.recentSearches)
                BtRow(
                  leading: const Icon(Icons.history_rounded, color: Bt.ink3),
                  title: s,
                  showChevron: true,
                  onTap: () => onPromptSelected(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.prompt, required this.onTap});
  final String prompt;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => BtChip(label: prompt, icon: Icons.insights_rounded, onTap: onTap);
}
class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const BtTile(icon: Icons.auto_awesome, size: 32),
          const SizedBox(width: 10),
          Text('Working it out…', style: BtText.subhead(context)),
        ]),
        const SizedBox(height: 16),
        const BtSkeleton(height: 96),
        const SizedBox(height: 12),
        const Row(children: [
          Expanded(child: BtSkeleton(height: 72)),
          SizedBox(width: 12),
          Expanded(child: BtSkeleton(height: 72)),
        ]),
        const SizedBox(height: 12),
        const BtSkeleton(height: 180),
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
    return BtEmpty(
      icon: Icons.error_outline_rounded,
      title: 'Failed to generate report',
      message: error,
      action: 'Try Again',
      onAction: onRetry,
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
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Customize Columns',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    const Text(
                      'Drag items to reorder. Toggle checkbox to show/hide columns.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 300,
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
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
                          return ListTile(
                            key: ValueKey(col),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              col,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            leading: Checkbox(
                              activeColor: AppColors.primary,
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'At least one column must be visible.',
                                          ),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  }
                                });
                              },
                            ),
                            trailing: const Icon(
                              Icons.drag_handle,
                              size: 20,
                              color: Color(0xFF667085),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              tempActive = List.from(widget.result.columns);
                              tempAll = List.from(widget.result.columns);
                            });
                          },
                          child: const Text(
                            'Reset',
                            style: TextStyle(color: Color(0xFF667085), fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _visibleColumns = tempActive;
                            });
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
    return ListView(
      padding: EdgeInsets.only(bottom: 40),
      children: [
        if (result.alerts.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: result.alerts.map((alert) {
                final isCritical = alert['type'] == 'critical';
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCritical
                        ? Colors.red.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCritical
                          ? Colors.red.withValues(alpha: 0.3)
                          : AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCritical ? Icons.warning : Icons.info,
                        color: isCritical ? const Color(0xFFC01048) : AppColors.primary,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          alert['message'] ?? '',
                          style: TextStyle(
                            color: isCritical
                                ? Colors.red.withValues(alpha: 0.95)
                                : AppColors.primary.withValues(alpha: 0.95),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEEF1F5), Color(0xFFC5CAE9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(Bt.rCard),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Executive Summary',
                      style: AppTheme.label.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  result.summary,
                  style: AppTheme.body.copyWith(
                    color: AppColors.textDark,
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => provider.shareSummary(),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
              if (result.tableRows.isNotEmpty)
                TextButton.icon(
                  onPressed: () => provider.exportCsv(),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export CSV'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
        if (result.totalAmount != null || result.rowCount != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
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
                  const SizedBox(width: 16),
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
          ),
        const SizedBox(height: 24),
        if (result.projectBreakdown.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By Project', style: AppTheme.heading3),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Bt.line),
                  ),
                  child: Column(
                    children: List.generate(result.projectBreakdown.length, (
                      index,
                    ) {
                      final item = result.projectBreakdown[index];
                      final isTop = index == 0;
                      final val =
                          (item['totalAmount'] as num?)?.toDouble() ?? 0;
                      final valStr = val > 0
                          ? _formatCurrency(val)
                          : '${item['totalQty'] ?? 0} units';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                if (isTop)
                                  const Text(
                                    '🏆 ',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                if (!isTop) const SizedBox(width: 16),
                                Text(
                                  item['projectName']?.toString() ?? 'Unknown',
                                  style: AppTheme.body.copyWith(
                                    color: AppColors.textDark,
                                    fontWeight: isTop
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              valStr,
                              style: AppTheme.body.copyWith(
                                fontWeight: isTop
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        if (result.tableRows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Bt.line),
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      result.tableType == 'inventory'
                          ? 'Inventory Details'
                          : 'Transaction Details',
                      style: AppTheme.heading3.copyWith(fontSize: 16),
                    ),
                    if (result.tableType != 'inventory')
                      TextButton.icon(
                        onPressed: _showCustomizeColumnsDialog,
                        icon: const Icon(Icons.view_column, size: 16),
                        label: const Text('Customize'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                children: [
                  if (result.tableType == 'inventory')
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildInventoryTable(),
                    )
                  else
                    _buildTransactionTable(),
                ],
              ),
            ),
          ),
        const SizedBox(height: 32),
        if (result.actions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Suggested Explorations',
              style: AppTheme.label.copyWith(color: AppColors.textLight),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: result.actions.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                return ActionChip(
                  label: Text(result.actions[i]),
                  onPressed: () => widget.onActionTap(result.actions[i]),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Bt.rCard),
                    side: const BorderSide(color: Colors.transparent),
                  ),
                );
              },
            ),
          ),
        ],
      ],
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
    double grandTotal = 0;
    for (final r in result.tableRows) {
      final p = r['Amount (INR)'] ?? r['price'];
      grandTotal += (p is num)
          ? p.toDouble()
          : (double.tryParse(p?.toString() ?? '') ?? 0);
    }
    const double colHash = 36;
    const double rowPadH = 16;
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
    const headerBg = Color(0xFFF1F3F8);
    const headerTextStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF667085),
      letterSpacing: 0.5,
    );
    const cellTextStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: Color(0xFF1E293B),
      height: 1.4,
    );
    const dividerColor = Color(0xFFE4E7EC);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: headerBg,
                border: Border(
                  bottom: BorderSide(color: dividerColor, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: rowPadH,
                vertical: 12,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: colHash,
                    child: const Text(
                      '#',
                      style: headerTextStyle,
                      softWrap: false,
                      maxLines: 1,
                    ),
                  ),
                  ..._visibleColumns.map((colName) {
                    final isAmount = colName == 'Amount (INR)';
                    final width = getColWidth(colName);
                    return SizedBox(
                      width: width,
                      child: Align(
                        alignment: isAmount
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          colName.toUpperCase(),
                          style: headerTextStyle,
                          softWrap: false,
                          maxLines: 1,
                        ),
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
                  color: isEven ? Colors.white : const Color(0xFFFAFBFD),
                  border: const Border(
                    bottom: BorderSide(color: dividerColor, width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: rowPadH,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: colHash,
                      child: Text(
                        (r['number'] ?? (index + 1)).toString(),
                        style: cellTextStyle.copyWith(
                          color: const Color(0xFF98A2B3),
                          fontSize: 13,
                        ),
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
                        style = style.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        );
                      } else {
                        displayVal = (val ?? '-').toString();
                        if (colName == 'Description' || colName == 'Project') {
                          style = style.copyWith(fontWeight: FontWeight.w500);
                        } else if (colName == 'Brand' || colName == 'Type') {
                          style = style.copyWith(
                            color: const Color(0xFF475467),
                          );
                        }
                      }
                      return SizedBox(
                        width: width,
                        child: Align(
                          alignment: isAmount
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text(
                            displayVal,
                            style: style,
                            softWrap: false,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF1F3F8),
                border: Border(
                  top: BorderSide(color: Color(0xFFD0D5DD), width: 1.5),
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: rowPadH,
                vertical: 14,
              ),
              child: Row(
                children: [
                  SizedBox(width: colHash),
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
                              'TOTAL (${result.tableRows.length} entries)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF344054),
                                letterSpacing: 0.3,
                              ),
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
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0B63CE),
                                  ),
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
      headingTextStyle: AppTheme.label.copyWith(
        color: AppColors.textLight,
        fontWeight: FontWeight.bold,
      ),
      dataTextStyle: AppTheme.body.copyWith(
        color: AppColors.textDark,
        fontSize: 13,
      ),
      columns: const [
        DataColumn(label: Text('Material')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Quantity')),
        DataColumn(label: Text('Status')),
      ],
      rows: widget.result.tableRows.map((r) {
        final severity = r['severity']?.toString() ?? 'ok';
        Color statusColor = AppColors.success;
        if (severity == 'critical') statusColor = AppColors.error;
        if (severity == 'low') statusColor = AppColors.primary;
        return DataRow(
          cells: [
            DataCell(Text(r['name']?.toString() ?? '-')),
            DataCell(Text(r['category']?.toString().toUpperCase() ?? '-')),
            DataCell(Text('${r['quantity'] ?? 0} ${r['unit'] ?? ''}')),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Bt.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textLight, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTheme.heading2.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTheme.caption.copyWith(color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
