import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/design/design.dart';

/// PrivacyPolicyScreen — Comprehensive DPDPA 2023 compliance & data rights screen.
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  final Set<int> _expandedSections = {1, 2, 6, 8, 12, 20}; // Common sections open by default
  late String _selectedFont;

  @override
  void initState() {
    super.initState();
    final sessionFont = UserSession.companyFontStyle.trim();
    _selectedFont = sessionFont.isNotEmpty ? sessionFont : 'Inter';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  TextStyle _font({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? Bt.ink,
      height: height,
      letterSpacing: letterSpacing,
    );
    switch (_selectedFont.toLowerCase().trim()) {
      case 'plus jakarta sans':
      case 'jakarta':
        return GoogleFonts.plusJakartaSans(textStyle: base);
      case 'poppins':
        return GoogleFonts.poppins(textStyle: base);
      case 'outfit':
        return GoogleFonts.outfit(textStyle: base);
      case 'montserrat':
        return GoogleFonts.montserrat(textStyle: base);
      case 'roboto':
        return GoogleFonts.roboto(textStyle: base);
      case 'inter':
      default:
        return GoogleFonts.inter(textStyle: base);
    }
  }

  PopupMenuItem<String> _fontMenuItem(String value, String label) {
    final isSelected = _selectedFont.toLowerCase() == value.toLowerCase();
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: _font(
                size: 13,
                weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? context.bt.accent : Bt.ink,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 16, color: context.bt.accent),
        ],
      ),
    );
  }

  void _toggle(int id) {
    setState(() {
      if (_expandedSections.contains(id)) {
        _expandedSections.remove(id);
      } else {
        _expandedSections.add(id);
      }
    });
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'BuildTrack Privacy Inquiry / Grievance'},
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: email));
        if (mounted) btToast(context, 'Email copied to clipboard');
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: email));
      if (mounted) btToast(context, 'Email copied to clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _sections.where((s) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          s.summary.toLowerCase().contains(q) ||
          s.details.any((d) => d.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: 'Privacy Policy',
        trailing: PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Bt.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Bt.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.text_fields_rounded, size: 16, color: Bt.ink),
                const SizedBox(width: 4),
                Text(
                  _selectedFont,
                  style: _font(size: 11.5, weight: FontWeight.w600, color: Bt.ink),
                ),
              ],
            ),
          ),
          tooltip: 'Select Typography Font',
          onSelected: (font) => setState(() => _selectedFont = font),
          itemBuilder: (context) => [
            _fontMenuItem('Inter', 'Inter (Default Clean Sans)'),
            _fontMenuItem('Plus Jakarta Sans', 'Plus Jakarta Sans (Modern SaaS)'),
            _fontMenuItem('Poppins', 'Poppins (Geometric)'),
            _fontMenuItem('Outfit', 'Outfit (Contemporary)'),
            _fontMenuItem('Roboto', 'Roboto (System Sans)'),
          ],
        ),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Bt.gutter, 12, Bt.gutter, 40),
        children: [
          // ── Hero Banner ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Bt.noir,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.bt.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: context.bt.accent.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 13, color: context.bt.accent),
                          const SizedBox(width: 5),
                          Text(
                            'DPDPA 2023 COMPLIANT',
                            style: _font(
                              size: 10.5,
                              weight: FontWeight.w700,
                              color: context.bt.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$_selectedFont Font',
                      style: _font(
                        size: 11,
                        weight: FontWeight.w500,
                        color: Bt.bone.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'BuildTrack Privacy & Data Protection Policy',
                  style: _font(
                    size: 20,
                    weight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: -0.4,
                    color: Bt.bone,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Governed by Nurofin Quantum Financials Labs Pvt. Ltd. Bengaluru, India. This policy details how we handle, store, protect, and respect your operational data.',
                  style: _font(
                    size: 13,
                    weight: FontWeight.w400,
                    height: 1.5,
                    color: Bt.bone.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip('Effective: 01-06-2026'),
                    _chip('Updated: 15-09-2026'),
                    _chip('India Jurisdiction'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Search bar ──
          TextField(
            controller: _searchCtrl,
            style: _font(size: 14, weight: FontWeight.w500, color: Bt.ink),
            decoration: btInput(
              context,
              hint: 'Search 21 policy sections...',
              prefix: const Icon(Icons.search_rounded, size: 20, color: Bt.ink3),
              suffix: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Bt.ink3),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    )
                  : null,
            ).copyWith(
              hintStyle: _font(size: 13.5, weight: FontWeight.w400, color: Bt.ink3),
            ),
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
          const SizedBox(height: 16),

          // ── Key Safeguards Grid ──
          Row(
            children: [
              Expanded(
                child: _safeguardCard(
                  icon: Icons.location_off_outlined,
                  title: 'Zero GPS Tracking',
                  desc: 'We never request, track, or record physical device coordinates.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _safeguardCard(
                  icon: Icons.lock_outline_rounded,
                  title: 'Airpay Payments',
                  desc: 'PCI-DSS direct payments. Zero card numbers stored on our servers.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _safeguardCard(
                  icon: Icons.smart_toy_outlined,
                  title: 'Stateless AI',
                  desc: 'Groq inference processes voice/text with zero training retention.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _safeguardCard(
                  icon: Icons.gavel_outlined,
                  title: 'DPDPA Rights',
                  desc: 'Right to access, correct, erase, and nominate under Indian law.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Section Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Row(
              children: [
                Text(
                  _search.isEmpty ? 'POLICY SECTIONS (21)' : 'RESULTS (${filtered.length})',
                  style: _font(
                    size: 11.5,
                    weight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: Bt.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ── Sections List ──
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No matching policy sections found for "$_search"',
                  style: _font(size: 14, color: Bt.ink2),
                ),
              ),
            )
          else
            ...filtered.map((sec) {
              final isOpen = _expandedSections.contains(sec.id) || _search.isNotEmpty;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Bt.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOpen ? context.bt.accent.withValues(alpha: 0.35) : Bt.line,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isOpen ? 0.03 : 0.015),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: isOpen,
                    onExpansionChanged: (_) => _toggle(sec.id),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Bt.noir,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${sec.id}',
                        style: _font(
                          size: 12,
                          weight: FontWeight.w700,
                          color: Bt.bone,
                        ),
                      ),
                    ),
                    title: Text(
                      sec.title,
                      style: _font(
                        size: 15,
                        weight: FontWeight.w700,
                        letterSpacing: -0.25,
                        height: 1.25,
                        color: Bt.ink,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        sec.summary,
                        style: _font(
                          size: 13,
                          weight: FontWeight.w400,
                          height: 1.45,
                          color: const Color(0xFF525864),
                        ),
                        maxLines: isOpen ? 4 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(color: Bt.line, height: 16),
                            ...sec.details.map((point) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 7, right: 10),
                                        child: Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: context.bt.accent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          point,
                                          style: _font(
                                            size: 13.5,
                                            weight: FontWeight.w400,
                                            height: 1.55,
                                            letterSpacing: -0.1,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          // ── Grievance Officer Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Bt.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.bt.accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.bt.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.support_agent_rounded, size: 22, color: context.bt.accentInk),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grievance Officer (DPDPA)',
                            style: _font(
                              size: 15.5,
                              weight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: Bt.ink,
                            ),
                          ),
                          Text(
                            'Statutory contact under Indian Law',
                            style: _font(size: 12.5, weight: FontWeight.w400, color: Bt.ink2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _contactRow(Icons.person_outline, 'Officer Name', 'Vincent (Chief Executive Officer)'),
                const SizedBox(height: 8),
                _contactRow(Icons.business_outlined, 'Entity', 'Nurofin Quantum Financials Labs Pvt. Ltd.'),
                const SizedBox(height: 8),
                _contactRow(Icons.pin_drop_outlined, 'Jurisdiction', 'Bengaluru, Karnataka, India'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _launchEmail('info.nurofin@gmail.com'),
                  child: _contactRow(
                    Icons.mail_outline_rounded,
                    'Email (Tap to send)',
                    'info.nurofin@gmail.com',
                    isLink: true,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'All privacy queries, grievance escalations, and DPDPA data rights requests are acknowledged within 48 hours and resolved within 30 calendar days.',
                  style: _font(
                    size: 11.5,
                    weight: FontWeight.w400,
                    height: 1.45,
                    color: Bt.ink3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: _font(
          size: 10.5,
          weight: FontWeight.w600,
          color: Bt.bone.withValues(alpha: 0.9),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _safeguardCard({required IconData icon, required String title, required String desc}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Bt.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.bt.accent),
          const SizedBox(height: 8),
          Text(
            title,
            style: _font(
              size: 13.5,
              weight: FontWeight.w700,
              letterSpacing: -0.2,
              color: Bt.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: _font(
              size: 11.5,
              weight: FontWeight.w400,
              height: 1.45,
              color: Bt.ink2,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value, {bool isLink = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isLink ? context.bt.accent : Bt.ink3),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: _font(size: 12.5, weight: FontWeight.w600, color: Bt.ink),
        ),
        Expanded(
          child: Text(
            value,
            style: _font(
              size: 12.5,
              weight: isLink ? FontWeight.w600 : FontWeight.w400,
              color: isLink ? context.bt.accent : Bt.ink,
            ).copyWith(
              decoration: isLink ? TextDecoration.underline : null,
              decorationColor: isLink ? context.bt.accent : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _PolicySection {
  final int id;
  final String title;
  final String summary;
  final List<String> details;

  const _PolicySection({
    required this.id,
    required this.title,
    required this.summary,
    required this.details,
  });
}

const List<_PolicySection> _sections = [
  _PolicySection(
    id: 1,
    title: 'Introduction & Scope',
    summary: 'Governed by Nurofin Quantum Financials Labs Pvt. Ltd. across Web Portal and Mobile Apps.',
    details: [
      'This Privacy Policy governs the collection, processing, storage, and transfer of personal and operational data across BuildTrack.',
      'Operated by Nurofin Quantum Financials Labs Private Limited, headquartered in Bengaluru, Karnataka, India.',
      'Applies to all construction companies, project managers, contractors, supervisors, site workers, and portal visitors.',
    ],
  ),
  _PolicySection(
    id: 2,
    title: 'Data Fiduciary vs Data Processor',
    summary: 'Clear role boundaries under the Digital Personal Data Protection Act (DPDPA), 2023.',
    details: [
      'Subscriber Organization as Data Fiduciary: The construction company controls site data, worker logs, materials, and expense entries.',
      'BuildTrack as Data Processor: We process operational project data strictly on behalf and instruction of the customer organization.',
      'BuildTrack as Data Fiduciary: We act as fiduciary strictly for account registration, subscription billing, and system audit logs.',
    ],
  ),
  _PolicySection(
    id: 3,
    title: 'Information We Collect',
    summary: 'Personal identity, site operational logs, expense records, and system telemetry.',
    details: [
      'Account Data: Name, business email, mobile phone number, workspace name, role title, and hashed passwords.',
      'Site Operations: Materials inventory, daily workforce headcounts, milestone progress, and financial transaction entries.',
      'User Content: Site delivery challans, material receipts, photo logs, and voice-assisted prompt transcripts.',
      'Technical Telemetry: IP addresses, device model, operating system version, app logs, and network connection status.',
    ],
  ),
  _PolicySection(
    id: 4,
    title: 'Device Permissions & Hardware Access',
    summary: 'Microphone for voice entries, camera for site receipts, and storage for document exports.',
    details: [
      'Microphone (RECORD_AUDIO): Activated only when you tap the voice mic to record audio notes or site updates. Never runs in the background.',
      'Camera (CAMERA): Used solely to capture physical challans, receipts, delivery slips, and project progress photos.',
      'Photo Library & Storage: Used only when you choose to upload files or export PDF/CSV audit summaries.',
      'Push Notifications: Used to alert supervisors of approval requests, inventory alerts, and payment receipts.',
    ],
  ),
  _PolicySection(
    id: 5,
    title: 'What We Do NOT Collect',
    summary: 'Zero GPS tracking, no continuous background audio, and no biometric templates.',
    details: [
      'Zero GPS Tracking: BuildTrack does not request, track, or record physical GPS device locations.',
      'No Passive Audio Listening: The microphone is only active while holding the in-app record button.',
      'No Biometrics: We do not capture or process fingerprints, facial recognition scans, or biometric identifiers.',
      'No Personal Scraping: We never read personal SMS, contact lists, browsing history, or external app files.',
    ],
  ),
  _PolicySection(
    id: 6,
    title: 'Financial & Payment Processing',
    summary: 'Secured via Airpay Payment Gateway. Zero card details stored on BuildTrack servers.',
    details: [
      'All subscription transactions are processed directly by Airpay, a licensed, PCI-DSS Level 1 compliant gateway.',
      'BuildTrack never stores, logs, or views credit/debit card numbers, CVV codes, net banking passwords, or UPI PINs.',
      'We retain only the gateway transaction reference ID, order number, plan tier, amount, and payment timestamp.',
    ],
  ),
  _PolicySection(
    id: 7,
    title: 'How We Use Collected Information',
    summary: 'Service delivery, site analytics, role-based workflows, and statutory compliance.',
    details: [
      'Facilitating construction site accounting, inventory logging, and workforce scheduling.',
      'Generating audit-ready project reports, cashflow summaries, and cost variance forecasts.',
      'Enforcing multi-tier role approvals (Admin, Manager, Supervisor, Mason, Viewer).',
      'Preventing security intrusions, unauthorized access, fraud, and system abuse.',
    ],
  ),
  _PolicySection(
    id: 8,
    title: 'AI Processing & Third-Party Intelligence',
    summary: 'Powered by Groq Inc. Stateless inference with zero training retention on customer data.',
    details: [
      'BuildTrack integrates Groq high-speed AI inference for speech transcription and chat analytics.',
      'Voice audio snippets and transaction queries are sent over TLS 1.3 encryption for immediate inference.',
      'Data is processed statelessly: Groq does not retain, store, or use your proprietary project data to train general models.',
    ],
  ),
  _PolicySection(
    id: 9,
    title: 'Data Storage, Security & Encryption',
    summary: 'AES-256 at rest, TLS 1.3 in transit, salted bcrypt hashing, and role isolation.',
    details: [
      'Encryption in Transit: All data transfers use mandatory HTTPS / TLS 1.3 encryption.',
      'Encryption at Rest: Sensitive database records and cloud backups are encrypted with AES-256.',
      'Credential Protection: User passwords are encrypted with industry-standard salted bcrypt hashing.',
      'Multi-Tenant Isolation: Workspace data is separated logically with strict organization boundary checks.',
    ],
  ),
  _PolicySection(
    id: 10,
    title: 'Data Sharing & Third-Party Disclosures',
    summary: 'Zero data sales. Limited sharing strictly with essential infrastructure partners.',
    details: [
      'We do not sell, rent, monetize, or trade your personal or operational construction data to advertisers.',
      'Authorized Infrastructure: Airpay (payments), Groq (AI inference), MongoDB Atlas (database), AWS/GCP (cloud hosting).',
      'Legal & Statutory: Disclosures made only when required by valid court order, subpoena, or law enforcement warrant.',
    ],
  ),
  _PolicySection(
    id: 11,
    title: 'Data Retention & Account Closure',
    summary: 'Retained during active subscription, plus statutory tax retention; permanent erasure on request.',
    details: [
      'Active Subscriptions: Operational records are retained during your subscription to power historical reporting.',
      'Account Deletion: Upon workspace admin deletion, data is purged from active databases within 30 days.',
      'Financial Compliance: Invoices and transaction receipts are retained for 7 years to satisfy Indian tax and accounting laws.',
    ],
  ),
  _PolicySection(
    id: 12,
    title: 'Data Subject Rights (DPDPA 2023)',
    summary: 'Right to access, correct, erase, withdraw consent, and appoint a nominee.',
    details: [
      'Right to Access & Summary: Request a complete export of your personal data processed by BuildTrack.',
      'Right to Correction & Updating: Rectify inaccurate, misleading, or out-of-date personal information.',
      'Right to Erasure: Request permanent deletion of your personal account details.',
      'Right of Grievance Redressal: File concerns with our designated Grievance Officer or the Data Protection Board of India.',
      'Right to Nominate: Designate an authorized nominee in the event of death or incapacity.',
    ],
  ),
  _PolicySection(
    id: 13,
    title: 'Cross-Border Data Transfers',
    summary: 'Primary hosting in India; cross-border transfers comply with Indian government notifications.',
    details: [
      'Customer project data is primarily stored and processed on secure cloud data centers located in India.',
      'Any cross-border routing (e.g. specialized AI inference) complies with Indian Central Government transfer rules.',
    ],
  ),
  _PolicySection(
    id: 14,
    title: 'Cookies & Local Storage',
    summary: 'Functional session tokens, security keys, and UI theme preferences only.',
    details: [
      'We use secure, HTTP-only authentication tokens and local preferences (app theme, dark mode).',
      'We do not utilize third-party cross-site marketing or advertising trackers.',
    ],
  ),
  _PolicySection(
    id: 15,
    title: 'Data Breach Notification Protocol',
    summary: 'CERT-In and Data Protection Board notification protocols with 72-hour customer alerts.',
    details: [
      'Incident containment, forensics, and remediation deployed immediately upon detection.',
      'Notification to the Data Protection Board of India and CERT-In within statutory time limits.',
      'Direct communication to affected customer workspace administrators with mitigation guidance.',
    ],
  ),
  _PolicySection(
    id: 16,
    title: "Children's Privacy Protection",
    summary: 'Enterprise construction software not directed to individuals under 18 years of age.',
    details: [
      'BuildTrack is an enterprise B2B platform strictly intended for commercial construction personnel aged 18 and older.',
      'We do not knowingly collect, verify, or process data of minors.',
    ],
  ),
  _PolicySection(
    id: 17,
    title: 'Offline Storage & Synchronization',
    summary: 'Encrypted local device cache enabling offline site entries with immediate sync upon reconnection.',
    details: [
      'Mobile app caches site entries locally to permit operations in low-connectivity construction zones.',
      'Local data is encrypted on device and securely synchronized once an active internet connection is detected.',
    ],
  ),
  _PolicySection(
    id: 18,
    title: 'Push Notifications & Communication',
    summary: 'Critical project alerts, approvals, and security updates with user control.',
    details: [
      'Notifications are used strictly for site workflow events: material delivery alerts, supervisor approvals, and security notices.',
      'Users can configure or disable push notifications at any time via App Profile Settings.',
    ],
  ),
  _PolicySection(
    id: 19,
    title: 'Changes & Version History',
    summary: 'Transparent change notices via in-app banner and email before material revisions.',
    details: [
      'We periodically review this policy to reflect platform updates, regulatory guidelines, or statutory revisions.',
      'Material changes will be notified at least 15 days in advance via portal alerts or registered admin email.',
    ],
  ),
  _PolicySection(
    id: 20,
    title: 'Grievance Officer & Statutory Contact',
    summary: 'Officer Vincent (CEO), Nurofin Quantum Financials Labs, Bengaluru. 48-hour response guarantee.',
    details: [
      'Officer: Vincent (Chief Executive Officer).',
      'Organization: Nurofin Quantum Financials Labs Private Limited.',
      'Email: info.nurofin@gmail.com.',
      'Address: Bengaluru, Karnataka, India.',
      'Response SLA: Acknowledgment within 48 hours; resolution within 30 days.',
    ],
  ),
  _PolicySection(
    id: 21,
    title: 'Governing Law & Legal Jurisdiction',
    summary: 'Exclusively governed by the laws of India with courts in Bengaluru having jurisdiction.',
    details: [
      'This agreement and all privacy matters are governed by the laws of the Republic of India.',
      'Exclusive jurisdiction over any legal proceedings resides with the competent courts of Bengaluru, Karnataka, India.',
    ],
  ),
];
