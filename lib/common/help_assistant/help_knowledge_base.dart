class HelpCategory {
  final String id;
  final String label;

  const HelpCategory({required this.id, required this.label});
}

class HelpTopic {
  final String id;
  final String category;
  final String title;
  final List<String> keywords;
  final String summary;
  final String route;
  final String actionLabel;
  final String breadcrumbs;
  final List<String> steps;
  final String? tips;

  const HelpTopic({
    required this.id,
    required this.category,
    required this.title,
    required this.keywords,
    required this.summary,
    required this.route,
    required this.actionLabel,
    required this.breadcrumbs,
    required this.steps,
    this.tips,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'keywords': keywords,
        'summary': summary,
        'route': route,
        'actionLabel': actionLabel,
        'breadcrumbs': breadcrumbs,
        'steps': steps,
        'tips': tips,
      };

  factory HelpTopic.fromJson(Map<String, dynamic> json) => HelpTopic(
        id: json['id'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        keywords: List<String>.from(json['keywords'] as List),
        summary: json['summary'] as String,
        route: json['route'] as String,
        actionLabel: json['actionLabel'] as String,
        breadcrumbs: json['breadcrumbs'] as String,
        steps: List<String>.from(json['steps'] as List),
        tips: json['tips'] as String?,
      );
}

class HelpKnowledgeBase {
  static const List<HelpCategory> categories = [
    HelpCategory(id: 'all', label: 'All Topics'),
    HelpCategory(id: 'projects', label: 'Projects & Phases'),
    HelpCategory(id: 'entries', label: 'Site Entries & Voice'),
    HelpCategory(id: 'csv', label: 'CSV & Bulk Import'),
    HelpCategory(id: 'finance', label: 'Revenue & Budgets'),
    HelpCategory(id: 'reports', label: 'Reports & Charts'),
    HelpCategory(id: 'team', label: 'Team & Tasks'),
    HelpCategory(id: 'history', label: 'History & Tags'),
    HelpCategory(id: 'account', label: 'Account & Billing'),
  ];

  static const List<HelpTopic> topics = [
    // ─── 1. PROJECTS & PHASES ───
    HelpTopic(
      id: 'add_project',
      category: 'projects',
      title: 'How to add a new project',
      keywords: ['add project', 'new project', 'create project', 'start project', 'build site'],
      summary: 'Create a new construction project with budget, client info, and milestone phases.',
      route: '/projects',
      actionLabel: 'Go to Projects',
      breadcrumbs: 'Bottom Bar > Projects > + Add Project',
      steps: [
        'Tap the "Projects" tab on the bottom navigation bar.',
        'Tap the "+ New Project" button at the top right of the screen.',
        'Enter Project Name, Client Name, Contact Number, and Site Location.',
        'Specify Estimated Budget and targeted Start & End Dates.',
        'Configure milestone phases (Foundation, Structure, Brickwork, MEP, Finishing).',
        'Tap "Save Project" to initialize your site dashboard.',
      ],
      tips: 'Setting phase budget caps during creation will trigger automatic warnings when expenses reach 80%.',
    ),
    HelpTopic(
      id: 'project_phases',
      category: 'projects',
      title: 'Where can I get and configure my project phases?',
      keywords: ['phases', 'project phases', 'get phases', 'milestones', 'stages', 'structure', 'foundation'],
      summary: 'Manage milestone stages and allocate budgets for each construction phase.',
      route: '/projects',
      actionLabel: 'View Projects & Phases',
      breadcrumbs: 'Projects > Select Project > Phases Tab',
      steps: [
        'Open the Projects screen from the bottom navigation.',
        'Tap on your project card to open Project Details.',
        'Switch to the "Phases" tab.',
        'View active phases: Foundation, Structure, Masonry, Plumbing, Electrical, Finishing.',
        'Tap "+ Add Phase" to insert custom stages or adjust phase budget caps.',
      ],
      tips: 'Every entry (material, labour, equipment) is linked to a phase to provide granular spend breakdowns.',
    ),
    HelpTopic(
      id: 'update_progress',
      category: 'projects',
      title: 'How to update project progress',
      keywords: ['update progress', 'progress', 'percentage', 'site completion', 'milestone status'],
      summary: 'Log physical on-site completion percentage and attach progress photos.',
      route: '/update-progress',
      actionLabel: 'Go to Update Progress',
      breadcrumbs: 'Projects > Project Detail > Update Progress',
      steps: [
        'Open Update Progress from the project screen or quick actions.',
        'Select the target Project and Phase.',
        'Drag the completion slider to the current percentage (e.g. 70%).',
        'Add brief notes regarding completed work.',
        'Snap or upload photos of completed site work.',
        'Tap "Save Progress" to update team members.',
      ],
      tips: 'Updating progress keeps the dashboard progress rings accurate for clients and investors.',
    ),

    // ─── 2. ENTRIES & VOICE ───
    HelpTopic(
      id: 'add_entry_general',
      category: 'entries',
      title: 'How to add an entry (Material, Labour, Equipment, Expense)',
      keywords: ['add entry', 'new entry', 'log expense', 'record cost', 'manual entry', 'quick add'],
      summary: 'Record daily on-site transactions with photos of receipts and challans.',
      route: '/add-entry',
      actionLabel: 'Add New Entry',
      breadcrumbs: 'Bottom Bar > + (Center Button)',
      steps: [
        'Tap the large "+" button in the center of the bottom navigation bar.',
        'Choose your entry category: Material, Labour, Equipment, or Expense.',
        'Select the Project and Phase.',
        'Fill item name, quantity, unit rate, and supplier/contractor.',
        'Tap the camera icon to photograph the receipt or delivery challan.',
        'Tap "Submit Entry" to commit to the site ledger.',
      ],
      tips: 'You can tap the microphone tab inside Add Entry to log hands-free using AI voice!',
    ),
    HelpTopic(
      id: 'add_material',
      category: 'entries',
      title: 'How to log material purchases (Cement, Steel, Bricks, etc.)',
      keywords: ['material', 'cement', 'steel', 'sand', 'bricks', 'material entry', 'supplier'],
      summary: 'Track material delivery quantities, unit prices, vendors, and bills.',
      route: '/add-material',
      actionLabel: 'Open Material Entry',
      breadcrumbs: 'Add Entry > Material Tab',
      steps: [
        'Open Add Entry and choose "Material".',
        'Select Project and active Phase.',
        'Select or type item name (Cement, 12mm TMT Steel, River Sand, Red Bricks).',
        'Input Quantity and Unit (Bags, Tons, Brass, Sqft, Nos).',
        'Enter Unit Price — total cost calculates automatically.',
        'Specify Supplier Name and Payment Status (Paid, Pending).',
        'Upload delivery receipt photo and tap "Save".',
      ],
      tips: 'Filtering by supplier in Reports gives you the exact outstanding dues for each vendor.',
    ),
    HelpTopic(
      id: 'add_labour',
      category: 'entries',
      title: 'How to log labour wages & worker attendance',
      keywords: ['labour', 'wages', 'workers', 'mason', 'carpenter', 'daily wages', 'contractor'],
      summary: 'Record contractor payments, worker counts, trade types, and daily wages.',
      route: '/add-labour',
      actionLabel: 'Open Labour Entry',
      breadcrumbs: 'Add Entry > Labour Tab',
      steps: [
        'Open Add Entry and select "Labour".',
        'Select Project and Phase.',
        'Enter Contractor / Head Mason name.',
        'Choose Trade (Mason, Carpenter, Barbender, Plumber, Helper).',
        'Enter Worker Count and Daily Wage Rate (or contract lumpsum).',
        'Mark payment settled (Cash/UPI) or pending, then tap "Save".',
      ],
      tips: 'Daily labour logs maintain an accurate record of site attendance and weekly payroll.',
    ),
    HelpTopic(
      id: 'add_equipment',
      category: 'entries',
      title: 'How to log equipment & machinery rental',
      keywords: ['equipment', 'machinery', 'jcb', 'crane', 'mixer', 'fuel', 'rental', 'operator'],
      summary: 'Track heavy machinery rental hours, fuel expenses, and operator fees.',
      route: '/add-equipment',
      actionLabel: 'Open Equipment Entry',
      breadcrumbs: 'Add Entry > Equipment Tab',
      steps: [
        'Open Add Entry and choose "Equipment".',
        'Select Project and Phase.',
        'Enter Machinery type (JCB, Transit Mixer, Tower Crane, Compactor).',
        'Select Rental Duration (Hours or Days) and rental rate.',
        'Add Fuel and Operator charges if billed separately.',
        'Upload invoice and tap "Save".',
      ],
    ),
    HelpTopic(
      id: 'voice_assistant',
      category: 'entries',
      title: 'How to use Voice Assistant to log entries',
      keywords: ['voice', 'voice assistant', 'microphone', 'speak', 'audio entry', 'hands-free'],
      summary: 'Speak naturally into the microphone to log site updates without typing.',
      route: '/review-material',
      actionLabel: 'Open Voice Entry',
      breadcrumbs: 'Bottom Bar > Voice Assistant',
      steps: [
        'Tap the Voice tab on your navigation bar.',
        'Tap the blue Microphone button to start listening.',
        'Speak clearly: "Bought 50 bags of ACC cement for 19000 from Royal Traders for Villa Project".',
        'Tap Stop. AI extracts the fields automatically.',
        'Review the parsed values on screen and tap "Confirm and Save".',
      ],
      tips: 'Voice logging works offline and syncs automatically once an internet connection is restored.',
    ),

    // ─── 3. CSV & BULK IMPORT ───
    HelpTopic(
      id: 'upload_csv',
      category: 'csv',
      title: 'How to upload and import a CSV file',
      keywords: ['csv', 'upload csv', 'import csv', 'excel import', 'bulk upload', 'bulk transactions'],
      summary: 'Import hundreds of transactions at once using our spreadsheet template.',
      route: '/reports',
      actionLabel: 'Go to Reports / Import CSV',
      breadcrumbs: 'Reports > Import CSV Button',
      steps: [
        'Navigate to the Reports screen.',
        'Tap the "Import CSV" button in the upper toolbar.',
        'Tap "Download Template" to get the standard format.',
        'Fill your entries in Excel or Google Sheets with required headers (Date, Project, Category, Item, Qty, Amount).',
        'Tap "Choose CSV File" to upload.',
        'Review the preview table and tap "Confirm Import" to save.',
      ],
      tips: 'Ensure project names in the spreadsheet match your registered project names exactly.',
    ),

    // ─── 4. REVENUE & BUDGETS ───
    HelpTopic(
      id: 'add_revenue',
      category: 'finance',
      title: 'How to add revenue / record client payments',
      keywords: ['add revenue', 'record payment', 'client payment', 'incoming', 'milestone payment', 'revenue'],
      summary: 'Record client milestone payments, incoming funds, and receipts.',
      route: '/fulfillment-payment',
      actionLabel: 'Record Payment',
      breadcrumbs: 'Dashboard > Record Payment',
      steps: [
        'On the Home Dashboard, tap "Record Payment" or "+ Add Revenue".',
        'Select the Project and Client.',
        'Enter Payment Amount received.',
        'Specify the milestone billed (e.g. 2nd Floor Slab Cast).',
        'Choose payment method: Bank Transfer, UPI, Cheque, or Cash.',
        'Enter reference/UTR number and tap "Save Payment".',
      ],
      tips: 'Client payments immediately update your Net Cash Flow gauge on the dashboard.',
    ),
    HelpTopic(
      id: 'check_revenues_cashflow',
      category: 'finance',
      title: 'Where can I check total revenues, costs & net cash flow?',
      keywords: ['check revenue', 'revenues', 'net cash flow', 'cash flow', 'total cost', 'profit', 'balance'],
      summary: 'Monitor financial metrics and profitability on your home dashboard.',
      route: '/home',
      actionLabel: 'Go to Dashboard',
      breadcrumbs: 'Home Dashboard > Top Metric Cards',
      steps: [
        'Open the Home screen.',
        'At the top, inspect the primary financial metrics:',
        '• Total Cost: Aggregate site expenses across material, labour, and equipment.',
        '• Total Budget: Combined budget allocations for active sites.',
        '• Total Revenue: Total milestone payments collected from clients.',
        '• Net Cash Flow: Revenue minus Cost (green is cash positive, red indicates deficit).',
      ],
    ),

    // ─── 5. REPORTS & CHARTS ───
    HelpTopic(
      id: 'where_are_charts',
      category: 'reports',
      title: 'Where can I get my charts and visual analytics?',
      keywords: ['charts', 'get charts', 'graphs', 'visuals', 'insights', 'burn rate', 'pie chart', 'analytics'],
      summary: 'View interactive visual graphs for category spend, monthly burn rate, and cash curves.',
      route: '/insights',
      actionLabel: 'Go to Insights & Charts',
      breadcrumbs: 'Navigation > Insights Hub',
      steps: [
        'Tap on "Insights" or open Insights Hub from Reports.',
        'View visual analytics:',
        '• Category Spend Breakdown (Pie chart of Material vs Labour vs Equipment).',
        '• Monthly Spend Trend (Bar graph comparing monthly site expenditure).',
        '• Cash Flow Curve (Expenditure curve vs client billing).',
        '• Phase Progress vs Budget Consumed.',
      ],
      tips: 'Filter charts by a single site or view portfolio-wide trends across all projects.',
    ),
    HelpTopic(
      id: 'export_reports',
      category: 'reports',
      title: 'How to export reports (PDF, Excel, CSV)',
      keywords: ['export', 'export report', 'download pdf', 'download excel', 'download csv', 'export reports'],
      summary: 'Download formatted PDF reports or Excel sheets for audits and accounting.',
      route: '/reports',
      actionLabel: 'Go to Reports',
      breadcrumbs: 'Reports Screen > Export Button',
      steps: [
        'Open the Reports screen from the navigation menu.',
        'Apply filters for Project, Phase, Date Range, or Category.',
        'Tap the "Export" button at the top right.',
        'Choose your desired format: "Export as PDF" or "Export as Excel (.xlsx / .csv)".',
        'Share the generated report via WhatsApp, Email, or save to your device storage.',
      ],
      tips: 'PDF reports include your company logo, summary metrics, and signature lines.',
    ),
    HelpTopic(
      id: 'ai_chat_reports',
      category: 'reports',
      title: 'How to use AI Chat for financial and project inquiries',
      keywords: ['ai chat', 'ask ai', 'ai report', 'cement spend', 'query data', 'assistant'],
      summary: 'Ask natural language questions like "How much did we spend on cement this month?".',
      route: '/ai-chat',
      actionLabel: 'Open AI Chat',
      breadcrumbs: 'Navigation > AI Chat',
      steps: [
        'Tap on "AI Chat" in the menu or Reports screen.',
        'Type or speak any question about your sites or accounts.',
        'Example: "Show all unpaid labour bills for Site B" or "Total steel cost in June".',
        'The AI answers instantly with formatted tables and totals.',
      ],
    ),

    // ─── 6. TEAM & TASKS ───
    HelpTopic(
      id: 'see_team_members',
      category: 'team',
      title: 'Where can I see my team members?',
      keywords: ['team members', 'see team', 'view team', 'members', 'staff', 'roster', 'engineers'],
      summary: 'View all engineers, supervisors, and admins in your organization.',
      route: '/assign-role',
      actionLabel: 'View Team Members',
      breadcrumbs: 'Sidebar / Settings > Assign Roles',
      steps: [
        'Open "Assign Roles" from the menu or Profile > Team.',
        'View the full roster of registered team members.',
        'Check member names, emails, phone numbers, assigned roles, and assigned sites.',
      ],
    ),
    HelpTopic(
      id: 'create_member_account',
      category: 'team',
      title: 'How to create / invite a member\'s account',
      keywords: ['create member', 'add member', 'invite member', 'new user', 'invite team'],
      summary: 'Invite engineers, supervisors, or accountants to join your workspace.',
      route: '/assign-role',
      actionLabel: 'Invite Team Member',
      breadcrumbs: 'Assign Roles > + Add Member',
      steps: [
        'Open Assign Roles.',
        'Tap "+ Add Member" at top right.',
        'Enter Name, Work Email, Phone Number.',
        'Select their Role (Site Engineer, Supervisor, Accountant, Admin).',
        'Select which construction projects they can access.',
        'Tap "Send Invitation".',
      ],
    ),
    HelpTopic(
      id: 'assign_task',
      category: 'team',
      title: 'How to give / assign work to another team member',
      keywords: ['assign work', 'assign task', 'give work', 'delegate', 'create task', 'todo'],
      summary: 'Create site tasks, assign to members, set deadlines, and track status.',
      route: '/assign-task',
      actionLabel: 'Go to Assign Task',
      breadcrumbs: 'Navigation > Assign Task',
      steps: [
        'Tap "Assign Task" from the navigation menu.',
        'Tap "+ Create Task".',
        'Select the target Project and Phase.',
        'Enter Task Title and detailed instructions.',
        'Select Assignee from your team roster.',
        'Set Priority (Low/Medium/High) and Due Date.',
        'Tap "Assign Task" — the member receives a push notification.',
      ],
    ),

    // ─── 7. HISTORY & TAGS ───
    HelpTopic(
      id: 'check_histories',
      category: 'history',
      title: 'How to check transaction histories & site ledger',
      keywords: ['histories', 'history', 'check histories', 'transaction log', 'ledger', 'all entries'],
      summary: 'Browse chronological history of every expense and payment.',
      route: '/logs',
      actionLabel: 'Open Transaction Log',
      breadcrumbs: 'Bottom Bar / Menu > Transaction Log',
      steps: [
        'Tap "Log" or "Transaction Log" in the navigation bar.',
        'Browse all entries listed by date.',
        'Use search to find specific items, suppliers, or amounts.',
        'Tap any entry to view full details and receipt photos.',
      ],
    ),
    HelpTopic(
      id: 'check_tags',
      category: 'history',
      title: 'How to check and filter by tags (e.g. #urgent, #foundation)',
      keywords: ['tags', 'check tag', 'tag', 'hashtag', 'filter tags', 'tagging'],
      summary: 'Organize site expenses using custom tags and filter quickly.',
      route: '/logs',
      actionLabel: 'Filter by Tags in Ledger',
      breadcrumbs: 'Transaction Log > Filter > Tags',
      steps: [
        'In Transaction Log, tap the Filter icon.',
        'Open the Tags section.',
        'Select any tag (#urgent, #foundation, #subcontractor) to filter.',
        'To add tags: edit any entry, type your tag in the Tags field, and save.',
      ],
    ),
    HelpTopic(
      id: 'check_approvals',
      category: 'history',
      title: 'Where to check pending approvals and approve bills',
      keywords: ['approvals', 'pending approvals', 'approve bill', 'verify bill', 'reject entry'],
      summary: 'Review site entries submitted by supervisors before committing to the balance.',
      route: '/approvals',
      actionLabel: 'Go to Approvals',
      breadcrumbs: 'Menu > Approvals',
      steps: [
        'Open Approvals from the menu.',
        'Review pending site entries.',
        'Inspect item, quantity, amount, and receipt photos.',
        'Tap "Approve" to commit or "Reject" with feedback.',
      ],
    ),

    // ─── 8. ACCOUNT & BILLING ───
    HelpTopic(
      id: 'subscribe_plan',
      category: 'account',
      title: 'How to subscribe or upgrade your plan',
      keywords: ['subscribe', 'subscription', 'upgrade plan', 'pricing', 'payment', 'pro plan', 'billing'],
      summary: 'Unlock unlimited projects, team seats, voice AI, and cloud storage.',
      route: '/subscription',
      actionLabel: 'Go to Subscription',
      breadcrumbs: 'Profile > Subscription',
      steps: [
        'Go to Profile > Subscription.',
        'Compare plans: Starter, Pro, Enterprise.',
        'Select Monthly or Annual billing.',
        'Tap "Upgrade Now" and complete checkout via the payment gateway.',
        'Features unlock immediately upon completion.',
      ],
    ),
    HelpTopic(
      id: 'edit_profile',
      category: 'account',
      title: 'How to edit profile, change avatar & company info',
      keywords: ['profile', 'edit profile', 'avatar', 'photo', 'phone', 'company name'],
      summary: 'Update your contact information, photo, and company details.',
      route: '/profile',
      actionLabel: 'Open Profile',
      breadcrumbs: 'Home > Profile Avatar (Top Right)',
      steps: [
        'Tap your Profile Avatar at the top right of the Home screen.',
        'Tap "Edit Profile".',
        'Update Name, Phone, and Company Name.',
        'Tap the avatar camera icon to upload a new profile picture.',
        'Tap "Save Changes".',
      ],
    ),
    HelpTopic(
      id: 'replay_tour',
      category: 'account',
      title: 'How to replay the visual app tour',
      keywords: ['guide', 'tour', 'replay tour', 'walkthrough', 'app guide', 'showcase'],
      summary: 'Restart the spotlight tour highlighting on-screen buttons.',
      route: '/home',
      actionLabel: 'Replay Visual Tour',
      breadcrumbs: 'Home > Help Icon > Replay Tour',
      steps: [
        'Tap the Help (?) icon on the top bar of the Home screen.',
        'Choose "Visual Tour" in the Help Assistant.',
        'Spotlight tooltips will walk you through every dashboard element.',
      ],
    ),
  ];

  static List<HelpTopic> search(String query, {String? category}) {
    final q = query.trim().toLowerCase();
    List<HelpTopic> list = topics;
    if (category != null && category != 'all') {
      list = list.where((t) => t.category == category).toList();
    }
    if (q.isEmpty) return list;

    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    final scored = <MapEntry<HelpTopic, int>>[];
    for (final topic in list) {
      int score = 0;
      final title = topic.title.toLowerCase();
      if (title.contains(q)) score += 50;

      for (final kw in topic.keywords) {
        final lkw = kw.toLowerCase();
        if (lkw == q) {
          score += 40;
        } else if (lkw.contains(q) || q.contains(lkw)) {
          score += 25;
        } else {
          for (final tok in tokens) {
            if (lkw.contains(tok)) score += 8;
          }
        }
      }

      if (topic.summary.toLowerCase().contains(q)) score += 15;
      for (final step in topic.steps) {
        if (step.toLowerCase().contains(q)) score += 5;
      }

      if (score > 0) scored.add(MapEntry(topic, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }
}
