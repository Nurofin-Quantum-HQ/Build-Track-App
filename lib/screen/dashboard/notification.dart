import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  bool _loadingMore = false;
  bool _hasError = false;
  int _page = 1;
  int _pages = 1;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications({bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    final targetPage = append ? _page + 1 : 1;
    try {
      final data = await ApiService.fetchNotificationPage(page: targetPage, limit: 50);
      if (!mounted) return;
      setState(() {
        final items = (data['items'] as List?) ?? <dynamic>[];
        if (append) {
          final existing = _notifications.map((n) => n['_id']).toSet();
          final incoming = items.where((n) => !existing.contains(n['_id'])).toList();
          _notifications = [..._notifications, ...incoming];
        } else {
          _notifications = items;
        }
        _page = (data['page'] as int?) ?? targetPage;
        _pages = (data['pages'] as int?) ?? 1;
        _isLoading = false;
        _loadingMore = false;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadingMore = false;
        _hasError = !append;
      });
    }
  }

  void _retry() => _fetchNotifications();

  Future<void> _markAllRead() async {
    await ApiService.markAllNotificationsAsRead();
    _fetchNotifications();
  }

  Future<void> _clearAll() async {
    await ApiService.clearAllNotifications();
    _fetchNotifications();
  }

  String? _targetRoute(dynamic n) {
    switch (n['relatedModel']) {
      case 'Transaction':
        return '/logs';
      case 'Inventory':
        return '/inventory';
      case 'Task':
        return '/assign-task';
      case 'Project':
        return '/projects';
      case 'Payment':
        return '/subscription';
      default:
        return null;
    }
  }

  void _openNotification(dynamic n) {
    final id = n['_id'] as String?;
    if (id != null && n['read'] != true) {
      ApiService.markNotificationAsRead(id).then((_) {
        if (mounted) _fetchNotifications();
      });
    }
    final route = _targetRoute(n);
    if (route != null && mounted) {
      Navigator.pushNamed(context, route);
    }
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, h:mm a').format(date);
    } catch (e) {
      return '';
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'approval': return Icons.check_circle;
      case 'payment': return Icons.attach_money;
      case 'inventory': return Icons.inventory;
      case 'project': return Icons.business;
      case 'worker': return Icons.person;
      case 'task': return Icons.assignment_late_outlined;
      default: return Icons.notifications;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'approval': return Colors.blue;
      case 'payment': return Colors.green;
      case 'inventory': return Colors.orange;
      case 'project': return Colors.purple;
      case 'worker': return Colors.blueAccent;
      case 'task': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['read'] == false).length;

    return Scaffold(
      backgroundColor: AppColors.gradientStart,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: 'Notifications',
              isSubScreen: true,
              leftIcon: Icons.arrow_back,
              onLeftTap: () => Navigator.maybePop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    unreadCount > 0 ? '$unreadCount Unread' : 'All caught up!',
                    style: AppTheme.heading3,
                  ),
                  Row(
                    children: [
                      if (unreadCount > 0)
                        IconButton(
                          icon: const Icon(Icons.done_all, color: AppColors.primary),
                          onPressed: _markAllRead,
                          tooltip: 'Mark all as read',
                        ),
                      if (_notifications.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep, color: Colors.red),
                          onPressed: _clearAll,
                          tooltip: 'Clear all',
                        ),
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi_off, size: 40, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text("Couldn't load notifications"),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: _retry,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _notifications.isEmpty
                          ? const Center(child: Text('No notifications'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _notifications.length + (_page < _pages ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _notifications.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(child: _loadingMore
                                        ? const CircularProgressIndicator()
                                        : TextButton(
                                            onPressed: () => _fetchNotifications(append: true),
                                            child: const Text('Load more'),
                                          )),
                                  );
                                }
                                final n = _notifications[index];
                                final isRead = n['read'] == true;
                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isRead ? Colors.grey.shade200 : AppColors.primary,
                                      width: isRead ? 1 : 2,
                                    ),
                                  ),
                                  child: ListTile(
                                    onTap: () => _openNotification(n),
                                    leading: CircleAvatar(
                                      backgroundColor: _getColor(n['type'] ?? '').withValues(alpha: 0.1),
                                      child: Icon(_getIcon(n['type'] ?? ''), color: _getColor(n['type'] ?? '')),
                                    ),
                                    title: Text(
                                      n['title'] ?? '',
                                      style: AppTheme.heading3.copyWith(
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          n['message'] ?? '',
                                          style: TextStyle(fontSize: 14, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatTime(n['createdAt'] ?? ''),
                                          style: AppTheme.label.copyWith(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
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