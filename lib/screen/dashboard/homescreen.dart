import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/models/task_model.dart';
import 'package:buildtrack_mobile/services/task_service.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/common/themes/app_gradients.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/nurofin_scaffold.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/controller/subscription_provider.dart';
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/screen/dashboard/notifications_bell.dart';

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
        const TooltipActionButton(
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
    keys.add(ShowcaseKeys.sidebarMenu);
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
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.only(
                top: 60,
                bottom: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BuildTrack Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Role: ${UserSession.roleLabel}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.supervisor_account_outlined,
                color: AppColors.textDark,
              ),
              title: const Text(
                'Team Overview',
                style: TextStyle(color: AppColors.textDark),
              ),
              onTap: () => Navigator.pushNamed(context, '/admin-overview'),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.textDark),
              title: const Text(
                'Profile',
                style: TextStyle(color: AppColors.textDark),
              ),
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppColors.textDark),
              title: const Text(
                'App Guidelines',
                style: TextStyle(color: AppColors.textDark),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                final keysToShow = _getShowcaseKeys(isReplay: true);
                if (keysToShow.isNotEmpty) {
                  ShowcaseView.get().startShowCase(keysToShow);
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A6CF7), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              title: const Text(
                'Upgrade Plan',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Consumer<SubscriptionProvider>(
                builder: (context, sub, _) => Text(
                  sub.currentPlan.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ),
              onTap: () => Navigator.pushNamed(context, '/subscription'),
            ),
            if (UserSession.isAdmin) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.only(left: 16.0, top: 12.0, bottom: 8.0),
                child: Text(
                  'Admin Controls',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.workspaces_outline,
                  color: AppColors.textDark,
                ),
                title: const Text(
                  'Create Workspace',
                  style: TextStyle(color: AppColors.textDark),
                ),
                onTap: () => Navigator.pushNamed(context, '/create-workspace'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.manage_accounts_outlined,
                  color: AppColors.textDark,
                ),
                title: const Text(
                  'Assign Roles',
                  style: TextStyle(color: AppColors.textDark),
                ),
                onTap: () => Navigator.pushNamed(context, '/assign-role'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.textDark,
                ),
                title: const Text(
                  'Transaction Logs',
                  style: TextStyle(color: AppColors.textDark),
                ),
                onTap: () => Navigator.pushNamed(context, '/logs'),
              ),
            ],
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    _checkTour(context.watch<ProjectProvider>());
    return NurofinScaffold(
      drawer: _buildDrawer(context),
      body: SafeArea(
        bottom: false,
        child: Builder(
          builder: (ctx) => Column(
            children: [
              Showcase(
                key: ShowcaseKeys.sidebarMenu,
                description: 'Tap the menu icon to access Logs, Inventory, Subscriptions, and Roles.',
                tooltipBackgroundColor: const Color(0xFF1E1E2C),
                textColor: Colors.white,
                tooltipBorderRadius: BorderRadius.circular(16),
                tooltipPadding: const EdgeInsets.all(16),
                child: AppTopBar(
                  title: 'BuildTrack',
                  leftIcon: Icons.menu,
                  onLeftTap: () => Scaffold.of(ctx).openDrawer(),
                  rightWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Showcase(
                        key: ShowcaseKeys.helpButton,
                        description: 'Tap here anytime to replay this tour and get help.',
                        tooltipBackgroundColor: const Color(0xFF1E1E2C),
                        textColor: Colors.white,
                        tooltipBorderRadius: BorderRadius.circular(16),
                        tooltipPadding: const EdgeInsets.all(16),
                        child: GestureDetector(
                          onTap: () {
                            final keysToShow = _getShowcaseKeys(isReplay: true);
                            if (keysToShow.isNotEmpty) {
                              ShowcaseView.get().startShowCase(keysToShow);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.help_outline,
                              color: AppColors.primary,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const NotificationsBell(),
                    const SizedBox(width: 8),
                    Showcase(
                      key: ShowcaseKeys.profileIcon,
                      description: 'Tap your profile icon to view your account details and settings.',
                      tooltipBackgroundColor: const Color(0xFF1E1E2C),
                      textColor: Colors.white,
                      tooltipBorderRadius: BorderRadius.circular(16),
                      tooltipPadding: const EdgeInsets.all(16),
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                        child: const ProfileAvatar(radius: 17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (UserSession.isAdmin || RoleManager.canViewReports || RoleManager.canManageExpenses)
                        _AdminDashboard(onEntryTap: _showEntryOptions),
                      if (UserSession.isSupervisor)
                        const _SupervisorDashboard(),
                      if (UserSession.isMason)
                        _MasonDashboard(onEntryTap: _showEntryOptions),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onEdit;
  const _TaskCard({required this.task, this.onEdit});
  @override
  Widget build(BuildContext context) {
    String displayStatus = task.status;
    Color statusColor = AppColors.primary;
    Color statusBg = AppColors.primary.withValues(alpha: 0.1);
    try {
      final projects = context.read<ProjectProvider>().projects;
      final proj = projects.cast<dynamic>().firstWhere(
        (p) => p.id == task.project,
        orElse: () => null,
      );
      if (proj != null && task.activityName != null) {
        final phases = proj.selectedPhases ?? [];
        for (var phase in phases) {
          for (var act in phase.activities) {
              if (act.name == task.activityName) {
                break;
              }
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating task status: $e');
    }
    if (displayStatus == 'Completed') {
      statusColor = Colors.green;
      statusBg = Colors.green.withValues(alpha: 0.1);
    } else if (displayStatus == 'Work in Progress') {
      statusColor = Colors.orange;
      statusBg = Colors.orange.withValues(alpha: 0.1);
    }
    return GestureDetector(
      onTap: displayStatus != 'Completed' ? onEdit : null,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                if (displayStatus != 'Completed' && onEdit != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.edit,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (task.description.isNotEmpty) ...[
              Text(
                task.description,
                style: const TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 4),
                Text(
                  'Assigned to: ${task.assignee ?? "Unassigned"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 4),
                Text(
                  task.floorName ?? 'On Site',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
Future<void> _showEditTaskDialog(
  BuildContext context,
  TaskModel task,
  VoidCallback onSave,
) async {
  String? updatedStatus = task.status;
  final TextEditingController titleCtrl = TextEditingController(
    text: task.title,
  );
  final TextEditingController descCtrl = TextEditingController(
    text: task.description,
  );
  bool saving = false;
  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Title',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Status',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue:
                        [
                          'Not Started',
                          'In Progress',
                          'Completed',
                        ].contains(updatedStatus)
                        ? updatedStatus
                        : 'Not Started',
                    items: ['Not Started', 'In Progress', 'Completed']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        updatedStatus = v;
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          await TaskService.updateTask(task.id, {
                            'title': titleCtrl.text,
                            'description': descCtrl.text,
                            'status': updatedStatus,
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            onSave();
                          }
                        } catch (e) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard({required this.onEntryTap});
  final void Function(BuildContext, String) onEntryTap;
  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}
class _AdminDashboardState extends State<_AdminDashboard> {
  static const primaryBlue = AppColors.primary;
  static const textDark = AppColors.textDark;
  static const textGray = AppColors.textLight;
  List<dynamic> _revenueEntries = [];
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
              DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.now();
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
        selectedDate = DateTime.parse(editingTx!['date'].toString());
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
                        color: const Color(0xFFDDE0F0),
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
                      fontWeight: FontWeight.w800,
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
                                  ? const Color(0xFFE8F5E9)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isInflow
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey[300]!,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  color: isInflow
                                      ? const Color(0xFF2E7D32)
                                      : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Money In',
                                  style: TextStyle(
                                    color: isInflow
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey,
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
                                  ? const Color(0xFFFFEBEE)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: !isInflow
                                    ? Colors.red
                                    : Colors.grey[300]!,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  color: !isInflow ? Colors.red : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Money Out',
                                  style: TextStyle(
                                    color: !isInflow ? Colors.red : Colors.grey,
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
                      border: UnderlineInputBorder(),
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
                      border: const UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      border: UnderlineInputBorder(),
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
                      activeColor: const Color(0xFF173EEA),
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
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF173EEA))),
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
                            backgroundColor: isEsignPolling ? Colors.red : const Color(0xFF173EEA),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(isEsignPolling ? 'Cancel Polling' : 'Send for E-Signature', style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                      if (esignStatusText.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 8), child: Text(esignStatusText, style: TextStyle(color: isEsignPolling ? Colors.orange : (isEsignCompleted ? Colors.green : Colors.red), fontWeight: FontWeight.bold)))
                    ],
                    if (isEsignCompleted) ...[
                       const SizedBox(height: 8),
                       Container(
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                         child: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Signature successfully captured!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))])
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
                          bottom: BorderSide(color: Colors.black26),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Date Received',
                            style: TextStyle(color: Colors.black54),
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
                      border: const UnderlineInputBorder(),
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
                          bottom: BorderSide(color: Colors.black26),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: Colors.black54,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Upload Receipt Proof (Optional)',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                          if (pickedImage != null)
                            Row(
                              children: [
                                const Text(
                                  'Selected',
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
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
                                    color: Colors.red,
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
                                    color: Colors.red,
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
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ),
                              ],
                            )
                          else
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.black26,
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
                          border: Border.all(color: Colors.grey[300]!),
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
                          border: Border.all(color: Colors.grey[300]!),
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
                                    color: Colors.grey,
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
                          border: Border.all(color: Colors.grey[300]!),
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
                                    color: Colors.grey,
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final project = Provider.of<ProjectProvider>(
      context,
      listen: false,
    ).selectedProject;
    final projectName = project?.name ?? 'Project';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Revenue Inflow Timeline'),
        const SizedBox(height: 8),
        if (project != null)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () =>
                  _showAllRevenueHistory(context, projectName, project.id),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[100]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Color(0xFF2E7D32),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'View Full Revenue Timeline',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Click to view all logged inflows',
                              style: TextStyle(fontSize: 12, color: textGray),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(Icons.chevron_right, color: textGray, size: 20),
                  ],
                ),
              ),
            ),
          ),
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
                              color: Colors.grey[300],
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
                                      fontSize: 12,
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
                                            fontSize: 12,
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
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, -4),
                              ),
                            ],
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
                                  fontWeight: FontWeight.w800,
                                  color: _totalRevenueSum > 0
                                      ? const Color(0xFF2E7D32)
                                      : (_totalRevenueSum < 0
                                            ? Colors.red
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
    final textColor = isOutflow ? Colors.red : const Color(0xFF2E7D32);
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
        date = DateTime.parse(tx['date'].toString());
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
                          color: Colors.grey[300],
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
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: isOutflow ? Colors.red : const Color(0xFF2E7D32),
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isOutflow ? 'Payment Sent' : 'Revenue Received',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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
                      fontWeight: FontWeight.w900,
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
                              ? Colors.grey[300]
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
                          'STATUS',
                          style: TextStyle(
                            fontSize: 12,
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
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            paymentStatus.toUpperCase(),
                            style: TextStyle(
                              color: paymentStatus.toLowerCase() == 'paid'
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFE65100),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
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
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NOTES / REMARKS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
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
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PROOF OF PAYMENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
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
                                        color: Colors.grey[100],
                                        alignment: Alignment.center,
                                        child: const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.broken_image_outlined,
                                              color: Colors.grey,
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Error loading proof image',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
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
                                            color: Colors.grey[100],
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
                                          fontSize: 10,
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
                    icon: const Icon(Icons.share_outlined, color: primaryBlue),
                    label: const Text(
                      'Share Receipt Summary',
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primaryBlue, width: 1.5),
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
                            color: Colors.red,
                          ),
                          label: Text(
                            isOutflow ? 'Delete Outflow' : 'Delete Inflow',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
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
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                  color: Colors.red,
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
              fontSize: 12,
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
                                color: Colors.red,
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
    final textColor = isOutflow ? Colors.red : const Color(0xFF2E7D32);
    final paymentMode = tx['paymentMode']?.toString() ?? 'Cash';
    final List<dynamic> attachments = tx['attachments'] is List
        ? tx['attachments'] as List
        : [];
    final hasImage =
        attachments.isNotEmpty && attachments.first.toString().isNotEmpty;

    DateTime date = DateTime.now();
    if (tx['date'] != null) {
      try {
        date = DateTime.parse(tx['date'].toString());
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
            border: Border.all(color: Colors.grey[200]!),
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
                    color: Colors.grey,
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
          border: Border.all(color: Colors.grey[200]!),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey[300],
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                dateStr,
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
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
                    style: const TextStyle(fontSize: 12, color: textGray),
                  ),
                ],
              ),
            ),
            Text(
              isOutflow ? '-$formattedAmt' : '+$formattedAmt',
              style: TextStyle(
                fontWeight: FontWeight.w800,
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
    final project = provider.selectedProject;
    if (project != null && project.id != _lastProjectId) {
      _lastProjectId = project.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRevenue(project.id);
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProjectSelector(context, provider),
        const SizedBox(height: 16),
        const ApprovalsAlertWidget(),
        const SizedBox(height: 16),
        Showcase(
          key: ShowcaseKeys.progress,
          description: 'Track your overall project completion here',
          tooltipBackgroundColor: const Color(0xFF1E1E2C),
          textColor: Colors.white,
          tooltipBorderRadius: BorderRadius.circular(16),
          tooltipPadding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B7280).withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'OVERALL PROGRESS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (project != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: textGray,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${project.city[0].toUpperCase()}${project.city.substring(1)}',
                          style: const TextStyle(
                            color: textGray,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    project != null
                        ? '${(project.progress * 100).toStringAsFixed(1)}%'
                        : '—',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                      letterSpacing: -1.0,
                    ),
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          project?.name ?? 'No project',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Current Milestone',
                          style: TextStyle(
                            color: textGray.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1EEFA),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: (project?.progress ?? 0).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppGradients.progressBar,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPurple.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress status',
                        style: TextStyle(
                          color: textGray.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        project != null
                            ? '${(project.progress * 100).toStringAsFixed(0)}% Completed'
                            : '—',
                        style: const TextStyle(
                          color: AppColors.primaryPurple,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Showcase(
                key: ShowcaseKeys.dashboardTotalCost,
                description: 'Track your total funds spent across all categories for this project.',
                tooltipBackgroundColor: const Color(0xFF1E1E2C),
                textColor: Colors.white,
                tooltipBorderRadius: BorderRadius.circular(16),
                tooltipPadding: const EdgeInsets.all(16),
                child: _costCard(
                  'TOTAL COST',
                  project != null
                      ? formatCurrency(
                          context.read<ProjectProvider>().totalSpentForProject(
                            project.id,
                          ),
                        )
                      : '₹—',
                  project != null
                      ? () {
                          final paid = context
                              .read<ProjectProvider>()
                              .totalSpentForProject(project.id);
                          final budget = project.totalBudget;
                          final pct = budget > 0
                              ? (paid / budget * 100).toStringAsFixed(0)
                              : '0';
                          return '$pct% Used';
                        }()
                      : '—',
                  project != null &&
                      context.read<ProjectProvider>().totalSpentForProject(
                            project.id,
                          ) >
                          project.totalBudget * 0.9,
                  indicatorIcon: Icons.trending_up,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Showcase(
                key: ShowcaseKeys.dashboardTotalBudget,
                description: 'Track the total allocated budget and remaining balance for this project.',
                tooltipBackgroundColor: const Color(0xFF1E1E2C),
                textColor: Colors.white,
                tooltipBorderRadius: BorderRadius.circular(16),
                tooltipPadding: const EdgeInsets.all(16),
                child: _costCard(
                  'BUDGET',
                  project?.formattedBudget ?? '₹—',
                  'Remaining: ${project?.formattedRemaining ?? '—'}',
                  project != null && project.remainingBudget < 0,
                  isInvoice: true,
                  indicatorIcon: (project != null && project.remainingBudget < 0)
                      ? Icons.trending_down
                      : Icons.trending_flat,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Showcase(
                key: ShowcaseKeys.dashboardTotalRevenue,
                description: 'View the total revenue inflow recorded for this project.',
                tooltipBackgroundColor: const Color(0xFF1E1E2C),
                textColor: Colors.white,
                tooltipBorderRadius: BorderRadius.circular(16),
                tooltipPadding: const EdgeInsets.all(16),
                child: _costCard(
                  'TOTAL REVENUE',
                  project != null ? formatCurrency(_totalRevenueSum) : '₹—',
                  'Cash Inflow',
                  false,
                  indicatorIcon: Icons.trending_up,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Builder(
                builder: (_) {
                  final netCash = project != null
                      ? (_totalRevenueSum -
                          context
                              .read<ProjectProvider>()
                              .totalSpentForProject(project.id))
                      : 0.0;
                  final isLoss = netCash < 0;
                  return Showcase(
                    key: ShowcaseKeys.dashboardNetCashFlow,
                    description: 'See your net profit or loss calculated instantly.',
                    tooltipBackgroundColor: const Color(0xFF1E1E2C),
                    textColor: Colors.white,
                    tooltipBorderRadius: BorderRadius.circular(16),
                    tooltipPadding: const EdgeInsets.all(16),
                    child: _costCard(
                      'NET CASH FLOW',
                      project != null ? formatCurrency(netCash) : '₹—',
                      project != null ? (isLoss ? 'Net Loss' : 'Net Profit') : '—',
                      isLoss,
                      isInvoice: !isLoss,
                      indicatorIcon: isLoss ? Icons.trending_down : Icons.trending_up,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (project != null) ...[
          _buildRevenueHistory(context),
          const SizedBox(height: 14),
        ],
        _buildSpeakUpdate(context),
        const SizedBox(height: 16),
        Showcase(
          key: ShowcaseKeys.recentEntries,
          description: 'Quickly view or edit your most recently added entries',
          tooltipBackgroundColor: const Color(0xFF1E1E2C),
          textColor: Colors.white,
          tooltipBorderRadius: BorderRadius.circular(16),
          tooltipPadding: const EdgeInsets.all(16),
          child: _buildRecentActivity(context),
        ),
      ],
    );
  }
  Widget _buildProjectSelector(BuildContext context, ProjectProvider provider) {
    final selectedName = provider.selectedProject?.name ?? 'Select Project';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B7280).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showProjectPicker(context, provider),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.domain_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACTIVE PROJECT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: textGray.withValues(alpha: 0.7),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selectedName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.unfold_more_rounded,
                      color: textGray,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                    color: const Color(0xFFDDE0F0),
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
                    children: projects.map((p) {
                      final selected = p.id == provider.selectedProject?.id;
                      return InkWell(
                        onTap: () {
                          provider.selectProject(p);
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _costCard(
    String label,
    String value,
    String sub,
    bool isOver, {
    bool isInvoice = false,
    IconData? icon,
    IconData? indicatorIcon,
  }) {
    final cardColor = Colors.white.withValues(alpha: 0.95);
    final accentColor = isOver
        ? Colors.redAccent
        : (isInvoice ? AppColors.primaryPurple : AppColors.primaryBlue);
    final iconData = icon ??
        (isInvoice
            ? Icons.account_balance_wallet_outlined
            : Icons.currency_rupee_rounded);
    final pillIcon = indicatorIcon ??
        (isInvoice
            ? Icons.trending_flat
            : (isOver ? Icons.trending_up : Icons.trending_down));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B7280).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: textGray.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 14, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textDark,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pillIcon,
                  size: 12,
                  color: accentColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      sub,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSpeakUpdate(BuildContext context) {
    return Showcase(
      key: ShowcaseKeys.quickAddEntry,
      description: 'Quickly add a new entry from here.',
      tooltipBackgroundColor: const Color(0xFF1E1E2C),
      textColor: Colors.white,
      tooltipBorderRadius: BorderRadius.circular(16),
      tooltipPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: AppGradients.primaryButton,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, '/add-entry'),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Speak Update',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'AI FOREMAN IS LISTENING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
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
      children: [
        AppSectionHeader(
          title: 'Recent Activity',
          actionLabel: 'View All',
          onAction: () => Navigator.pushNamed(
            context,
            '/logs',
            arguments: {'projectId': selectedProjectId},
          ),
        ),
        const SizedBox(height: 10),
        _TeamApprovalHistoryWidget(projectId: selectedProjectId),
        const SizedBox(height: 12),
        const AppSectionHeader(title: 'Recent Entries'),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B7280).withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: textGray.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_toggle_off_rounded,
                    size: 32,
                    color: textGray.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No recent entries',
                  style: TextStyle(
                    color: textDark.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Updates you speak or enter will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textGray.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          )
        else
          ...recent.map((entry) => _activityTile(context, entry)),
      ],
    );
  }
  Widget _activityTile(BuildContext context, EntryModel entry) {
    final IconData icon;
    final Color badgeBg;
    final Color badgeColor;
    final String badgeLabel;
    switch (entry.type) {
      case EntryType.labour:
        icon = Icons.engineering_rounded;
        badgeBg = const Color(0xFFE8F5E9);
        badgeColor = const Color(0xFF2E7D32);
        badgeLabel = 'Labour';
        break;
      case EntryType.equipment:
        icon = Icons.construction_rounded;
        badgeBg = const Color(0xFFFFF3E0);
        badgeColor = Colors.orange;
        badgeLabel = 'Equipment';
        break;
      case EntryType.material:
        icon = Icons.inventory_2_rounded;
        badgeBg = const Color(0xFFEEF0FF);
        badgeColor = primaryBlue;
        badgeLabel = 'Material';
        break;
    }
    final timeLabel = relativeTimeLabel(entry.date.toLocal());
    final title = entry.description.isNotEmpty ? entry.description : badgeLabel;
    final subtitle = '₹${entry.amount.toStringAsFixed(0)} • $timeLabel';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B7280).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, '/logs'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: badgeColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: textGray.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to approve'),
          backgroundColor: Colors.red,
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
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadAll();
    }
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _summaryChip(
              '$pendingCount',
              'Pending',
              AppTheme.warning,
              isActive: _activeTab == 'pending',
              onTap: () => setState(() => _activeTab = 'pending'),
            ),
            const SizedBox(width: 8),
            _summaryChip(
              '$approvedCount',
              'Approved',
              AppTheme.success,
              isActive: _activeTab == 'approved',
              onTap: () => setState(() => _activeTab = 'approved'),
            ),
            const SizedBox(width: 8),
            _summaryChip(
              '$rejectedCount',
              'Rejected',
              AppTheme.error,
              isActive: _activeTab == 'rejected',
              onTap: () => setState(() => _activeTab = 'rejected'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (RoleManager.canAssignTasks) ...[
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/assign-task'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.assignment_turned_in,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Assign Task',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              GestureDetector(
                onTap: _loadAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Refresh',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Tasks Assigned',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        if (_tasks.isEmpty)
          const AppEmptyState(
            icon: Icons.task_alt,
            message: 'No tasks currently active.',
          )
        else
          ..._tasks.map(
            (task) => _TaskCard(
              task: task,
              onEdit: () => Navigator.pushNamed(context, '/update-progress', arguments: {'task': task}).then((_) {
                if (context.mounted) _loadAll();
              }),
            ),
          ),
        const SizedBox(height: 24),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadAll,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
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
          emptyColor: AppTheme.success,
        );
      case 'rejected':
        final rejected = _historyTransactions
            .where((t) => t['approvalStatus'] == 'Rejected')
            .toList();
        return _buildHistoryList(
          items: rejected,
          emptyMessage: 'No rejected entries',
          emptyIcon: Icons.cancel_outlined,
          emptyColor: AppTheme.error,
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingCount == 0)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: AppColors.textLight.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No pending approvals',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pull down to refresh',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              const AppSectionHeader(title: 'Pending Approvals'),
              const SizedBox(height: 8),
              ..._pendingTransactions.map(
                (tx) => _PendingTxCard(
                  tx: tx as Map<String, dynamic>,
                  onApprove: () => _handleApprove(tx['_id']?.toString() ?? ''),
                  onReject: () => _handleReject(tx['_id']?.toString() ?? ''),
                ),
              ),
            ],
            const SizedBox(height: 20),
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
                return DateTime.parse(raw.toString());
              } catch (_) {
                return DateTime.fromMillisecondsSinceEpoch(0);
              }
            }
            return parse(b).compareTo(parse(a));
          });
    final recent = combined.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Recent History'),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 40,
                  color: AppColors.textLight.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No history yet',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          ...recent.map((tx) => _HistoryTxCard(tx: tx as Map<String, dynamic>)),
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
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(emptyIcon, size: 48, color: emptyColor.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total history loaded: ${_historyTransactions.length}',
              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: _activeTab == 'approved'
              ? 'Recently Approved'
              : 'Recently Rejected',
        ),
        const SizedBox(height: 8),
        ...items.map((tx) => _HistoryTxCard(tx: tx as Map<String, dynamic>)),
      ],
    );
  }
  Widget _summaryChip(
    String count,
    String label,
    Color color, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.18)
                : color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : color.withValues(alpha: 0.25),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
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
    final createdByName =
        (tx['createdBy'] is Map ? tx['createdBy']['name'] : null)?.toString() ??
        'Unknown';
    final createdByRole =
        (tx['createdBy'] is Map ? tx['createdBy']['role'] : null)?.toString() ??
        '';
    final projectName =
        (tx['project'] is Map ? tx['project']['projectName'] : null)
            ?.toString() ??
        'Unknown Project';
    String dateStr = '';
    final rawDate = tx['date'] ?? tx['createdAt'];
    if (rawDate != null) {
      try {
        final d = DateTime.parse(rawDate.toString());
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
        dateStr = '${d.day} ${months[d.month - 1]} ${d.year}';
      } catch (_) {}
    }
    IconData typeIcon;
    Color typeColor;
    switch (type.toLowerCase()) {
      case 'wages':
        typeIcon = Icons.people_outlined;
        typeColor = const Color(0xFF2E7D32);
        break;
      case 'expense':
        typeIcon = Icons.precision_manufacturing_outlined;
        typeColor = const Color(0xFFE65100);
        break;
      default:
        typeIcon = Icons.category_outlined;
        typeColor = AppColors.primary;
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$createdByName${createdByRole.isNotEmpty ? ' · $createdByRole' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 13,
                color: AppColors.textLight,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  projectName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (dateStr.isNotEmpty) ...[
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Approve',
                  icon: Icons.check_circle_outline,
                  onPressed: onApprove,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Reject',
                  icon: Icons.cancel_outlined,
                  variant: AppButtonVariant.danger,
                  onPressed: onReject,
                ),
              ),
            ],
          ),
        ],
      ),
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
    final createdByName =
        (tx['createdBy'] is Map ? tx['createdBy']['name'] : null)?.toString() ??
        'Unknown';
    final projectName =
        (tx['project'] is Map ? tx['project']['projectName'] : null)
            ?.toString() ??
        'Unknown Project';
    final approvedByName =
        (tx['approvedBy'] is Map ? tx['approvedBy']['name'] : null)?.toString();
    final rejectionReason = tx['rejectionReason']?.toString() ?? '';
    String dateStr = '';
    final rawDate = tx['approvedAt'] ?? tx['date'] ?? tx['createdAt'];
    if (rawDate != null) {
      try {
        final d = DateTime.parse(rawDate.toString());
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
        dateStr = '${d.day} ${months[d.month - 1]} ${d.year}';
      } catch (_) {}
    }
    final bool isApproved = approvalStatus == 'Approved';
    IconData typeIcon;
    Color typeColor;
    switch (type.toLowerCase()) {
      case 'wages':
        typeIcon = Icons.people_outlined;
        typeColor = const Color(0xFF2E7D32);
        break;
      case 'expense':
        typeIcon = Icons.precision_manufacturing_outlined;
        typeColor = const Color(0xFFE65100);
        break;
      default:
        typeIcon = Icons.category_outlined;
        typeColor = AppColors.primary;
    }
    final statusColor = isApproved ? const Color(0xFF059669) : Colors.red;
    final statusBg = isApproved
        ? const Color(0xFFD1FAE5)
        : const Color(0xFFFFEEEE);
    final statusIcon = isApproved
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        createdByName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 11, color: statusColor),
                          const SizedBox(width: 3),
                          Text(
                            approvalStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  size: 12,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    projectName,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (dateStr.isNotEmpty) ...[
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 11,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ],
            ),
            if (approvedByName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(statusIcon, size: 11, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    isApproved
                        ? 'Approved by $approvedByName'
                        : 'Rejected by $approvedByName',
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (!isApproved && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                ),
                child: Text(
                  'Reason: $rejectionReason',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.person_outline,
                  color: AppTheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good Morning, ${UserSession.roleLabel}',
                    style: AppTheme.heading3,
                  ),
                  Text('Ready for today\'s work', style: AppTheme.caption),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Add Daily Update',
          icon: Icons.add_circle_outline,
          onPressed: () => Navigator.pushNamed(context, '/update-progress'),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Add Material Entry',
          icon: Icons.category_outlined,
          variant: AppButtonVariant.outline,
          onPressed: () => widget.onEntryTap(context, 'material'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tasks Assigned',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingTasks)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_tasks.isEmpty)
          const AppEmptyState(
            icon: Icons.task_alt,
            message: 'No tasks currently active.',
          )
        else
          ..._tasks.map(
            (task) => _TaskCard(
              task: task,
              onEdit: task.status != 'Completed'
                  ? () => Navigator.pushNamed(context, '/update-progress', arguments: {'task': task}).then((_) {
                      if (context.mounted) _loadTasks();
                    })
                  : null,
            ),
          ),
        const SizedBox(height: 24),
        AppSectionHeader(
          title: 'Recent Entries',
          actionLabel: 'View All',
          onAction: () => Navigator.pushNamed(context, '/logs'),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<dynamic>>(
          future: _recentEntriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Failed to load recent entries.',
                  style: TextStyle(color: Colors.red),
                ),
              );
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 36,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No entries yet',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: entries
                  .take(5)
                  .map((e) => _recentEntryTile(e as Map<String, dynamic>))
                  .toList(),
            );
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
    IconData icon;
    Color iconColor;
    Color iconBg;
    switch (type.toLowerCase()) {
      case 'wages':
        icon = Icons.people_outlined;
        iconColor = const Color(0xFF2E7D32);
        iconBg = const Color(0xFFE8F5E9);
        break;
      case 'expense':
        icon = Icons.precision_manufacturing_outlined;
        iconColor = const Color(0xFFE65100);
        iconBg = const Color(0xFFFFF3E0);
        break;
      default:
        icon = Icons.category_outlined;
        iconColor = AppColors.primary;
        iconBg = const Color(0xFFEEF0FF);
    }
    Color statusColor;
    Color statusBg;
    switch (approvalStatus.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF059669);
        statusBg = const Color(0xFFD1FAE5);
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusBg = const Color(0xFFFFEEEE);
        break;
      default:
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/logs'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${amount.toStringAsFixed(0)}${timeLabel.isNotEmpty ? ' • $timeLabel' : ''}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    approvalStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/approvals'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8E5FF), Color(0xFFF0EEFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loaded
                        ? '$_pendingCount Approval${_pendingCount == 1 ? "" : "s"} Pending'
                        : 'Checking Approvals…',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Review pending project updates and expenses.',
                    style: TextStyle(
                      color: AppColors.textMedium,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
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
                return DateTime.parse(raw.toString());
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }
    final shown = _expanded ? _history : _history.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B7280).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.people_outline,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Team Approval History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                if (_history.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? 'Show Less' : 'Show All',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EEF8)),
          if (_history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: 30,
                      color: AppColors.textLight.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No approval requests yet',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...shown.map((tx) => _historyTile(tx as Map<String, dynamic>)),
        ],
      ),
    );
  }
  Widget _historyTile(Map<String, dynamic> tx) {
    final title = tx['title']?.toString() ?? 'Entry';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final approvalStatus = tx['approvalStatus']?.toString() ?? '';
    final createdByName =
        (tx['createdBy'] is Map ? tx['createdBy']['name'] : null)?.toString() ??
        'Unknown';
    final createdByRole =
        (tx['createdBy'] is Map ? tx['createdBy']['role'] : null)?.toString() ??
        '';
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
    final statusColor = isApproved ? const Color(0xFF059669) : Colors.red;
    final statusBg = isApproved
        ? const Color(0xFFD1FAE5)
        : const Color(0xFFFFEEEE);
    IconData typeIcon;
    Color typeColor;
    switch (type.toLowerCase()) {
      case 'wages':
        typeIcon = Icons.people_outlined;
        typeColor = const Color(0xFF2E7D32);
        break;
      case 'expense':
        typeIcon = Icons.precision_manufacturing_outlined;
        typeColor = const Color(0xFFE65100);
        break;
      default:
        typeIcon = Icons.category_outlined;
        typeColor = AppColors.primary;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(typeIcon, color: typeColor, size: 18),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'By $createdByName${createdByRole.isNotEmpty ? ' · $createdByRole' : ''}${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (approvedByName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    isApproved
                        ? 'Approved by $approvedByName'
                        : 'Rejected by $approvedByName',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  approvalStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
