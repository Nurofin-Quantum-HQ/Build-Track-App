import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:buildtrack_mobile/config/api_config.dart';
class SignaturePage extends StatefulWidget {
  final String token;
  const SignaturePage({super.key, required this.token});
  @override
  State<SignaturePage> createState() => _SignaturePageState();
}
class _SignaturePageState extends State<SignaturePage> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _transaction;
  String? _errorMessage;
  @override
  void initState() {
    super.initState();
    _fetchTransaction();
  }
  Future<void> _fetchTransaction() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/esign/details/${widget.token}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _transaction = data['meta'] ?? {};
          _transaction!['eSignStatus'] = data['status'] == 'signed' ? 'Signed' : 'Pending';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = jsonDecode(response.body)['message'] ?? 'Failed to load receipt';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please try again.';
        _isLoading = false;
      });
    }
  }
  Future<void> _submitSignature() async {
    setState(() => _isSubmitting = true);
    try {
      final dataUri = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='; // dummy 1x1 image as placeholder for authorization
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/esign/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.token,
          'signatureData': dataUri
        }),
      );
      if (response.statusCode == 200) {
        await showBtSuccess(
          context,
          kind: BtSuccessKind.check,
          label: 'Cash receipt',
          title: 'Receipt signed successfully!',
          message: 'Thank you! This receipt has been securely signed.',
        );
        if (!mounted) return;
        setState(() {
          _transaction!['eSignStatus'] = 'Signed';
          _isSubmitting = false;
        });
      } else {
        btToast(context, jsonDecode(response.body)['message'] ?? 'Failed to submit signature', error: true);
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      btToast(context, 'Error submitting signature', error: true);
      setState(() => _isSubmitting = false);
    }
  }

  String _amountLabel() {
    final a = _transaction?['amount'];
    if (a is num) return formatInr(a);
    return '₹${a ?? 0}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Bt.ground, body: BtPageLoader(label: 'Loading receipt…'));
    }
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Bt.ground,
        appBar: const BtNavBar(title: 'Sign receipt', showBack: false),
        body: BtEmpty(icon: Icons.error_outline_rounded, title: 'Can\'t open this receipt', message: _errorMessage!),
      );
    }
    if (_transaction?['eSignStatus'] == 'Signed') {
      return Scaffold(
        backgroundColor: Bt.noir,
        body: BtHero(
          overlap: 0,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top - 34,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BtReveal(
                  child: BtRing(
                    value: 1,
                    size: 104,
                    stroke: 6,
                    onDark: true,
                    color: Bt.greenBright,
                    child: const Icon(Icons.check_rounded, size: 48, color: Bt.greenBright),
                  ),
                ),
                const SizedBox(height: 28),
                BtReveal(index: 1, child: Text('RECEIPT SIGNED', style: BtText.mono(context, color: Bt.greenBright))),
                const SizedBox(height: 10),
                BtReveal(index: 2, child: Text('Thank you!', textAlign: TextAlign.center, style: BtText.d1(context, color: Bt.bone))),
                const SizedBox(height: 8),
                BtReveal(
                  index: 3,
                  child: Text('This receipt has been securely signed.', textAlign: TextAlign.center, style: BtText.body(context, color: Bt.onNoir2)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final bt = context.bt;
    return Scaffold(
      backgroundColor: Bt.ground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BtHeroScroll(
            hero: BtHero(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BtReveal(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(Bt.rChip),
                        border: Border.all(color: Colors.white.withValues(alpha: .09)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.lock_outline_rounded, size: 15, color: Bt.onNoir2),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Secure link · sign receipt', maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: Bt.onNoir2))),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 22),
                  BtReveal(index: 1, child: Text('CASH RECEIPT', style: BtText.mono(context, color: bt.accent))),
                  const SizedBox(height: 8),
                  BtReveal(index: 2, child: Text('Review & sign\nreceipt', style: BtText.d1(context, color: Bt.bone))),
                  const SizedBox(height: 8),
                  BtReveal(
                    index: 2,
                    child: Text('Please check the details below, then authorize.', style: BtText.body(context, color: Bt.onNoir2)),
                  ),
                ],
              ),
            ),
            children: [
              BtReveal(
                index: 3,
                child: BtCard(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(child: Text('CASH RECEIPT', style: BtText.mono(context))),
                        const BtBadge(label: 'Pending', tone: BtTone.amber),
                      ]),
                      const SizedBox(height: 12),
                      Text(_amountLabel(), style: BtText.amount(context, size: 38)),
                      const SizedBox(height: 6),
                      _buildRow('Project', _transaction?['projectName'] ?? 'N/A'),
                      _buildRow('Type', _transaction?['type'] ?? 'N/A'),
                      _buildRow('Amount', '₹${_transaction?['amount'] ?? 0}'),
                      _buildRow('Date', _transaction?['date']?.substring(0, 10) ?? 'N/A'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              BtReveal(index: 4, child: Text('Authorize & sign:', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
              const SizedBox(height: 10),
              BtReveal(
                index: 5,
                child: BtButton(
                  label: 'Authorize and Sign',
                  icon: Icons.draw_outlined,
                  loading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submitSignature,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Bt.line))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: BtText.subhead(context)),
            const SizedBox(width: 16),
            Expanded(child: Text(value, textAlign: TextAlign.right, style: BtText.num(BtText.subhead(context, color: Bt.ink, weight: FontWeight.w500)))),
          ],
        ),
      );
}
