import 'package:buildtrack_mobile/screen/inbox/inbox_screen.dart';
import 'package:flutter/material.dart';

/// `/approvals` now opens Inbox on "To approve" (same list, same actions — see inbox_screen.dart).
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});
  @override
  Widget build(BuildContext context) => const InboxScreen(initialTab: InboxTab.approvals);
}
