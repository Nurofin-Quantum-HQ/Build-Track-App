import 'package:buildtrack_mobile/screen/inbox/inbox_screen.dart';
import 'package:flutter/material.dart';

/// `/approvals` — Home's "See all": pending approvals only (no Activity tab),
/// same list and actions as Inbox → To approve (see inbox_screen.dart).
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});
  @override
  Widget build(BuildContext context) => const InboxScreen(mode: InboxMode.approvals);
}
