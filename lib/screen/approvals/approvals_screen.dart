import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/widgets/nurofin_scaffold.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});
  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}
class _ApprovalsScreenState extends State<ApprovalsScreen> {
  bool _isLoading = true;
  List<dynamic> _transactions = [];
  List<dynamic> _projectUpdates = [];
  @override
  void initState() {
    super.initState();
    _fetchPendingApprovals();
  }
  Future<void> _fetchPendingApprovals() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchPendingApprovals();
    if (data != null && mounted) {
      setState(() {
        _transactions = data['transactions'] ?? [];
        _projectUpdates = data['projectUpdates'] ?? [];
      });
    }
    if (mounted) setState(() => _isLoading = false);
  }
  Future<void> _handleApproveTx(String id) async {
    final success = await ApiService.approveTransaction(id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction Approved'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchPendingApprovals();
    }
  }
  Future<void> _handleRejectTx(String id) async {
    final success = await ApiService.rejectTransaction(
      id,
      'Rejected by supervisor/admin',
    );
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction Rejected'),
          backgroundColor: Colors.red,
        ),
      );
      _fetchPendingApprovals();
    }
  }
  @override
  Widget build(BuildContext context) {
    return NurofinScaffold(
      appBar: AppBar(
        title: const Text(
          'Pending Approvals',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchPendingApprovals,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_transactions.isEmpty && _projectUpdates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 50),
                      child: Center(
                        child: Text(
                          'No pending approvals at this time.',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      ),
                    ),
                  if (_transactions.isNotEmpty) ...[
                    Text(
                      'Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._transactions.map((tx) => _buildTransactionCard(tx)),
                  ],
                ],
              ),
            ),
    );
  }
  Widget _buildTransactionCard(dynamic tx) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tx['title'] ?? 'Transaction',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '₹${tx['amount']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Created By: ${tx['createdBy']?['name'] ?? 'Unknown'} (${tx['createdBy']?['role'] ?? 'Worker'})',
            ),
            Text('Project: ${tx['project']?['projectName'] ?? 'Unknown'}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _handleApproveTx(tx['_id'] ?? tx['id']),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _handleRejectTx(tx['_id'] ?? tx['id']),
                    child: const Text('Reject'),
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
