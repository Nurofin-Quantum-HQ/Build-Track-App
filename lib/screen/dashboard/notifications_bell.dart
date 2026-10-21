import 'dart:async';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';

/// Bell that opens the Inbox (To approve · Activity) with the unread count.
/// Inbox left the bottom bar in Design V2, so this is its home-screen entry.
class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key, this.onDark = true});

  /// Glass style for the noir hero (default); `false` for light headers.
  final bool onDark;

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  static int _last = 0;
  int _unreadCount = _last;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchUnread();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchUnread());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnread() async {
    try {
      final count = await ApiService.getUnreadNotificationCount();
      _last = count;
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BtIconButton(
      icon: Icons.notifications_none_rounded,
      size: 21,
      semantic: _unreadCount > 0 ? 'Inbox, $_unreadCount unread' : 'Inbox',
      color: widget.onDark ? Bt.bone : Bt.ink,
      background: widget.onDark ? Colors.white.withValues(alpha: .09) : Bt.card,
      badge: _unreadCount,
      onTap: () async {
        await Navigator.pushNamed(context, '/inbox');
        _fetchUnread();
      },
    );
  }
}
