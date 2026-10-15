import 'package:buildtrack_mobile/screen/inbox/inbox_screen.dart';
import 'package:flutter/material.dart';

/// `/notifications` now opens Inbox on "Activity" (same list, same actions — see inbox_screen.dart).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => const InboxScreen(initialTab: InboxTab.activity);
}
