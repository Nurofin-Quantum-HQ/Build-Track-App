import 'package:buildtrack_mobile/screen/inbox/inbox_screen.dart';
import 'package:flutter/material.dart';

/// `/notifications` — the Home bell: the notification list only (no To approve
/// tab), with mark all as read / clear all / load more (see inbox_screen.dart).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => const InboxScreen(mode: InboxMode.notifications);
}
