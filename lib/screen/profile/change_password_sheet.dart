import 'dart:convert';

import 'package:buildtrack_mobile/config/api_config.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Account › Change Password: current + new + confirm →
/// `PUT /auth/change-password {currentPassword, newPassword}` (authRoutes.js).
/// The server keeps the session valid (no tokenVersion bump), so the user
/// stays signed in. Before, this row opened the e-mail reset flow.
Future<void> showChangePasswordSheet(BuildContext context) async {
  final changed = await showBtSheet<bool>(
    context,
    title: 'Change password',
    subtitle: 'You stay signed in on this phone.',
    builder: (ctx) => const _ChangePasswordForm(),
  );
  if (changed == true && context.mounted) btToast(context, 'Password changed');
}

/// Same minimum as the server's reset-password rule (8+).
const int _minLength = 8;

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();
  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _currentError;
  String? _nextError;
  String? _confirmError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    String? c, n, f;
    if (_current.text.isEmpty) c = 'Enter your current password';
    if (_next.text.length < _minLength) {
      n = 'At least $_minLength characters';
    } else if (_next.text == _current.text) {
      n = 'Choose a password different from the current one';
    }
    if (_confirm.text != _next.text) f = "Passwords don't match";
    setState(() {
      _currentError = c;
      _nextError = n;
      _confirmError = f;
    });
    return c == null && n == null && f == null;
  }

  Future<void> _submit() async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    http.Response? res;
    try {
      // Direct call (not ApiService.put): the server answers a WRONG CURRENT
      // PASSWORD with 401, and ApiService treats every 401 as an expired
      // session and signs the user out.
      final token = await AuthService.getToken();
      res = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/auth/change-password'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'currentPassword': _current.text, 'newPassword': _next.text}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      res = null;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (res == null) {
      btToast(context, "Couldn't reach the server — check your connection.", error: true);
      return;
    }
    String message = '';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) message = body['message'].toString();
    } catch (_) {}
    if (res.statusCode == 200) {
      Navigator.of(context).pop(true);
      return;
    }
    if (message.toLowerCase().contains('current password')) {
      setState(() => _currentError = 'Current password is incorrect');
      return;
    }
    if (res.statusCode == 401) {
      // A real expired / revoked session.
      Navigator.of(context).pop();
      AuthService.handleUnauthorized();
      return;
    }
    btToast(context, message.isNotEmpty ? message : "Couldn't change password — try again.", error: true);
  }

  Widget _field(String label, TextEditingController c, String? error, {TextInputAction action = TextInputAction.next, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BtField(
        label: label,
        error: error,
        child: TextField(
          controller: c,
          obscureText: _obscure,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: action,
          onSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
          style: BtText.body(context),
          decoration: btInput(
            context,
            hint: hint,
            suffix: IconButton(
              tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Bt.ink2),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _field('Current password', _current, _currentError),
      _field('New password', _next, _nextError, hint: 'At least $_minLength characters'),
      _field('Confirm new password', _confirm, _confirmError, action: TextInputAction.done),
      const SizedBox(height: 4),
      BtButton(label: 'Change password', loading: _saving, onPressed: _saving ? null : _submit),
    ]);
  }
}
