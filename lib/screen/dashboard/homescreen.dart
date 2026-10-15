import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/models/task_model.dart';
import 'package:buildtrack_mobile/services/task_service.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';

String relativeTimeLabel(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.isNegative) {
    return 'Just now';
  }
  if (diff.inMinutes < 1) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  } else if (diff.inDays == 1) {
    return 'Yesterday';
  } else if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  } else {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});
  final GlobalKey<ShowCaseWidgetState> _showcaseKey = GlobalKey<ShowCaseWidgetState>();
  
  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      key: _showcaseKey,
      globalTooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.skip, 
          backgroundColor: Colors.transparent, 
          textStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          onTap: () {
            UserSession.skipTour();
            _showcaseKey.currentState?.dismiss();
          }
        ), 
        TooltipActionButton(
          type: TooltipDefaultActionType.next, 
          backgroundColor: AppColors.primary, 
          textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        )
      ], 
      enableAutoScroll: true,
      onFinish: () {
        UserSession.markModuleVisited('HomeScreen');
        if (UserSession.globalTourActive) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) {
              final nav = Provider.of<NavController>(context, listen: false);
              nav.setRoute('/projects', context);
            }
          });
        }
      },
      builder: (context) => const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();
  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}
class _HomeScreenContentState extends State<_HomeScreenContent> {
  List<GlobalKey> _getShowcaseKeys({bool isReplay = false}) {
    final keys = <GlobalKey>[];
    if (isReplay || !UserSession.hasCreatedProject) {
      keys.add(ShowcaseKeys.projects);
    }
    keys.add(ShowcaseKeys.inventoryTab);
    keys.add(ShowcaseKeys.profileIcon);
    keys.add(ShowcaseKeys.progress);
    keys.add(ShowcaseKeys.dashboardTotalCost);
    keys.add(ShowcaseKeys.dashboardTotalBudget);
    keys.add(ShowcaseKeys.dashboardTotalRevenue);
    keys.add(ShowcaseKeys.dashboardNetCashFlow);
    if (isReplay || !UserSession.hasAddedEntry) {
      keys.add(ShowcaseKeys.addEntry);
    }
    keys.add(ShowcaseKeys.recentEntries);
    if (isReplay || !UserSession.hasViewedReports) {
      keys.add(ShowcaseKeys.reports);
    }
    keys.add(ShowcaseKeys.quickAddEntry);
    keys.add(ShowcaseKeys.helpButton);
    return keys;
  }

  bool _tourChecked = false;

  @override
  void initState() {
    super.initState();
  }

  void _checkTour(ProjectProvider provider) {
    if (_tourChecked) return;
    if (!provider.projectsLoaded) return;
    _tourChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.projects.isNotEmpty || UserSession.hasAddedEntry) {
        UserSession.markAllModulesVisited();
      } else {
        if (!UserSession.appTourPrompted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Welcome to BuildTrack!'),
              content: const Text('Do you want an app tour to help you get started?'),
              actions: [
                TextButton(
                  onPressed: () {
                    UserSession.markAppTourPrompted();
                    Navigator.pop(context);
                  },
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () {
                    UserSession.markAppTourPrompted();
                    UserSession.resetTour();
                    UserSession.setGlobalTourActive(true);
                    Navigator.pop(context);
                    _startHomeScreenTour();
                  },
                  child: const Text('Yes', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        } else if (UserSession.globalTourActive && !UserSession.visitedModules.contains('HomeScreen')) {
          _startHomeScreenTour();
        }
      }
    });
  }

  void _startHomeScreenTour() {
    if (!UserSession.hasSkippedTour && !UserSession.visitedModules.contains('HomeScreen')) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          final keysToShow = _getShowcaseKeys();
          if (keysToShow.isNotEmpty) {
            ShowCaseWidget.of(context).startShowCase(keysToShow);
          }
        }
      });
    }
  }

  void _showEntryOptions(BuildContext context, String type) {
    Navigator.pushNamed(context, '/add-entry');
  }
  @override
  Widget build(BuildContext context) {
    _checkTour(context.watch<ProjectProvider>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NavController>().markCurrent('/home');
    });
    final company = UserSession.companyName.isNotEmpty ? UserSession.companyName : 'BuildTrack';
    final hasLogo = UserSession.companyLogo != null && UserSession.companyLogo!.isNotEmpty;
    return Scaffold(
      backgroundColor: Bt.ground,
      body: SafeArea(
        bottom: false,
        child: Builder(
          builder: (ctx) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 8, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            if (hasLogo) ...[
                              Container(
                                width: 22,
                                height: 22,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Bt.line),
                                  image: DecorationImage(image: getProfileImageProvider(UserSession.companyLogo)!, fit: BoxFit.contain),
                                ),
                              ),
                            ],
                            Flexible(
                              child: Text(
                                company,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: UserSession.getCompanyTextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Bt.ink2),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 2),
                          Text('Today', style: BtText.largeTitle(context)),
                        ],
                      ),
                    ),
                    Showcase(
                      key: ShowcaseKeys.helpButton,
                      description: 'Tap here anytime to replay this tour and get help.',
                      tooltipBackgroundColor: Bt.ink,
                      textColor: Colors.white,
                      tooltipBorderRadius: BorderRadius.circular(16),
                      tooltipPadding: const EdgeInsets.all(16),
                      child: BtIconButton(
                        icon: Icons.help_outline_rounded,
                        semantic: 'App guidelines',
                        color: Bt.ink2,
                        onTap: () {
                          final keysToShow = _getShowcaseKeys(isReplay: true);
                          if (keysToShow.isNotEmpty) {
                            ShowcaseView.get().startShowCase(keysToShow);
                          }
                        },
                      ),
                    ),
                    Showcase(
                      key: ShowcaseKeys.profileIcon,
                      description: 'Tap your profile for your account, team, plan, logs and settings.',
                      tooltipBackgroundColor: Bt.ink,
                      textColor: Colors.white,
                      tooltipBorderRadius: BorderRadius.circular(16),
                      tooltipPadding: const EdgeInsets.all(16),
                      child: Semantics(
                        button: true,
                        label: 'Account',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                          child: const Padding(padding: EdgeInsets.all(4), child: ProfileAvatar(radius: 20)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (UserSession.isAdmin)
                          _AdminDashboard(onEntryTap: _showEntryOptions)
                        else if (UserSession.isSupervisor)
                          const _SupervisorDashboard()
                        else
                          _MasonDashboard(onEntryTap: _showEntryOptions),
                      ],
                    ),
                  ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(),
    );
  }
}
class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onEdit;
  const _TaskCard({required this.task, this.onEdit});
  @override
  Widget build(BuildContext context) {
    final displayStatus = task.status;
    final done = displayStatus == 'Completed';
    final meta = <String>[
      'Assigned to: ${task.assignee ?? "Unassigned"}',
      task.floorName ?? 'On Site',
    ].join(' · ');
    return BtRow(
      leading: BtAvatar(name: task.assignee ?? '?', size: 36),
      title: task.title,
      titleColor: done ? Bt.ink2 : Bt.ink,
      subtitle: task.description.isNotEmpty ? '${task.description}\n$meta' : meta,
      subtitleMaxLines: 3,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        BtBadge(label: displayStatus, tone: done ? BtTone.green : (displayStatus == 'Work in Progress' ? BtTone.brand : BtTone.neutral)),
        if (!done && onEdit != null) ...[const SizedBox(width: 4), Icon(Icons.edit_outlined, size: 18, color: context.bt.brand)],
      ]),
      onTap: !done ? onEdit : null,
    );
  }
}

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard({required this.onEntryTap});
  final void Function(BuildContext, String) onEntryTap;
  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}
class _AdminDashboardState extends State<_AdminDashboard> {
  static var primaryBlue = AppColors.primary;
  static const textDark = AppColors.textDark;
  static const textGray = AppColors.textLight;
  List<dynamic> _revenueEntries = [];
  bool _isGlobalView = true;
  bool _loadingRevenue = false;
  String? _lastProjectId;
  double get _totalRevenueSum {
    return _revenueEntries.fold<double>(0.0, (sum, tx) {
      final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
      return sum + amount;
    });
  }
  Future<void> _loadRevenue(String projectId) async {
    setState(() {
      _loadingRevenue = true;
    });
    try {
      final response = await ApiService.get(
        '/transactions?project=$projectId&type=Income',
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> entries = [];
        if (decoded is List) {
          entries = decoded;
        } else if (decoded is Map) {
          entries =
              (decoded['transactions'] ?? decoded['data'] ?? [])
                  as List<dynamic>;
        }
        entries.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['date']?.toString() ?? '')?.toLocal() ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['date']?.toString() ?? '')?.toLocal() ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
        if (mounted && projectId == _lastProjectId) {
          setState(() {
            _revenueEntries = entries;
            _loadingRevenue = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadingRevenue = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingRevenue = false;
        });
      }
    }
  }
  void _showAddRevenueDialog(
    BuildContext context,
    String projectId, {
    Map<String, dynamic>? editingTx,
    VoidCallback? onSave,
  }) {
    final titleCtrl = TextEditingController(
      text: editingTx?['title']?.toString() ?? '',
    );
    final double initialAmt =
        double.tryParse(editingTx?['amount']?.toString() ?? '') ?? 0.0;
    final amountCtrl = TextEditingController(
      text: initialAmt != 0.0 ? initialAmt.abs().toString() : '',
    );
    final notesCtrl = TextEditingController(
      text: editingTx?['notes']?.toString() ?? '',
    );
    String selectedMode =
        editingTx?['paymentMode']?.toString() ?? 'Bank Transfer';
    DateTime selectedDate = DateTime.now();
    if (editingTx?['date'] != null) {
      try {
        selectedDate = DateTime.parse(editingTx!['date'].toString()).toLocal();
      } catch (_) {}
    }
    PickedImage? pickedImage;
    List<dynamic> attachments = editingTx?['attachments'] is List
        ? editingTx!['attachments'] as List
        : [];
    String? existingImageUrl = attachments.isNotEmpty
        ? attachments.first.toString()
        : (editingTx?['paymentReceipt']?.toString());
    bool isInflow = editingTx != null ? initialAmt >= 0 : true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool isSaving = false;
        bool isEsignPolling = false;
        bool isEsignCompleted = false;
        String esignStatusText = '';
        bool requestEsign = false;
        final clientEmailCtrl = TextEditingController();
        String? newReceiptDataUri;
        Future<void> startEsignFlow(StateSetter ss) async {
          final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          if (amt <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount before requesting an E-Signature')));
            return;
          }
          if (clientEmailCtrl.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter client email')));
            return;
          }
          ss(() {
            isEsignPolling = true;
            esignStatusText = 'Sending request...';
          });
          final meta = {
            'projectName': 'BuildTrack Revenue',
            'type': titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Revenue',
            'amount': amt,
            'paymentMethod': selectedMode,
            'notes': notesCtrl.text.trim(),
            'date': selectedDate.toIso8601String(),
          };
          final res = await ApiService.requestEsignature(clientEmailCtrl.text.trim(), meta);
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
                newReceiptDataUri = statusRes['signatureData'];
                esignStatusText = 'Signature captured!';
              });
              break;
            }
          }
        }
        return StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E7EC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    editingTx != null
                        ? (isInflow
                              ? 'Edit Revenue Inflow'
                              : 'Edit Revenue Outflow')
                        : (isInflow
                              ? 'Record Revenue Inflow'
                              : 'Record Revenue Outflow'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              isInflow = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isInflow
                                  ? const Color(0xFFE7F6EE)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isInflow
                                    ? const Color(0xFF067647)
                                    : const Color(0xFFE4E7EC),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  color: isInflow
                                      ? const Color(0xFF067647)
                                      : const Color(0xFF667085),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Money In',
                                  style: TextStyle(
                                    color: isInflow
                                        ? const Color(0xFF067647)
                                        : const Color(0xFF667085),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              isInflow = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !isInflow
                                  ? const Color(0xFFFDECEF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: !isInflow
                                    ? const Color(0xFFC01048)
                                    : const Color(0xFFE4E7EC),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  color: !isInflow ? const Color(0xFFC01048) : const Color(0xFF667085),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Money Out',
                                  style: TextStyle(
                                    color: !isInflow ? const Color(0xFFC01048) : const Color(0xFF667085),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Payment Title / Milestone',
                      hintText: 'e.g. Milestone 1 Payment, Advance Payment',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isInflow
                          ? 'Amount Received (₹)'
                          : 'Amount Sent (₹)',
                      hintText: 'e.g. 500000',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(
                        value: 'Bank Transfer',
                        child: Text('Bank Transfer'),
                      ),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedMode = val;
                        });
                      }
                    },
                  ),
                  if (selectedMode == 'Cash') ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Request E-Signature for Cash Receipt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      value: requestEsign,
                      onChanged: (val) => setModalState(() => requestEsign = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF0B63CE),
                    ),
                    if (requestEsign)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: TextField(
                          controller: clientEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Client Email Address',
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFFE4E7EC))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0B63CE))),
                          ),
                        ),
                      ),
                    if (requestEsign && !isEsignCompleted) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isEsignPolling ? () {
                            setModalState(() => isEsignPolling = false);
                          } : () => startEsignFlow(setModalState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEsignPolling ? const Color(0xFFC01048) : const Color(0xFF0B63CE),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(isEsignPolling ? 'Cancel Polling' : 'Send for E-Signature', style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                      if (esignStatusText.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 8), child: Text(esignStatusText, style: TextStyle(color: isEsignPolling ? const Color(0xFFB54708) : (isEsignCompleted ? const Color(0xFF067647) : const Color(0xFFC01048)), fontWeight: FontWeight.bold)))
                    ],
                    if (isEsignCompleted) ...[
                       const SizedBox(height: 8),
                       Container(
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF067647))),
                         child: const Row(children: [Icon(Icons.check_circle, color: Color(0xFF067647)), SizedBox(width: 8), Text('Signature successfully captured!', style: TextStyle(color: Color(0xFF067647), fontWeight: FontWeight.bold))])
                       )
                    ],
                  ],
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        final now = DateTime.now();
                        setModalState(() {
                          selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            now.hour,
                            now.minute,
                            now.second,
                          );
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFD0D5DD)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Date Received',
                            style: TextStyle(color: Color(0xFF475467)),
                          ),
                          Text(
                            '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Notes / Remarks (Optional)',
                      hintText: isInflow
                          ? 'e.g. Initial payment received for start of work'
                          : 'e.g. Refund sent for milestone delay',
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final img = await pickImageFromGallery(context);
                      if (img != null) {
                        setModalState(() {
                          pickedImage = img;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFD0D5DD)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: Color(0xFF475467),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Upload Receipt Proof (Optional)',
                                style: TextStyle(color: Color(0xFF475467)),
                              ),
                            ],
                          ),
                          if (pickedImage != null)
                            Row(
                              children: [
                                const Text(
                                  'Selected',
                                  style: TextStyle(
                                    color: Color(0xFF067647),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      pickedImage = null;
                                    });
                                  },
                                  child: const Icon(
                                    Icons.cancel,
                                    color: Color(0xFFC01048),
                                    size: 20,
                                  ),
                                ),
                              ],
                            )
                          else if (newReceiptDataUri != null)
                            Row(
                              children: [
                                const Text(
                                  'E-Signature',
                                  style: TextStyle(
                                    color: Color(0xFF1976D2),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      newReceiptDataUri = null;
                                    });
                                  },
                                  child: const Icon(
                                    Icons.cancel,
                                    color: Color(0xFFC01048),
                                    size: 20,
                                  ),
                                ),
                              ],
                            )
                          else if (existingImageUrl != null)
                            Row(
                              children: [
                                const Text(
                                  'Has Image',
                                  style: TextStyle(
                                    color: Color(0xFF1976D2),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      existingImageUrl = null;
                                    });
                                  },
                                  child: const Icon(
                                    Icons.cancel,
                                    color: Color(0xFFC01048),
                                    size: 20,
                                  ),
                                ),
                              ],
                            )
                          else
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFD0D5DD),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (pickedImage != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 80,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Bt.line),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<Uint8List>(
                            future: pickedImage!.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              }
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ] else if (newReceiptDataUri != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 80,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Bt.line),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(newReceiptDataUri!.split(',').last),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ] else if (existingImageUrl != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 80,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Bt.line),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            existingImageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final title = titleCtrl.text.trim();
                              var amount =
                                  double.tryParse(amountCtrl.text.trim()) ??
                                  0.0;
                              amount = amount.abs();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter a payment title',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter a valid amount',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setModalState(() {
                                isSaving = true;
                              });
                              if (!isInflow) {
                                amount = -amount;
                              }
                              try {
                                String? base64Image;
                                if (pickedImage != null) {
                                  final bytes = await pickedImage!
                                      .readAsBytes();
                                  base64Image =
                                      'data:image/jpeg;base64,${base64Encode(bytes)}';
                                }
                                final payload = {
                                  'title': title,
                                  'type': 'Income',
                                  'project': projectId,
                                  'amount': amount,
                                  'date': selectedDate.toIso8601String(),
                                  'paymentStatus': 'Paid',
                                  'paymentMode': selectedMode,
                                  'paidAmount': amount,
                                  'notes': notesCtrl.text.trim(),
                                  if (newReceiptDataUri != null) 'paymentReceipt': newReceiptDataUri,
                                  if (newReceiptDataUri != null) 'receiptImage': newReceiptDataUri,
                                  if (base64Image != null) 'receiptImage': base64Image,
                                  if (base64Image == null && newReceiptDataUri == null && editingTx != null)
                                    'attachments': existingImageUrl != null
                                        ? [existingImageUrl]
                                        : [],
                                };
                                final bool isEdit = editingTx != null;
                                final bool success;
                                if (isEdit) {
                                  final txId =
                                      editingTx['_id']?.toString() ??
                                      editingTx['id']?.toString() ??
                                      '';
                                  success = await ApiService.updateTransaction(
                                    txId,
                                    payload,
                                  );
                                } else {
                                  final result =
                                      await ApiService.addTransaction(payload);
                                  success = result != null;
                                }
                                if (success) {
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isEdit
                                              ? 'Revenue updated successfully'
                                              : 'Revenue recorded successfully',
                                        ),
                                      ),
                                    );
                                    context.read<ProjectProvider>().load();
                                    if (onSave != null) {
                                      onSave();
                                    } else {
                                      _loadRevenue(projectId);
                                    }
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isEdit
                                              ? 'Failed to update revenue'
                                              : 'Failed to record revenue',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setModalState(() {
                                    isSaving = false;
                                  });
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              editingTx != null ? 'Save Changes' : 'Save',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildRevenueHistory(BuildContext context) {
    if (_loadingRevenue) {
      return const BtSkeleton(height: 64, radius: 16);
    }
    final project = Provider.of<ProjectProvider>(
      context,
      listen: false,
    ).selectedProject;
    final projectName = project?.name ?? 'Project';
    if (project == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BtSectionHeader(title: 'Revenue inflow timeline'),
        BtGroup(children: [
          BtRow(
            leading: const BtTile(icon: Icons.receipt_long_outlined, bg: Bt.greenSoft, fg: Bt.green),
            title: 'View full revenue timeline',
            subtitle: _revenueEntries.isEmpty ? 'Click to view all logged inflows' : '${_revenueEntries.length} payments · ${formatInr(_totalRevenueSum, compact: true)} received',
            showChevron: true,
            onTap: () => _showAllRevenueHistory(context, projectName, project.id),
          ),
        ]),
      ],
    );
  }
  void _showAllRevenueHistory(
    BuildContext context,
    String projectName,
    String projectId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE4E7EC),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Revenue History',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    projectName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: textGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    _showAddRevenueDialog(
                                      context,
                                      projectId,
                                      onSave: () async {
                                        await _loadRevenue(projectId);
                                        setSheetState(() {});
                                      },
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryBlue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Record Payment',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: textDark,
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: _revenueEntries.length,
                            itemBuilder: (context, index) {
                              return _revenueTile(
                                context,
                                _revenueEntries[index],
                                onRefresh: () async {
                                  await _loadRevenue(projectId);
                                  setSheetState(() {});
                                },
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Bt.line),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primaryBlue.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet,
                                      color: primaryBlue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Total Balance',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _totalRevenueSum == 0
                                    ? '₹0'
                                    : (_totalRevenueSum < 0
                                          ? '-${formatCurrency(_totalRevenueSum.abs())}'
                                          : '+${formatCurrency(_totalRevenueSum)}'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _totalRevenueSum > 0
                                      ? const Color(0xFF067647)
                                      : (_totalRevenueSum < 0
                                            ? const Color(0xFFC01048)
                                            : textDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  void _showRevenueDetailDialog(
    BuildContext context,
    Map<String, dynamic> tx, {
    VoidCallback? onRefresh,
  }) {
    final title = tx['title']?.toString() ?? 'Revenue Inflow';
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
    final bool isOutflow = amount < 0;
    final absAmount = amount.abs();
    final formattedAmt = formatCurrency(absAmount);
    final textColor = isOutflow ? const Color(0xFFC01048) : const Color(0xFF067647);
    final paymentMode = tx['paymentMode']?.toString() ?? 'Cash';
    final paymentStatus = tx['paymentStatus']?.toString() ?? 'Paid';
    final rawId = tx['_id']?.toString() ?? tx['id']?.toString() ?? '';
    final refId = rawId.isNotEmpty ? rawId.toUpperCase() : 'N/A';
    final List<dynamic> attachments = tx['attachments'] is List
        ? tx['attachments'] as List
        : [];

    DateTime date = DateTime.now();
    if (tx['date'] != null) {
      try {
        date = DateTime.parse(tx['date'].toString()).toLocal();
      } catch (_) {}
    }
    final dateStr =
        '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)} ${date.year}';
    final timeStr = _formatTime12Hour(date);
    final project = Provider.of<ProjectProvider>(
      context,
      listen: false,
    ).selectedProject;
    final projectName = project?.name ?? 'Project';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 32),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4E7EC),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F3F5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: textGray,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isOutflow
                          ? const Color(0xFFFDECEF)
                          : const Color(0xFFE7F6EE),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: isOutflow ? const Color(0xFFC01048) : const Color(0xFF067647),
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isOutflow ? 'Payment Sent' : 'Revenue Received',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isOutflow ? '-$formattedAmt' : '+$formattedAmt',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 32,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: List.generate(
                      30,
                      (index) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 1,
                          color: index % 2 == 0
                              ? const Color(0xFFE4E7EC)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _receiptRow('PROJECT', projectName),
                  _receiptRow('PAYMENT METHOD', paymentMode),
                  _receiptRow(
                    isOutflow ? 'DATE SENT' : 'DATE RECEIVED',
                    dateStr,
                  ),
                  _receiptRow('TIME RECEIVED', timeStr),
                  _receiptRow('REFERENCE ID', refId),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textGray,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: paymentStatus.toLowerCase() == 'paid'
                                ? const Color(0xFFE7F6EE)
                                : const Color(0xFFFEF3E7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            paymentStatus.toUpperCase(),
                            style: TextStyle(
                              color: paymentStatus.toLowerCase() == 'paid'
                                  ? const Color(0xFF067647)
                                  : const Color(0xFFB54708),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tx['notes'] != null &&
                      tx['notes'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Bt.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notes / remarks',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textGray,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tx['notes'].toString().trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: textDark,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Bt.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Proof of payment',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textGray,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/receipt-viewer',
                                arguments: {
                                  'receipt': attachments.first.toString(),
                                },
                              );
                            },
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    attachments.first.toString(),
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 150,
                                        color: const Color(0xFFF6F7F9),
                                        alignment: Alignment.center,
                                        child: const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.broken_image_outlined,
                                              color: Color(0xFF667085),
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Error loading proof image',
                                              style: TextStyle(
                                                color: Color(0xFF667085),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Container(
                                            height: 150,
                                            color: const Color(0xFFF6F7F9),
                                            alignment: Alignment.center,
                                            child:
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                          );
                                        },
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.fullscreen,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tap to zoom',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      _shareTransactionReceipt(
                        context,
                        tx,
                        projectName,
                        title,
                        formattedAmt,
                        isOutflow,
                        dateStr,
                        timeStr,
                        refId,
                        attachments,
                      );
                    },
                    icon: Icon(Icons.share_outlined, color: primaryBlue),
                    label: Text(
                      'Share Receipt Summary',
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryBlue, width: 1.5),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _confirmDeleteTransaction(context, tx, onRefresh);
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFC01048),
                          ),
                          label: Text(
                            isOutflow ? 'Delete Outflow' : 'Delete Inflow',
                            style: const TextStyle(
                              color: Color(0xFFC01048),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFC01048)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAddRevenueDialog(
                              context,
                              project?.id ?? tx['project']?.toString() ?? '',
                              editingTx: tx,
                              onSave: onRefresh,
                            );
                          },
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                          ),
                          label: Text(
                            isOutflow ? 'Edit Outflow' : 'Edit Inflow',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  void _shareTransactionReceipt(
    BuildContext context,
    Map<String, dynamic> tx,
    String projectName,
    String title,
    String formattedAmt,
    bool isOutflow,
    String dateStr,
    String timeStr,
    String refId,
    List<dynamic> attachments,
  ) async {
    try {
      final typeLabel = isOutflow
          ? 'Money Out (Expense)'
          : 'Revenue Received (Inflow)';
      final amountPrefix = isOutflow ? '-₹' : '+₹';
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('📊 BuildTrack Transaction Receipt');
      buffer.writeln('================================');
      buffer.writeln('Type: $typeLabel');
      buffer.writeln('Title: $title');
      buffer.writeln('Amount: $amountPrefix$formattedAmt');
      buffer.writeln('Project: $projectName');
      buffer.writeln(
        'Payment Method: ${tx['paymentMode']?.toString() ?? 'Cash'}',
      );
      buffer.writeln('Date: $dateStr');
      buffer.writeln('Time: $timeStr');
      buffer.writeln('Reference ID: $refId');
      buffer.writeln(
        'Status: ${tx['paymentStatus']?.toString().toUpperCase() ?? 'PAID'}',
      );
      if (tx['notes'] != null && tx['notes'].toString().trim().isNotEmpty) {
        buffer.writeln('Notes: ${tx['notes'].toString().trim()}');
      }
      buffer.writeln('================================');
      buffer.writeln('Generated via BuildTrack App');
      if (attachments.isNotEmpty) {
        final attachmentUrl = attachments.first.toString();
        if (attachmentUrl.startsWith('http')) {
          buffer.writeln('\nProof of Payment: $attachmentUrl');
        }
      }
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          subject: 'Receipt Summary - $projectName',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing receipt: $e')));
      }
    }
  }
  void _confirmDeleteTransaction(
    BuildContext context,
    Map<String, dynamic> tx,
    VoidCallback? onRefresh,
  ) {
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
    final bool isOutflow = amount < 0;
    final String label = isOutflow ? 'outflow' : 'revenue inflow';
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(isOutflow ? 'Delete Outflow' : 'Delete Inflow'),
          content: Text(
            'Are you sure you want to delete this $label record? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF667085))),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final txId =
                    tx['_id']?.toString() ?? tx['id']?.toString() ?? '';
                final success = await ApiService.deleteTransaction(txId);
                if (success) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${isOutflow ? 'Outflow' : 'Revenue inflow'} record deleted successfully',
                        ),
                      ),
                    );
                    context.read<ProjectProvider>().load();
                    if (onRefresh != null) {
                      onRefresh();
                    }
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to delete ${isOutflow ? 'outflow' : 'revenue inflow'} record',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFC01048),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textGray,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _showFullScreenImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          color: Colors.white,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFFC01048),
                                size: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.black),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _revenueTile(
    BuildContext context,
    Map<String, dynamic> tx, {
    VoidCallback? onRefresh,
  }) {
    final title = tx['title']?.toString() ?? 'Revenue Inflow';
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
    final bool isOutflow = amount < 0;
    final absAmount = amount.abs();
    final formattedAmt = formatCurrency(absAmount);
    final textColor = isOutflow ? const Color(0xFFC01048) : const Color(0xFF067647);
    final paymentMode = tx['paymentMode']?.toString() ?? 'Cash';
    final List<dynamic> attachments = tx['attachments'] is List
        ? tx['attachments'] as List
        : [];
    final hasImage =
        attachments.isNotEmpty && attachments.first.toString().isNotEmpty;

    DateTime date = DateTime.now();
    if (tx['date'] != null) {
      try {
        date = DateTime.parse(tx['date'].toString()).toLocal();
      } catch (_) {}
    }
    final dateStr =
        '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)}';
    final timeStr = _formatTime12Hour(date);
    Widget thumbnail;
    if (hasImage) {
      final imageUrl = attachments.first.toString();
      thumbnail = GestureDetector(
        onTap: () {
          _showFullScreenImageDialog(context, imageUrl);
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Bt.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFF667085),
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else {
      thumbnail = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Bt.line),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: const Color(0xFFE4E7EC),
          size: 20,
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        _showRevenueDetailDialog(context, tx, onRefresh: onRefresh);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F6EE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                dateStr,
                style: const TextStyle(
                  color: Color(0xFF067647),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            thumbnail,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'via $paymentMode • $timeStr',
                    style: const TextStyle(fontSize: 13, color: textGray),
                  ),
                ],
              ),
            ),
            Text(
              isOutflow ? '-$formattedAmt' : '+$formattedAmt',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return 'Jan';
    return months[month - 1];
  }
  String _formatTime12Hour(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $amPm';
  }
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = _isGlobalView ? null : provider.selectedProject;

    double gBudget = 0;
    double gSpent = 0;
    double gRev = 0;
    double gProg = 0;
    if (_isGlobalView) {
      for (var p in provider.projects) {
        gBudget += p.totalBudget;
        gSpent += provider.totalSpentForProject(p.id);
        gRev += p.totalIncome;
        gProg += p.progress;
      }
      if (provider.projects.isNotEmpty) gProg /= provider.projects.length;
    }

    if (project != null && project.id != _lastProjectId) {
      _lastProjectId = project.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRevenue(project.id);
      });
    }

    final spent = _isGlobalView ? gSpent : (project != null ? provider.totalSpentForProject(project.id) : 0.0);
    final budget = _isGlobalView ? gBudget : (project?.totalBudget ?? 0.0);
    final remaining = _isGlobalView ? (gBudget - gSpent) : (project?.remainingBudget ?? 0.0);
    final revenue = _isGlobalView ? gRev : (project != null ? _totalRevenueSum : 0.0);
    final netCash = revenue - spent;
    final isLoss = netCash < 0;
    final progress = _isGlobalView ? gProg : (project?.progress ?? 0.0);
    final usedPct = budget > 0 ? (spent / budget) : 0.0;
    final over = budget > 0 && spent > budget * 0.9;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProjectSelector(context, provider),
        const SizedBox(height: 16),
        const ApprovalsAlertWidget(),
        // ── Money card: total cost, budget, revenue, net cash flow, planned ──
        Showcase(
          key: ShowcaseKeys.dashboardTotalCost,
          description: 'Track your total funds spent across all categories for this project.',
          tooltipBackgroundColor: Bt.ink,
          textColor: Colors.white,
          tooltipBorderRadius: BorderRadius.circular(16),
          tooltipPadding: const EdgeInsets.all(16),
          child: BtCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text('Total cost', style: BtText.subhead(context))),
                if (budget > 0) Text('of ${formatInr(budget, compact: true)} budget', style: BtText.num(BtText.caption(context))),
              ]),
              const SizedBox(height: 2),
              Text(_isGlobalView || project != null ? formatInr(spent, compact: true) : '—', style: BtText.amount(context)),
              const SizedBox(height: 12),
              BtProgress(value: usedPct.toDouble(), color: over ? Bt.red : null),
              const SizedBox(height: 6),
              Text(budget > 0 ? '${(usedPct * 100).toStringAsFixed(0)}% of budget used' : 'No budget set', style: BtText.caption(context, color: over ? Bt.red : Bt.ink3)),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Showcase(
                    key: ShowcaseKeys.dashboardTotalBudget,
                    description: 'Track the total allocated budget and remaining balance for this project.',
                    tooltipBackgroundColor: Bt.ink,
                    textColor: Colors.white,
                    tooltipBorderRadius: BorderRadius.circular(16),
                    tooltipPadding: const EdgeInsets.all(16),
                    child: _stat(context, 'Budget left', budget > 0 ? formatInr(remaining, compact: true) : '—', color: remaining < 0 ? Bt.red : Bt.ink),
                  ),
                ),
                Expanded(child: _stat(context, 'Upcoming / planned', budget > 0 ? formatInr(remaining < 0 ? 0 : remaining, compact: true) : '—')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Showcase(
                    key: ShowcaseKeys.dashboardTotalRevenue,
                    description: 'View the total revenue inflow recorded for this project.',
                    tooltipBackgroundColor: Bt.ink,
                    textColor: Colors.white,
                    tooltipBorderRadius: BorderRadius.circular(16),
                    tooltipPadding: const EdgeInsets.all(16),
                    child: _stat(context, 'Total revenue', formatInr(revenue, compact: true), color: Bt.green),
                  ),
                ),
                Expanded(
                  child: Showcase(
                    key: ShowcaseKeys.dashboardNetCashFlow,
                    description: 'See your net profit or loss calculated instantly.',
                    tooltipBackgroundColor: Bt.ink,
                    textColor: Colors.white,
                    tooltipBorderRadius: BorderRadius.circular(16),
                    tooltipPadding: const EdgeInsets.all(16),
                    child: _stat(context, isLoss ? 'Net cash flow · loss' : 'Net cash flow · profit', formatInr(netCash, compact: true), color: isLoss ? Bt.red : Bt.green),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // ── Overall progress ──
        Showcase(
          key: ShowcaseKeys.progress,
          description: 'Track your overall project completion here',
          tooltipBackgroundColor: Bt.ink,
          textColor: Colors.white,
          tooltipBorderRadius: BorderRadius.circular(16),
          tooltipPadding: const EdgeInsets.all(16),
          child: BtCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Overall progress', style: BtText.subhead(context)),
                    const SizedBox(height: 2),
                    Text(
                      _isGlobalView ? 'All projects' : (project?.name ?? 'No project'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BtText.body(context, weight: FontWeight.w600),
                    ),
                    if (project != null && project.city.isNotEmpty)
                      Text('${project.city[0].toUpperCase()}${project.city.substring(1)}', style: BtText.caption(context)),
                  ]),
                ),
                Text(_isGlobalView || project != null ? '${(progress * 100).toStringAsFixed(1)}%' : '--', style: BtText.amount(context, size: 28)),
              ]),
              const SizedBox(height: 12),
              BtProgress(value: progress.toDouble(), work: true),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        if (project != null) ...[
          _buildRevenueHistory(context),
          const SizedBox(height: 16),
        ],
        _buildSpeakUpdate(context),
        const SizedBox(height: 24),
        Showcase(
          key: ShowcaseKeys.recentEntries,
          description: 'Quickly view or edit your most recently added entries',
          tooltipBackgroundColor: Bt.ink,
          textColor: Colors.white,
          tooltipBorderRadius: BorderRadius.circular(16),
          tooltipPadding: const EdgeInsets.all(16),
          child: _buildRecentActivity(context),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value, {Color color = Bt.ink}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
        const SizedBox(height: 2),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.num(BtText.body(context, weight: FontWeight.w600, color: color))),
      ]),
    );
  }
  Widget _buildProjectSelector(BuildContext context, ProjectProvider provider) {
    final selectedName = _isGlobalView ? 'Global Financial Overview' : (provider.selectedProject?.name ?? 'Select Project');
    return Align(
      alignment: Alignment.centerLeft,
      child: BtChip(
        icon: Icons.apartment_outlined,
        label: selectedName.length > 34 ? '${selectedName.substring(0, 32)}…' : selectedName,
        trailingIcon: Icons.expand_more_rounded,
        onTap: () => _showProjectPicker(context, provider),
      ),
    );
  }
  void _showProjectPicker(BuildContext context, ProjectProvider provider) {
    final projects = provider.projects;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E7EC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Select Project',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() { _isGlobalView = true; });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: _isGlobalView ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isGlobalView ? AppColors.primary.withOpacity(0.3) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.public, color: _isGlobalView ? AppColors.primary : const Color(0xFF475467), size: 20),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Global Financial Overview (All Projects)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _isGlobalView ? FontWeight.w700 : FontWeight.w500,
                                    color: _isGlobalView ? AppColors.primary : AppColors.textDark,
                                  ),
                                ),
                              ),
                              if (_isGlobalView)
                                Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                              else
                                const Icon(Icons.chevron_right, color: Color(0xFFD0D5DD)),
                            ],
                          ),
                        ),
                      ),
                      ...projects.map((p) {
                      final selected = !_isGlobalView && p.id == provider.selectedProject?.id;
                      return InkWell(
                        onTap: () {
                          setState(() { _isGlobalView = false; }); provider.selectProject(p);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? primaryBlue.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? primaryBlue
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 18,
                                color: selected ? primaryBlue : textGray,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  p.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected ? primaryBlue : textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildSpeakUpdate(BuildContext context) {
    return Showcase(
      key: ShowcaseKeys.quickAddEntry,
      description: 'Quickly add a new entry from here.',
      tooltipBackgroundColor: Bt.ink,
      textColor: Colors.white,
      tooltipBorderRadius: BorderRadius.circular(16),
      tooltipPadding: const EdgeInsets.all(16),
      child: BtButton(
        label: 'Speak Update',
        icon: Icons.mic_rounded,
        variant: BtButtonVariant.accent,
        onPressed: () => Navigator.pushNamed(context, '/add-entry'),
      ),
    );
  }
  Widget _buildRecentActivity(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final selectedProjectId = provider.selectedProject?.id;
    final List<EntryModel> allEntries = selectedProjectId == null
        ? <EntryModel>[]
        : provider
              .entriesForProject(selectedProjectId)
              .where((e) => e.approvalStatus.toLowerCase().trim() != 'rejected')
              .toList();
    allEntries.sort((a, b) => b.date.compareTo(a.date));
    final recent = allEntries.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtSectionHeader(
          title: 'Recent activity',
          action: 'View all',
          onAction: () => Navigator.pushNamed(
            context,
            '/logs',
            arguments: {'projectId': selectedProjectId},
          ),
        ),
        _TeamApprovalHistoryWidget(projectId: selectedProjectId),
        const SizedBox(height: 20),
        const BtSectionHeader(title: 'Recent entries'),
        if (recent.isEmpty)
          const BtCard(
            child: BtEmpty(icon: Icons.history_toggle_off_rounded, title: 'No recent entries', message: 'Updates you speak or enter will appear here.'),
          )
        else
          BtGroup(children: [for (final entry in recent) _activityTile(context, entry)]),
      ],
    );
  }
  Widget _activityTile(BuildContext context, EntryModel entry) {
    final String badgeLabel;
    final BtTone tone;
    switch (entry.type) {
      case EntryType.labour:
        badgeLabel = 'Labour';
        tone = BtTone.green;
        break;
      case EntryType.equipment:
        badgeLabel = 'Equipment';
        tone = BtTone.amber;
        break;
      case EntryType.material:
        badgeLabel = 'Material';
        tone = BtTone.brand;
        break;
    }
    final timeLabel = relativeTimeLabel(entry.createdAt.toLocal());
    final title = entry.description.isNotEmpty ? entry.description : badgeLabel;
    return BtRow(
      leading: BtTypeTile(type: badgeLabel),
      title: title,
      subtitle: '${formatInr(entry.amount)} · $timeLabel',
      trailing: BtBadge(label: badgeLabel, tone: tone),
      onTap: () => Navigator.pushNamed(context, '/logs'),
    );
  }
}
class _SupervisorDashboard extends StatefulWidget {
  const _SupervisorDashboard();
  @override
  State<_SupervisorDashboard> createState() => _SupervisorDashboardState();
}
class _SupervisorDashboardState extends State<_SupervisorDashboard> {
  List<dynamic> _pendingTransactions = [];
  List<dynamic> _historyTransactions = [];
  List<TaskModel> _tasks = [];
  bool _isLoading = true;
  String? _error;
  String _activeTab = 'pending';
  @override
  void initState() {
    super.initState();
    _loadAll();
  }
  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiService.fetchPendingApprovals(),
      ApiService.fetchApprovalsHistory(),
      TaskService.getDailyTasks(),
    ]);
    if (!mounted) return;
    final pendingData = results[0] as Map<String, dynamic>?;
    final historyData = results[1] as Map<String, dynamic>?;
    final tasksData = results[2] as List<TaskModel>;
    setState(() {
      _pendingTransactions = (pendingData?['transactions'] as List?) ?? [];
      _historyTransactions = (historyData?['transactions'] as List?) ?? [];
      _tasks = tasksData;
      _isLoading = false;
      if (pendingData == null && historyData == null) {
        _error = 'Failed to load data';
      }
    });
  }
  Future<void> _handleApprove(String id) async {
    final ok = await ApiService.approveTransaction(id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction approved'),
          backgroundColor: Color(0xFF067647),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to approve'),
          backgroundColor: Color(0xFFC01048),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  Future<void> _handleReject(String id) async {
    final ok = await ApiService.rejectTransaction(id, 'Rejected by supervisor');
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction rejected'),
          backgroundColor: Color(0xFFC01048),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadAll();
    }
  }
  Future<void> _confirmReject(String id) async {
    final ok = await btConfirm(context, title: 'Reject this entry?', message: 'The person who logged it will see it as rejected.', confirmLabel: 'Reject');
    if (ok) _handleReject(id);
  }
  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingTransactions.length;
    final approvedCount = _historyTransactions
        .where((t) => t['approvalStatus'] == 'Approved')
        .length;
    final rejectedCount = _historyTransactions
        .where((t) => t['approvalStatus'] == 'Rejected')
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtSegmented<String>(
          segments: {
            'pending': 'Pending · $pendingCount',
            'approved': 'Approved · $approvedCount',
            'rejected': 'Rejected · $rejectedCount',
          },
          value: _activeTab,
          onChanged: (v) => setState(() => _activeTab = v),
        ),
        const SizedBox(height: 12),
        Row(children: [
          if (RoleManager.canAssignTasks) ...[
            Expanded(child: BtButton(label: 'Assign Task', icon: Icons.assignment_turned_in_outlined, small: true, onPressed: () => Navigator.pushNamed(context, '/assign-task'))),
            const SizedBox(width: 8),
          ],
          Expanded(child: BtButton(label: 'Refresh', icon: Icons.refresh_rounded, small: true, variant: BtButtonVariant.secondary, onPressed: _loadAll)),
        ]),
        const SizedBox(height: 24),
        const BtSectionHeader(title: 'Tasks assigned'),
        if (_tasks.isEmpty)
          const BtCard(child: BtEmpty(icon: Icons.task_alt, title: 'No tasks currently active.'))
        else
          BtGroup(children: [
            for (final task in _tasks)
              _TaskCard(
                task: task,
                onEdit: () => Navigator.pushNamed(context, '/update-progress', arguments: {'task': task}).then((_) {
                  if (context.mounted) _loadAll();
                }),
              ),
          ]),
        const SizedBox(height: 24),
        if (_isLoading)
          const BtSkeletonList(count: 3)
        else if (_error != null)
          BtErrorCard(message: _error!, onRetry: _loadAll)
        else
          _buildActiveTabContent(
            pendingCount: pendingCount,
            approvedCount: approvedCount,
            rejectedCount: rejectedCount,
          ),
      ],
    );
  }
  Widget _buildActiveTabContent({
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
  }) {
    switch (_activeTab) {
      case 'approved':
        final approved = _historyTransactions
            .where((t) => t['approvalStatus'] == 'Approved')
            .toList();
        return _buildHistoryList(
          items: approved,
          emptyMessage: 'No approved entries yet',
          emptyIcon: Icons.check_circle_outline,
          emptyColor: Bt.green,
        );
      case 'rejected':
        final rejected = _historyTransactions
            .where((t) => t['approvalStatus'] == 'Rejected')
            .toList();
        return _buildHistoryList(
          items: rejected,
          emptyMessage: 'No rejected entries',
          emptyIcon: Icons.cancel_outlined,
          emptyColor: Bt.red,
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pendingCount == 0)
              const BtCard(child: BtEmpty(icon: Icons.check_circle_outline, title: 'No pending approvals', message: 'Pull down to refresh'))
            else ...[
              const BtSectionHeader(title: 'Pending approvals'),
              BtGroup(children: [
                for (final tx in _pendingTransactions)
                  _PendingTxCard(
                    tx: tx as Map<String, dynamic>,
                    onApprove: () => _handleApprove(tx['_id']?.toString() ?? ''),
                    onReject: () => _confirmReject(tx['_id']?.toString() ?? ''),
                  ),
              ]),
            ],
            const SizedBox(height: 24),
            _buildRecentHistorySection(),
          ],
        );
    }
  }
  Widget _buildRecentHistorySection() {
    final combined =
        _historyTransactions
            .where(
              (t) =>
                  t['approvalStatus'] == 'Approved' ||
                  t['approvalStatus'] == 'Rejected',
            )
            .toList()
          ..sort((a, b) {
            DateTime parse(dynamic tx) {
              final raw = tx['approvedAt'] ?? tx['date'] ?? tx['createdAt'];
              try {
                return DateTime.parse(raw.toString()).toLocal();
              } catch (_) {
                return DateTime.fromMillisecondsSinceEpoch(0);
              }
            }
            return parse(b).compareTo(parse(a));
          });
    final recent = combined.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BtSectionHeader(title: 'Recent history'),
        if (recent.isEmpty)
          const BtCard(child: BtEmpty(icon: Icons.history, title: 'No history yet'))
        else
          BtGroup(children: [for (final tx in recent) _HistoryTxCard(tx: tx as Map<String, dynamic>)]),
      ],
    );
  }
  Widget _buildHistoryList({
    required List<dynamic> items,
    required String emptyMessage,
    required IconData emptyIcon,
    required Color emptyColor,
  }) {
    if (items.isEmpty) {
      return BtCard(
        child: BtEmpty(icon: emptyIcon, title: emptyMessage, message: 'Total history loaded: ${_historyTransactions.length}'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtSectionHeader(title: _activeTab == 'approved' ? 'Recently approved' : 'Recently rejected'),
        BtGroup(children: [for (final tx in items) _HistoryTxCard(tx: tx as Map<String, dynamic>)]),
      ],
    );
  }
}
class _PendingTxCard extends StatelessWidget {
  const _PendingTxCard({
    required this.tx,
    required this.onApprove,
    required this.onReject,
  });
  final Map<String, dynamic> tx;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  @override
  Widget build(BuildContext context) {
    final title = tx['title']?.toString() ?? 'Entry';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final type = tx['type']?.toString() ?? '';
    final role = _txRole(tx);
    final dateStr = _txDate(tx['date'] ?? tx['createdAt']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BtTypeTile(type: _txTypeWord(type, title)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w500)),
              Text('${_txWho(tx)}${role.isNotEmpty ? ' · $role' : ''}', style: BtText.caption(context)),
              Text([_txProject(tx), dateStr].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(formatInr(amount), style: BtText.num(BtText.body(context, weight: FontWeight.w600))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: BtButton(label: 'Reject', variant: BtButtonVariant.destructive, small: true, onPressed: onReject)),
          const SizedBox(width: 10),
          Expanded(child: BtButton(label: 'Approve', icon: Icons.check_rounded, small: true, onPressed: onApprove)),
        ]),
      ]),
    );
  }
}
class _HistoryTxCard extends StatelessWidget {
  const _HistoryTxCard({required this.tx});
  final Map<String, dynamic> tx;
  @override
  Widget build(BuildContext context) {
    final title = tx['title']?.toString() ?? 'Entry';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final type = tx['type']?.toString() ?? '';
    final approvalStatus = tx['approvalStatus']?.toString() ?? '';
    final approvedByName =
        (tx['approvedBy'] is Map ? tx['approvedBy']['name'] : null)?.toString();
    final rejectionReason = tx['rejectionReason']?.toString() ?? '';
    final dateStr = _txDate(tx['approvedAt'] ?? tx['date'] ?? tx['createdAt']);
    final bool isApproved = approvalStatus == 'Approved';
    final lines = <String>[
      _txWho(tx),
      [_txProject(tx), dateStr].where((x) => x.isNotEmpty).join(' · '),
      if (approvedByName != null) isApproved ? 'Approved by $approvedByName' : 'Rejected by $approvedByName',
      if (!isApproved && rejectionReason.isNotEmpty) 'Reason: $rejectionReason',
    ];
    return BtRow(
      leading: BtTypeTile(type: _txTypeWord(type, title)),
      title: title,
      subtitle: lines.join('\n'),
      subtitleMaxLines: 4,
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(formatInr(amount), style: BtText.num(BtText.body(context, weight: FontWeight.w600))),
        const SizedBox(height: 4),
        BtBadge(label: approvalStatus, tone: isApproved ? BtTone.green : BtTone.red),
      ]),
    );
  }
}
class _MasonDashboard extends StatefulWidget {
  const _MasonDashboard({required this.onEntryTap});
  final void Function(BuildContext, String) onEntryTap;
  @override
  State<_MasonDashboard> createState() => _MasonDashboardState();
}
class _MasonDashboardState extends State<_MasonDashboard> {
  late Future<List<dynamic>> _recentEntriesFuture;
  List<TaskModel> _tasks = [];
  bool _isLoadingTasks = true;
  @override
  void initState() {
    super.initState();
    final projectId = context.read<ProjectProvider>().selectedProject?.id;
    _recentEntriesFuture = ApiService.fetchMyRecentEntries(
      projectId: projectId,
    );
    _loadTasks();
  }
  Future<void> _loadTasks() async {
    try {
      final tasks = await TaskService.getDailyTasks();
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Good Morning, ${UserSession.roleLabel}', style: BtText.headline(context)),
            Text('Ready for today\'s work', style: BtText.subhead(context)),
            const SizedBox(height: 14),
            BtButton(
              label: 'Add Daily Update',
              icon: Icons.add_task_rounded,
              onPressed: () => Navigator.pushNamed(context, '/update-progress'),
            ),
            const SizedBox(height: 10),
            BtButton(
              label: 'Add Material Entry',
              icon: Icons.inventory_2_outlined,
              variant: BtButtonVariant.secondary,
              onPressed: () => widget.onEntryTap(context, 'material'),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        const BtSectionHeader(title: 'Tasks assigned'),
        if (_isLoadingTasks)
          const BtSkeletonList(count: 2)
        else if (_tasks.isEmpty)
          const BtCard(child: BtEmpty(icon: Icons.task_alt, title: 'No tasks currently active.'))
        else
          BtGroup(children: [
            for (final task in _tasks)
              _TaskCard(
                task: task,
                onEdit: task.status != 'Completed'
                    ? () => Navigator.pushNamed(context, '/update-progress', arguments: {'task': task}).then((_) {
                        if (context.mounted) _loadTasks();
                      })
                    : null,
              ),
          ]),
        const SizedBox(height: 24),
        BtSectionHeader(
          title: 'Recent entries',
          action: 'View all',
          onAction: () => Navigator.pushNamed(context, '/logs'),
        ),
        FutureBuilder<List<dynamic>>(
          future: _recentEntriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const BtSkeletonList(count: 3);
            }
            if (snapshot.hasError) {
              return const BtErrorCard(message: 'Failed to load recent entries.');
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const BtCard(child: BtEmpty(icon: Icons.inbox_outlined, title: 'No entries yet'));
            }
            return BtGroup(children: [
              for (final e in entries.take(5)) _recentEntryTile(e as Map<String, dynamic>),
            ]);
          },
        ),
      ],
    );
  }
  Widget _recentEntryTile(Map<String, dynamic> entry) {
    final title =
        entry['title']?.toString() ??
        entry['description']?.toString() ??
        'Entry';
    final type = entry['type']?.toString() ?? '';
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0.0;
    final approvalStatus = entry['approvalStatus']?.toString() ?? 'Pending';
    final rawDate = entry['date'] ?? entry['createdAt'];
    String timeLabel = '';
    if (rawDate != null) {
      try {
        final d = DateTime.parse(rawDate.toString()).toLocal();
        timeLabel = relativeTimeLabel(d);
      } catch (_) {}
    }
    return BtRow(
      leading: BtTypeTile(type: _txTypeWord(type, title)),
      title: title,
      subtitle: [formatInr(amount), timeLabel].where((x) => x.isNotEmpty).join(' · '),
      trailing: BtBadge(label: approvalStatus, tone: BtBadge.toneFor(approvalStatus)),
      onTap: () => Navigator.pushNamed(context, '/logs'),
    );
  }
}
class ApprovalsAlertWidget extends StatefulWidget {
  const ApprovalsAlertWidget({super.key});
  @override
  State<ApprovalsAlertWidget> createState() => _ApprovalsAlertWidgetState();
}
class _ApprovalsAlertWidgetState extends State<ApprovalsAlertWidget> {
  int _pendingCount = 0;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    _loadCount();
  }
  Future<void> _loadCount() async {
    final data = await ApiService.fetchPendingApprovals();
    if (mounted) {
      setState(() {
        final txs = (data?['transactions'] as List?)?.length ?? 0;
        final updates = (data?['projectUpdates'] as List?)?.length ?? 0;
        _pendingCount = txs + updates;
        _loaded = true;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_loaded && _pendingCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BtCard(
        variant: BtCardVariant.attention,
        onTap: () => Navigator.pushNamed(context, '/approvals'),
        child: Row(children: [
          BtTile(icon: Icons.inbox_outlined, bg: context.bt.brandSoft, fg: context.bt.brand, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _loaded ? '$_pendingCount Approval${_pendingCount == 1 ? "" : "s"} Pending' : 'Checking Approvals…',
                style: BtText.headline(context),
              ),
              const SizedBox(height: 2),
              Text('Review pending project updates and expenses.', style: BtText.subhead(context)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Bt.placeholder),
        ]),
      ),
    );
  }
}
class _TeamApprovalHistoryWidget extends StatefulWidget {
  final String? projectId;
  const _TeamApprovalHistoryWidget({this.projectId});
  @override
  State<_TeamApprovalHistoryWidget> createState() =>
      _TeamApprovalHistoryWidgetState();
}
class _TeamApprovalHistoryWidgetState
    extends State<_TeamApprovalHistoryWidget> {
  List<dynamic> _history = [];
  bool _loading = true;
  bool _expanded = false;
  @override
  void initState() {
    super.initState();
    _load();
  }
  @override
  void didUpdateWidget(_TeamApprovalHistoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      setState(() {
        _loading = true;
        _history = [];
        _expanded = false;
      });
      _load();
    }
  }
  Future<void> _load() async {
    try {
      final data = await ApiService.fetchApprovalsHistory();
      final List<dynamic> all = (data?['transactions'] as List?) ?? [];
      final filtered =
          all.where((t) {
            final status = (t['approvalStatus']?.toString() ?? '')
                .trim()
                .toLowerCase();
            final isActioned = status == 'approved' || status == 'rejected';
            if (!isActioned) return false;
            final createdByRole =
                (t['createdBy'] is Map ? t['createdBy']['role'] : null)
                    ?.toString()
                    .toLowerCase()
                    .trim();
            if (createdByRole == 'admin') return false;
            if (widget.projectId != null &&
                widget.projectId!.trim().isNotEmpty) {
              String txProjectId = '';
              final rawProj = t['project'];
              if (rawProj is Map) {
                txProjectId = rawProj['_id']?.toString() ?? '';
              } else if (rawProj != null) {
                txProjectId = rawProj.toString();
              }
              final wantedId = widget.projectId!.trim();
              if (txProjectId.trim().isNotEmpty &&
                  txProjectId.trim() != wantedId) {
                return false;
              }
            }
            return true;
          }).toList()..sort((a, b) {
            DateTime parse(dynamic tx) {
              final raw =
                  tx['approvedAt'] ??
                  tx['rejectedAt'] ??
                  tx['date'] ??
                  tx['createdAt'];
              try {
                return DateTime.parse(raw.toString()).toLocal();
              } catch (_) {
                return DateTime.fromMillisecondsSinceEpoch(0);
              }
            }
            return parse(b).compareTo(parse(a));
          });
      final approvedCount = filtered
          .where(
            (t) =>
                (t['approvalStatus']?.toString().toLowerCase().trim() ?? '') ==
                'approved',
          )
          .length;
      final rejectedCount = filtered
          .where(
            (t) =>
                (t['approvalStatus']?.toString().toLowerCase().trim() ?? '') ==
                'rejected',
          )
          .length;
      debugPrint(
        'TeamApprovalHistory[project=${widget.projectId}]: '
        'rawUnscoped=${all.length} filtered=${filtered.length} '
        'approved=$approvedCount rejected=$rejectedCount',
      );
      if (mounted) {
        setState(() {
          _history = filtered.take(15).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BtSkeleton(height: 120, radius: 16);
    }
    final shown = _expanded ? _history : _history.take(3).toList();
    return BtGroup(
      insetDividers: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(children: [
            const Icon(Icons.groups_outlined, size: 20, color: Bt.ink2),
            const SizedBox(width: 10),
            Expanded(child: Text('Team approval history', style: BtText.body(context, weight: FontWeight.w600))),
            if (_history.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show less' : 'Show all', style: BtText.subhead(context, weight: FontWeight.w600, color: context.bt.brand)),
              ),
          ]),
        ),
        if (_history.isEmpty)
          const BtEmpty(icon: Icons.fact_check_outlined, title: 'No approval requests yet')
        else
          for (final tx in shown) _historyTile(tx as Map<String, dynamic>),
      ],
    );
  }
  Widget _historyTile(Map<String, dynamic> tx) {
    final title = tx['title']?.toString() ?? 'Entry';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final approvalStatus = tx['approvalStatus']?.toString() ?? '';
    final createdByRole = _txRole(tx);
    final approvedByName =
        (tx['approvedBy'] is Map ? tx['approvedBy']['name'] : null)?.toString();
    final type = tx['type']?.toString() ?? '';
    String dateStr = '';
    final rawDate = tx['approvedAt'] ?? tx['date'] ?? tx['createdAt'];
    if (rawDate != null) {
      try {
        final d = DateTime.parse(rawDate.toString()).toLocal();
        dateStr = relativeTimeLabel(d);
      } catch (_) {}
    }
    final isApproved = approvalStatus == 'Approved';
    final lines = <String>[
      'By ${_txWho(tx)}${createdByRole.isNotEmpty ? ' · $createdByRole' : ''}${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
      if (approvedByName != null) isApproved ? 'Approved by $approvedByName' : 'Rejected by $approvedByName',
    ];
    return BtRow(
      leading: BtTypeTile(type: _txTypeWord(type, title)),
      title: title,
      subtitle: lines.join('\n'),
      subtitleMaxLines: 3,
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(formatInr(amount), style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
        const SizedBox(height: 4),
        BtBadge(label: approvalStatus, tone: isApproved ? BtTone.green : BtTone.red),
      ]),
    );
  }
}

// ───────── Redesign helpers for home cards ─────────
String _txWho(Map<String, dynamic> tx) =>
    (tx['createdBy'] is Map ? tx['createdBy']['name'] : null)?.toString() ?? 'Unknown';
String _txRole(Map<String, dynamic> tx) =>
    (tx['createdBy'] is Map ? tx['createdBy']['role'] : null)?.toString() ?? '';
String _txProject(Map<String, dynamic> tx) =>
    (tx['project'] is Map ? tx['project']['projectName'] : null)?.toString() ?? 'Unknown Project';
String _txDate(dynamic raw) {
  if (raw == null) return '';
  try {
    return formatDate(DateTime.parse(raw.toString()).toLocal());
  } catch (_) {
    return '';
  }
}
String _txTypeWord(String type, String title) {
  switch (type.toLowerCase()) {
    case 'wages':
      return 'labour';
    case 'expense':
      return 'equipment';
    default:
      return '$type $title';
  }
}
