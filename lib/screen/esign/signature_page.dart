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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sign Receipt')),
        body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 18))),
      );
    }
    if (_transaction?['eSignStatus'] == 'Signed') {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt Signed')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 80),
              SizedBox(height: 20),
              Text('Thank you! This receipt has been securely signed.', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review & Sign Receipt'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(child: Text('CASH RECEIPT', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                        const Divider(height: 40),
                        _buildRow('Project', _transaction?['projectName'] ?? 'N/A'),
                        const SizedBox(height: 12),
                        _buildRow('Type', _transaction?['type'] ?? 'N/A'),
                        const SizedBox(height: 12),
                        _buildRow('Amount', '₹${_transaction?['amount'] ?? 0}'),
                        const SizedBox(height: 12),
                        _buildRow('Date', _transaction?['date']?.substring(0, 10) ?? 'N/A'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Authorize & Sign:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitSignature,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Authorize and Sign'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
