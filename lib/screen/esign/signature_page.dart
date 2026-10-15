import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:buildtrack_mobile/config/api_config.dart';
class SignaturePage extends StatefulWidget {
  final String token;
  const SignaturePage({Key? key, required this.token}) : super(key: key);
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt signed successfully!')));
        setState(() {
          _transaction!['eSignStatus'] = 'Signed';
          _isSubmitting = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(jsonDecode(response.body)['message'] ?? 'Failed to submit signature')));
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error submitting signature')));
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Bt.ground, body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Bt.ground,
        appBar: const BtNavBar(title: 'Sign receipt', showBack: false),
        body: BtEmpty(icon: Icons.error_outline_rounded, title: 'Can\'t open this receipt', message: _errorMessage!),
      );
    }
    if (_transaction?['eSignStatus'] == 'Signed') {
      return const Scaffold(
        backgroundColor: Bt.ground,
        appBar: BtNavBar(title: 'Receipt signed', showBack: false),
        body: BtEmpty(
          icon: Icons.check_circle_rounded,
          title: 'Thank you!',
          message: 'This receipt has been securely signed.',
        ),
      );
    }
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: const BtNavBar(title: 'Review & sign receipt', showBack: false),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text('Cash receipt', style: BtText.largeTitle(context)),
              const SizedBox(height: 4),
              Text('Please check the details below, then authorize.', style: BtText.body(context, color: Bt.ink2)),
              const SizedBox(height: 20),
              BtGroup(children: [
                _buildRow('Project', _transaction?['projectName'] ?? 'N/A'),
                _buildRow('Type', _transaction?['type'] ?? 'N/A'),
                _buildRow('Amount', '₹${_transaction?['amount'] ?? 0}'),
                _buildRow('Date', _transaction?['date']?.substring(0, 10) ?? 'N/A'),
              ]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(color: Bt.card, border: Border(top: BorderSide(color: Bt.line))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: BtButton(
            label: 'Authorize and Sign',
            loading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submitSignature,
          ),
        ),
      ),
    );
  }
  Widget _buildRow(String label, String value) => BtValueRow(label: label, value: value);
}
