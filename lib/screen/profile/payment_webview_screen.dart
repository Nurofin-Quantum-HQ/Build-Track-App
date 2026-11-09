import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/controller/subscription_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final Map<String, dynamic> paymentParams;
  const PaymentWebViewScreen({super.key, required this.paymentParams});
  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isVerifying = false;
  bool _hasLaunchedExternalApp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            
            if (url.startsWith('buildtrack://payment/')) {
              final isSuccess = url.contains('/success');
              _handlePaymentReturn(isSuccess);
              return NavigationDecision.prevent;
            }
            if (url.startsWith('https://buildtrack.nurofin.com/subscription')) {
              final uri = Uri.parse(url);
              final status = uri.queryParameters['status'];
              final mayBeSuccess = status == 'success' || status == 'pending';
              _handlePaymentReturn(mayBeSuccess);
              return NavigationDecision.prevent;
            }
            if (url.contains('/api/subscriptions/callback') || url.contains('/api/subscriptions/browser-return')) {
              return NavigationDecision.navigate;
            }

            // Once external payment app has been launched once or verification is active,
            // strictly BLOCK all further external intents AND page re-navigations within AirPay
            // so AirPay cannot fire secondary fallback intents into Google Pay!
            if (_hasLaunchedExternalApp || _isVerifying) {
              debugPrint('Blocked duplicate navigation after payment app launched: $url');
              return NavigationDecision.prevent;
            }
            
            // Intercept Google Pay and other UPI Apps (Android Intent or custom scheme)
            if (url.startsWith('intent://') ||
                url.startsWith('upi://') ||
                url.startsWith('gpay://') ||
                url.startsWith('phonepe://') ||
                url.startsWith('paytm://') ||
                (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('about:'))) {
              _hasLaunchedExternalApp = true;
              _launchExternalUrl(url);
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(
        _buildPaymentHtml(),
        baseUrl: 'https://buildtrack.nurofin.com/',
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user completes payment in Google Pay and returns to the app,
    // Android triggers AppLifecycleState.resumed.
    if (state == AppLifecycleState.resumed && _hasLaunchedExternalApp && !_isVerifying) {
      debugPrint('Returned from external payment app. Starting verification...');
      _handlePaymentReturn(true);
    }
  }

  String _buildPaymentHtml() {
    final p = widget.paymentParams;
    final airpayUrl = p['airpayUrl']?.toString() ?? '';
    final StringBuffer inputFields = StringBuffer();
    
    p.forEach((key, value) {
      if (key != 'airpayUrl') {
        final safeValue = value
            .toString()
            .replaceAll('&', '&amp;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&#39;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        inputFields.write(
          '<input type="hidden" name="$key" value="$safeValue" />\n',
        );
      }
    });
    
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <style>
      body {
        margin: 0; padding: 0; background: #ffffff;
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
        display: flex; flex-direction: column; align-items: center;
        justify-content: center; min-height: 100vh; color: #344054;
      }
      .loader {
        width: 40px; height: 40px; border: 3px solid #E0E5FF;
        border-top: 3px solid #173EEA; border-radius: 50%;
        animation: spin 0.8s linear infinite; margin-bottom: 16px;
      }
      @keyframes spin { to { transform: rotate(360deg); } }
      p { font-size: 15px; font-weight: 600; color: #667085; }
    </style>
  </head>
  <body onload="document.getElementById('payForm').submit()">
    <div class="loader"></div>
    <p>Connecting to secure payment...</p>
    <form id="payForm" method="POST" action="$airpayUrl">
      $inputFields
    </form>
  </body>
</html>
''';
  }

  Future<void> _handlePaymentReturn(bool mayBeSuccess) async {
    if (_isVerifying) return;
    if (mounted) setState(() => _isVerifying = true);
    final verified = await context.read<SubscriptionProvider>().handlePaymentResult(mayBeSuccess);
    if (mounted) Navigator.of(context).pop(verified);
  }

  Future<void> _launchExternalUrl(String rawUrl) async {
    // Freeze pointer events in WebView so page cannot receive double taps
    try {
      _controller.runJavaScript("document.body.style.pointerEvents = 'none';");
    } catch (_) {}

    // Convert Android intent:// URLs to clean, standard upi:// URLs so the OS opens Google Pay cleanly
    String launchableUrl = rawUrl;
    if (launchableUrl.startsWith('intent://')) {
      final hashIndex = launchableUrl.indexOf('#Intent');
      final queryPart = hashIndex != -1
          ? launchableUrl.substring('intent://'.length, hashIndex)
          : launchableUrl.substring('intent://'.length);
      launchableUrl = 'upi://$queryPart';
    }

    try {
      final uri = Uri.parse(launchableUrl);
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (e) {
      debugPrint('Error launching external URL $launchableUrl: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isVerifying,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        _handlePaymentReturn(false);
      },
      child: Scaffold(
        backgroundColor: Bt.ground,
        appBar: BtNavBar(
          title: 'Secure Payment',
          close: true,
          onBack: _isVerifying ? null : () => _handlePaymentReturn(false),
          trailing: const Icon(Icons.lock_rounded, color: Bt.green, size: 18),
        ),
        body: Stack(
          children: [
            IgnorePointer(
              ignoring: _isVerifying,
              child: Opacity(
                opacity: _isVerifying ? 0.0 : 1.0,
                child: WebViewWidget(controller: _controller),
              ),
            ),
            if (_isVerifying)
              Container(
                color: Bt.ground,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BtPageLoader(label: 'Verifying payment with bank...'),
                    const SizedBox(height: 12),
                    Text(
                      'Please wait a moment while your bank confirms the transaction.',
                      textAlign: TextAlign.center,
                      style: BtText.caption(context),
                    ),
                  ],
                ),
              )
            else if (_isLoading)
              Container(
                color: Bt.ground,
                child: const BtPageLoader(label: 'Loading secure payment...'),
              ),
          ],
        ),
      ),
    );
  }
}
