import 'help_translations.dart';

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

  HelpTopic copyWith({
    String? id,
    String? category,
    String? title,
    List<String>? keywords,
    String? summary,
    String? route,
    String? actionLabel,
    String? breadcrumbs,
    List<String>? steps,
    String? tips,
  }) =>
      HelpTopic(
        id: id ?? this.id,
        category: category ?? this.category,
        title: title ?? this.title,
        keywords: keywords ?? this.keywords,
        summary: summary ?? this.summary,
        route: route ?? this.route,
        actionLabel: actionLabel ?? this.actionLabel,
        breadcrumbs: breadcrumbs ?? this.breadcrumbs,
        steps: steps ?? this.steps,
        tips: tips ?? this.tips,
      );

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
    HelpTopic(
      id: 'add_project',
      category: 'projects',
      title: 'How to add a new project',
      keywords: ['add project', 'new project', 'create project', 'start project', 'build site', 'new site'],
      summary: 'Create a new construction project with budget, client info, and milestone phases.',
      route: '/newproject',
      actionLabel: 'Go to Add Project',
      breadcrumbs: 'Projects > + New Project',
      steps: [
        'Navigate to the Projects screen from the bottom bar or left sidebar.',
        'Click the \'+ New Project\' button located at the top right.',
        'Enter the Project Name, Client details (Name, Contact, Email), and Site Address.',
        'Set your Estimated Budget and target Start / Completion dates.',
        'Optionally add initial Project Phases (e.g. Foundation, Structure, Brickwork).',
        'Click \'Save Project\' to immediately initialize your project workspace.',
      ],
      tips: 'Setting realistic phase budget caps during creation will help the system automatically warn you if costs exceed 80%.',
    ),
    HelpTopic(
      id: 'project_phases',
      category: 'projects',
      title: 'Where can I get and configure my project phases?',
      keywords: ['phases', 'project phases', 'get phases', 'milestones', 'stages', 'structure', 'foundation', 'finishing'],
      summary: 'Manage project milestones and track costs for each construction phase.',
      route: '/projects',
      actionLabel: 'View Projects & Phases',
      breadcrumbs: 'Projects > Select Project > Phases',
      steps: [
        'Go to the Projects page from the sidebar or navigation bar.',
        'Click on your desired project card to open its Project Dashboard.',
        'Switch to the \'Phases\' or \'Milestones\' tab.',
        'Here you will see all active stages: Foundation, Structure, Brickwork, MEP (Mechanical/Electrical/Plumbing), and Finishing.',
        'Click \'+ Add Phase\' to create a custom phase or edit existing phase budget allocations.',
      ],
      tips: 'Every entry you log (materials, labour, equipment) can be tagged to a specific phase for granular cost tracking.',
    ),
    HelpTopic(
      id: 'update_progress',
      category: 'projects',
      title: 'How to update project progress',
      keywords: ['update progress', 'progress', 'percentage', 'site completion', 'milestone progress', 'work status'],
      summary: 'Record on-site completion percentages and upload progress photos.',
      route: '/update-progress',
      actionLabel: 'Go to Update Progress',
      breadcrumbs: 'Projects > Manage Site > Update Progress',
      steps: [
        'Open the \'Update Progress\' page from the Projects menu or shortcut.',
        'Select the specific Project and Phase you are updating.',
        'Adjust the completion percentage slider (e.g., set Foundation to 75%).',
        'Add notes explaining recent accomplishments (e.g., \'Completed 3rd floor slab casting\').',
        'Attach site progress photos using the camera or gallery uploader.',
        'Click \'Save Progress\' to broadcast the update to the team.',
      ],
      tips: 'Progress updates automatically refresh the visual progress bars on your home dashboard.',
    ),
    HelpTopic(
      id: 'site_documents',
      category: 'projects',
      title: 'How to upload and view site blueprints & documents',
      keywords: ['blueprints', 'drawings', 'documents', 'plans', 'contracts', 'architectural', 'doc viewer'],
      summary: 'Store and view structural drawings, site photos, and contracts.',
      route: '/managesite',
      actionLabel: 'Manage Site Documents',
      breadcrumbs: 'Projects > Manage Site > Documents',
      steps: [
        'Open the Projects menu and choose \'Manage Site\'.',
        'Select your active construction project.',
        'Click on the \'Documents & Blueprints\' section.',
        'Click \'Upload File\' to attach PDF drawings, floor plans, or municipality approvals.',
        'Tap any document thumbnail to open the built-in full-screen zoomable viewer.',
      ],
      tips: 'Site supervisors on mobile can pinch-to-zoom blueprints directly on-site without needing third-party viewer apps.',
    ),
    HelpTopic(
      id: 'add_entry_general',
      category: 'entries',
      title: 'How to add an entry (Material, Labour, Equipment, Expense)',
      keywords: ['add entry', 'new entry', 'log expense', 'record cost', 'manual entry', 'choose entry mode'],
      summary: 'Record any daily site transaction under Material, Labour, Equipment, or Expense.',
      route: '/add-entry',
      actionLabel: 'Add New Entry',
      breadcrumbs: 'Bottom Bar / Sidebar > + Add Entry',
      steps: [
        'Click the prominent \'+ Add Entry\' button on the bottom bar or sidebar.',
        'Select your logging mode: \'Manual Form\' or \'Voice Assistant\'.',
        'Select the Entry Category: Material, Labour, Equipment, or General Expense.',
        'Choose the target Project and Phase.',
        'Fill in item details, quantity, unit, price/rate, and vendor or contractor name.',
        'Attach a photo of the receipt, delivery slip, or cash voucher.',
        'Click \'Submit Entry\' to record the transaction into the ledger.',
      ],
      tips: 'If you have multiple physical receipts, snap photos directly through the camera attachment button.',
    ),
    HelpTopic(
      id: 'add_material',
      category: 'entries',
      title: 'How to log material purchases (Cement, Steel, Bricks, etc.)',
      keywords: ['material', 'cement', 'steel', 'sand', 'bricks', 'aggregate', 'material entry', 'supplier bill'],
      summary: 'Track site material deliveries, units, rates, suppliers, and bills.',
      route: '/manualentry',
      actionLabel: 'Open Material Entry',
      breadcrumbs: 'Add Entry > Manual Entry > Material',
      steps: [
        'Go to Add Entry and select \'Material\' tab.',
        'Select your Project and the current Phase.',
        'Type the item name (our autocomplete suggests standard items like 53 Grade Cement, TMT 12mm Rebar, River Sand).',
        'Enter Quantity and Unit (Bags, Tons, Sqft, Cum, Nos, etc.).',
        'Specify Unit Rate — the Total Amount calculates automatically.',
        'Select Payment Status: Paid, Pending, or Partial.',
        'Upload the supplier\'s challan or tax invoice, then tap \'Save\'.',
      ],
      tips: 'Entering the supplier\'s name lets you filter all material bills by vendor in the Reports tab.',
    ),
    HelpTopic(
      id: 'add_labour',
      category: 'entries',
      title: 'How to log labour wages & attendance',
      keywords: ['labour', 'wages', 'workers', 'mason', 'carpenter', 'head labour', 'attendance', 'daily wages'],
      summary: 'Record contractor payments, worker counts, trade types, and daily wages.',
      route: '/manualentry',
      actionLabel: 'Open Labour Entry',
      breadcrumbs: 'Add Entry > Manual Entry > Labour',
      steps: [
        'Navigate to Add Entry and switch to the \'Labour\' tab.',
        'Choose the Project and Phase where work was performed.',
        'Enter Contractor / Head Mason name.',
        'Specify the Trade (e.g. Mason, Barbender, Carpenter, Plumber, Helper).',
        'Enter Number of Workers and the Daily Wage Rate per person (or total lumpsum contract amount).',
        'Select Date of work and mark whether payment was settled in cash, UPI, or pending.',
        'Tap \'Submit Labour Entry\'.',
      ],
      tips: 'Logging daily headcounts helps project managers monitor if the site is properly staffed for schedule milestones.',
    ),
    HelpTopic(
      id: 'add_equipment',
      category: 'entries',
      title: 'How to log equipment & machinery rental',
      keywords: ['equipment', 'machinery', 'jcb', 'crane', 'mixer', 'compactor', 'rental', 'fuel', 'operator'],
      summary: 'Track heavy machinery rental hours, fuel expenses, and operator fees.',
      route: '/manualentry',
      actionLabel: 'Open Equipment Entry',
      breadcrumbs: 'Add Entry > Manual Entry > Equipment',
      steps: [
        'In Add Entry, switch to \'Equipment\'.',
        'Choose Project and Phase.',
        'Enter Machinery name (e.g. JCB Backhoe Loader, Transit Mixer, Tower Crane, Generator).',
        'Specify Rental Basis (Hourly, Daily, or Monthly) and units used.',
        'Enter Fuel Expenses and Operator Charges if billed separately.',
        'Enter vendor details and payment status, then tap \'Submit\'.',
      ],
      tips: 'Keeping equipment fuel logs separate ensures accurate maintenance and operating cost analysis.',
    ),
    HelpTopic(
      id: 'voice_assistant',
      category: 'entries',
      title: 'How to use Voice Assistant to log site updates',
      keywords: ['voice', 'voice assistant', 'microphone', 'speak', 'voice logging', 'audio entry', 'ai voice'],
      summary: 'Hands-free AI voice logger that translates spoken language into structured entries.',
      route: '/voice',
      actionLabel: 'Open Voice Assistant',
      breadcrumbs: 'Navigation > Voice',
      steps: [
        'Click on \'Voice\' in the sidebar or bottom bar.',
        'Tap the large blue Microphone button to start recording.',
        'Speak naturally (e.g., \'Bought 60 bags of UltraTech cement for 22,000 rupees from Shree Traders for Downtown Tower\').',
        'Tap Stop. The AI transcription model parses Item, Quantity, Unit, Price, Supplier, and Project.',
        'Review the parsed card on screen — you can tap any field to correct it if necessary.',
        'Tap \'Confirm and Save\' to finalize the entry.',
      ],
      tips: 'Voice Assistant supports noisy site environments and recognizes Indian construction terms and multiple currencies.',
    ),
    HelpTopic(
      id: 'view_receipts',
      category: 'entries',
      title: 'How to view and zoom invoice/receipt photos',
      keywords: ['receipt', 'invoice', 'photo', 'bill', 'zoom', 'challan', 'receipt viewer'],
      summary: 'Inspect high-resolution photo proofs of receipts, invoices, and challans.',
      route: '/transaction',
      actionLabel: 'View Receipts in Ledger',
      breadcrumbs: 'Transaction Log > Entry Detail > View Receipt',
      steps: [
        'Go to the Transaction Log or Ledger.',
        'Click on any entry that has an attachment icon.',
        'In the Entry Details sheet, click on the receipt thumbnail.',
        'The full-screen Receipt Viewer will open allowing you to zoom, rotate, and download the original bill.',
      ],
      tips: 'Tax auditors and clients can verify all expenses with 1-click access to physical bill images.',
    ),
    HelpTopic(
      id: 'esign_receipts',
      category: 'entries',
      title: 'How to digitally sign material receipts (E-Sign)',
      keywords: ['esign', 'signature', 'digital sign', 'sign receipt', 'delivery slip', 'goods received note', 'grn'],
      summary: 'Collect digital signatures on-site for material delivery challans and GRNs.',
      route: '/transaction',
      actionLabel: 'Go to Entries for E-Sign',
      breadcrumbs: 'Transaction Log > Entry Detail > E-Sign',
      steps: [
        'Open the target material delivery entry from Transaction Log.',
        'Click \'Request E-Signature\' or open the signature link.',
        'On mobile or touch screen, the supervisor or storekeeper signs directly on the canvas with their finger or stylus.',
        'Click \'Save Signature\'. A cryptographically verified stamp is attached to the delivery slip.',
      ],
      tips: 'Signed slips prevent vendor disputes regarding missing materials or delayed deliveries.',
    ),
    HelpTopic(
      id: 'upload_csv',
      category: 'csv',
      title: 'How to upload and import a CSV file',
      keywords: ['csv', 'upload csv', 'import csv', 'excel import', 'bulk upload', 'bulk entry', 'import spreadsheet'],
      summary: 'Import hundreds of transactions at once using our Excel or CSV spreadsheet template.',
      route: '/reports',
      actionLabel: 'Go to Import CSV',
      breadcrumbs: 'Reports > Import CSV',
      steps: [
        'Navigate to the \'Reports\' page.',
        'Click the \'Import CSV\' button at the top header.',
        'Click \'Download Template\' to get the standard format with pre-built column headers.',
        'Paste your existing transactions into the template (Date, Project, Category, Item, Qty, Unit, Rate, Amount, Supplier).',
        'Click \'Select CSV File\' and choose your prepared file.',
        'Review the preview table: valid rows show green checks, and errors are highlighted in red with tooltips.',
        'Click \'Confirm Import\' to insert all transactions simultaneously into the database.',
      ],
      tips: 'Make sure project names in the spreadsheet match your existing project names exactly to avoid mismatch warnings.',
    ),
    HelpTopic(
      id: 'csv_template',
      category: 'csv',
      title: 'How to get and format the CSV import template',
      keywords: ['csv template', 'excel template', 'sample csv', 'columns', 'format spreadsheet', 'headers'],
      summary: 'Download the official template with the exact column order required for bulk import.',
      route: '/reports',
      actionLabel: 'Download CSV Template',
      breadcrumbs: 'Reports > Import CSV > Download Template',
      steps: [
        'Open Reports > Import CSV.',
        'Click \'Download Sample Template (.CSV)\'.',
        'Open the downloaded file in Microsoft Excel, Google Sheets, or LibreOffice.',
        'Columns include: `Date` (YYYY-MM-DD), `Project`, `Phase`, `Type` (Material/Labour/Equipment), `Item_Name`, `Quantity`, `Unit`, `Unit_Price`, `Total_Amount`, `Supplier`, `Payment_Status`.',
        'Save as `.csv` format and upload back into BuildTrack.',
      ],
      tips: 'Do not rename or rearrange the top row column headers, as the importer uses them to map the fields.',
    ),
    HelpTopic(
      id: 'add_revenue',
      category: 'finance',
      title: 'How to add revenue / record client payments',
      keywords: ['add revenue', 'record payment', 'client payment', 'incoming payment', 'milestone payment', 'bill client', 'revenue'],
      summary: 'Record incoming funds, client milestone installments, and generate receipts.',
      route: '/transaction',
      actionLabel: 'Record Payment',
      breadcrumbs: 'Dashboard / Projects > Record Payment',
      steps: [
        'Go to the Dashboard or open the specific Project page.',
        'Click the \'Record Payment\' or \'+ Add Revenue\' button.',
        'Select the Project and the paying Client.',
        'Enter the Payment Amount received.',
        'Select the Billing Milestone (e.g. 20% on Plinth Beam Completion).',
        'Select Payment Method: Bank Transfer (NEFT/RTGS), UPI, Cheque, or Cash.',
        'Add UTR / Transaction Reference Number and payment date.',
        'Click \'Save Revenue\' to immediately update your cash-flow balance.',
      ],
      tips: 'Recording client payments promptly ensures your dashboard cash-flow numbers always reflect true financial health.',
    ),
    HelpTopic(
      id: 'check_revenues_cashflow',
      category: 'finance',
      title: 'Where can I check total revenues, costs & net cash flow?',
      keywords: ['check revenue', 'revenues', 'net cash flow', 'cash flow', 'total cost', 'profit', 'balance', 'financials'],
      summary: 'View the real-time financial health cards on your dashboard.',
      route: '/',
      actionLabel: 'View Dashboard Financials',
      breadcrumbs: 'Dashboard > Financial Summary Cards',
      steps: [
        'Open your main Dashboard page.',
        'At the very top, locate the four primary financial indicator cards:',
        '1. \'Total Cost\' — Sum of all approved site expenses (materials + labour + equipment).',
        '2. \'Total Budget\' — Aggregate committed budgets across all active construction sites.',
        '3. \'Total Revenue\' — Sum of all client milestone payments received to date.',
        '4. \'Net Cash Flow\' — Real-time difference: Total Revenue Received minus Total Expenses Incurred.',
        'A positive Net Cash Flow displays in green; negative shows in amber/red alert.',
      ],
      tips: 'Click on any summary card to drill down into project-specific cost breakdowns.',
    ),
    HelpTopic(
      id: 'project_budgets',
      category: 'finance',
      title: 'How to set and monitor phase budgets',
      keywords: ['budget', 'phase budget', 'budget limit', 'cost cap', 'cost overrun', 'budget alert'],
      summary: 'Prevent cost overruns by setting expenditure caps per milestone.',
      route: '/projects',
      actionLabel: 'Manage Project Budgets',
      breadcrumbs: 'Projects > Project Detail > Edit Budget',
      steps: [
        'Navigate to Projects and click on your target project.',
        'Click \'Edit Project\' at top right.',
        'In the Budget allocation table, enter the budgeted amount for each phase (e.g. Structure: \$50,000, MEP: \$20,000).',
        'Save changes.',
        'The system monitors actual entries against these limits and marks phases nearing 100% in amber.',
      ],
      tips: 'Set your contingency reserve under a separate \'General Contingency\' phase to absorb sudden material price hikes.',
    ),
    HelpTopic(
      id: 'where_are_charts',
      category: 'reports',
      title: 'Where can I get my charts and visual analytics?',
      keywords: ['charts', 'get charts', 'graphs', 'visuals', 'insights', 'burn rate', 'pie chart', 'analytics', 'trends'],
      summary: 'Access interactive charts for spend distribution, monthly burn rate, and cash-flow curves.',
      route: '/insights',
      actionLabel: 'Go to Project Insights & Charts',
      breadcrumbs: 'Navigation > Reports > Insights & Charts',
      steps: [
        'Click on \'Insights\' or \'Reports\' in the navigation menu.',
        'You will see interactive visual charts including:',
        '• Category Spend Distribution (Donut / Pie Chart: Materials vs Labour vs Equipment).',
        '• Monthly Burn Rate (Bar Chart comparing site spend month-over-month).',
        '• Cash Flow Curve (Cumulative expenditure line vs client billing).',
        '• Phase Progress Chart (Physical % completion vs budget consumed).',
        'Hover over any bar or slice to view exact dollar amounts and counts.',
      ],
      tips: 'Use the top project selector dropdown to view charts for a single site or portfolio-wide aggregated trends.',
    ),
    HelpTopic(
      id: 'export_reports',
      category: 'reports',
      title: 'How to export reports (PDF, Excel, CSV)',
      keywords: ['export', 'export report', 'download pdf', 'download excel', 'download csv', 'export reports', 'print report'],
      summary: 'Generate executive PDF summaries or export raw Excel/CSV spreadsheets for accounting.',
      route: '/reports',
      actionLabel: 'Go to Reports & Export',
      breadcrumbs: 'Navigation > Reports > Export',
      steps: [
        'Navigate to the \'Reports\' screen.',
        'Use the filters to choose your Project, Phase, Date Range, or Expense Category.',
        'Review the filtered summary table on screen.',
        'Click the \'Export\' dropdown button at the top right.',
        'Choose your preferred export format:',
        '• \'Export as PDF\': Clean, branded PDF formatted with company logo, summary metrics, and signature block.',
        '• \'Export as Excel (.xlsx)\': Multi-sheet spreadsheet ready for Microsoft Excel.',
        '• \'Export as CSV\': Raw comma-separated data for accounting software like Tally or QuickBooks.',
      ],
      tips: 'You can schedule automatic weekly report exports to your email in Settings.',
    ),
    HelpTopic(
      id: 'filter_reports',
      category: 'reports',
      title: 'How to filter reports by project, phase, date, or category',
      keywords: ['filter reports', 'date range', 'category filter', 'search report', 'drill down'],
      summary: 'Narrow down financial data by specific criteria.',
      route: '/reports',
      actionLabel: 'Filter Reports',
      breadcrumbs: 'Reports > Filter Bar',
      steps: [
        'Open Reports.',
        'Click on the \'Project\' dropdown to select one or all projects.',
        'Click \'Phase\' to focus solely on e.g. Foundation or Finishing.',
        'Use the \'Date Range\' picker: select presets (This Week, This Month, Last Quarter) or pick Custom Dates.',
        'Filter by Type: Material, Labour, Equipment, or Miscellaneous.',
        'The metrics, table, and charts update in real time.',
      ],
      tips: 'Click \'Reset Filters\' anytime to clear all active constraints and view all-time totals.',
    ),
    HelpTopic(
      id: 'ai_chat_reports',
      category: 'reports',
      title: 'How to use AI Chat for financial and project inquiries',
      keywords: ['ai chat', 'ask ai', 'ai report', 'natural language', 'cement spend', 'assistant query'],
      summary: 'Ask natural language questions like \'How much did we spend on cement in October?\'.',
      route: '/ai-chat',
      actionLabel: 'Open AI Chat',
      breadcrumbs: 'Sidebar > AI Chat',
      steps: [
        'Click on \'AI Chat\' in the sidebar or top bar.',
        'Type any plain question about your projects or financials.',
        'Examples: \'Which project had the highest labour cost this month?\', \'Show all pending contractor invoices\', \'Total cement bags bought for Site A\'.',
        'The AI queries your live database and replies with exact numbers, formatted tables, and breakdown charts.',
      ],
      tips: 'You can copy or export the AI table responses directly into Excel.',
    ),
    HelpTopic(
      id: 'see_team_members',
      category: 'team',
      title: 'Where can I see my team members?',
      keywords: ['team members', 'see team', 'view team', 'members', 'staff', 'engineers', 'supervisors', 'roster'],
      summary: 'View the roster of all engineers, supervisors, and admins in your organization.',
      route: '/assign-role',
      actionLabel: 'View Team Roster',
      breadcrumbs: 'Sidebar > Assign Roles / Team',
      steps: [
        'Click on \'Assign Roles\' or \'Team\' in the left sidebar menu (or Settings > Team).',
        'You will see the complete roster of all registered members.',
        'Each card shows the member\'s Name, Email, Phone, Assigned Role, and Active Project Sites.',
        'You can filter members by role (Admin, Project Manager, Site Engineer, Supervisor, Accountant).',
      ],
      tips: 'Only Admins and Project Managers have permission to view and modify the organization team roster.',
    ),
    HelpTopic(
      id: 'create_member_account',
      category: 'team',
      title: 'How to create / invite a member\'s account',
      keywords: ['create member', 'add member', 'invite member', 'new user', 'invite team', 'team member account'],
      summary: 'Send email/SMS invitations to add new engineers, supervisors, or accountants.',
      route: '/assign-role',
      actionLabel: 'Invite New Member',
      breadcrumbs: 'Assign Roles > + Add Member',
      steps: [
        'Go to \'Assign Roles\' from the admin sidebar.',
        'Click the \'+ Add Team Member\' button.',
        'Enter the member\'s Full Name, Work Email address, and Phone Number.',
        'Select their default Role (e.g. Site Supervisor, Site Engineer, Accountant, Viewer).',
        'Assign which construction projects they are allowed to access.',
        'Click \'Send Invitation\'. The member receives an email with login credentials and onboarding instructions.',
      ],
      tips: 'Ensure you have available user seats on your subscription plan before inviting extra members.',
    ),
    HelpTopic(
      id: 'assign_task',
      category: 'team',
      title: 'How to give / assign work to another team member',
      keywords: ['assign work', 'assign task', 'give work', 'delegate', 'create task', 'todo', 'task management'],
      summary: 'Create work orders, assign to site engineers, set deadlines, and track status.',
      route: '/assign-task',
      actionLabel: 'Go to Assign Task',
      breadcrumbs: 'Navigation > Assign Task',
      steps: [
        'Click \'Assign Task\' in the navigation bar or sidebar.',
        'Click \'+ Create New Task\'.',
        'Select the target Project and Phase.',
        'Enter Task Title (e.g. \'Complete shuttering inspection for 2nd floor slab\').',
        'Select Assignee from the team member dropdown list.',
        'Set Priority: Low, Medium, High, or Urgent.',
        'Set the Due Date deadline and attach reference drawings or notes if needed.',
        'Click \'Assign Task\'. An instant push notification is sent to the assignee.',
      ],
      tips: 'Assignees can change task status directly from their mobile app to \'In Progress\' or \'Completed\'.',
    ),
    HelpTopic(
      id: 'assign_roles_permissions',
      category: 'team',
      title: 'How to assign roles and manage permissions',
      keywords: ['roles', 'permissions', 'assign role', 'access control', 'privileges', 'admin rights', 'rbac'],
      summary: 'Control who can create projects, approve expenses, or export reports.',
      route: '/assign-role',
      actionLabel: 'Manage Roles & Permissions',
      breadcrumbs: 'Sidebar > Assign Roles',
      steps: [
        'Open \'Assign Roles\' from the admin menu.',
        'Select any team member from the list to open their Permissions drawer.',
        'Choose their role level: Admin, Project Manager, Site Engineer, Supervisor, Accountant, or Viewer.',
        'Toggle granular permissions: \'Can Add Entries\', \'Can Approve Expenses\', \'Can Edit Projects\', \'Can Export Financials\'.',
        'Click \'Update Permissions\' to immediately apply changes.',
      ],
      tips: 'Restricting \'Approve Expenses\' to trusted managers prevents unauthorized budget commitments.',
    ),
    HelpTopic(
      id: 'check_histories',
      category: 'history',
      title: 'How to check transaction histories & ledger',
      keywords: ['histories', 'history', 'check histories', 'transaction log', 'ledger', 'all entries', 'past transactions'],
      summary: 'Browse the complete, searchable audit ledger of every expense and payment.',
      route: '/transaction',
      actionLabel: 'Open Transaction History',
      breadcrumbs: 'Bottom Bar / Sidebar > Transaction Log',
      steps: [
        'Click \'Log\' or \'Transaction Log\' in the navigation menu.',
        'The feed shows all transactions listed in reverse chronological order.',
        'Each item displays the Date, Project, Phase, Category badge, Item name, Quantity, Total Amount, and Creator.',
        'Use the search bar at the top to search by keyword, invoice number, or supplier name.',
        'Tap any item to open the full Entry Detail sheet.',
      ],
      tips: 'Entries with a green checkmark are verified and approved; pending entries show an amber badge.',
    ),
    HelpTopic(
      id: 'check_tags',
      category: 'history',
      title: 'How to check and filter by tags (e.g. #urgent, #foundation)',
      keywords: ['tags', 'check tag', 'tag', 'hashtag', 'filter tags', 'tagging', 'categories'],
      summary: 'Organize site expenses using custom tags and filter the ledger instantly.',
      route: '/transaction',
      actionLabel: 'Filter by Tags',
      breadcrumbs: 'Transaction Log > Filter > Tags',
      steps: [
        'In the Transaction Log, look at the tags displayed under each entry (e.g. `#urgent`, `#steel`, `#subcontractor`).',
        'Click on any tag badge to automatically filter the feed to all items sharing that tag.',
        'Alternatively, tap the \'Filter\' button at top right, open the \'Tags\' section, and check the tags you wish to view.',
        'To add tags to an entry: open the entry in edit mode, type your tag in the Tags input (with or without `#`), and save.',
      ],
      tips: 'Use tags like `#rework` or `#weather_delay` to track unforeseen expense patterns across multiple projects.',
    ),
    HelpTopic(
      id: 'check_audit_logs',
      category: 'history',
      title: 'How to check audit logs (Who changed what and when)',
      keywords: ['audit logs', 'audit trail', 'activity log', 'who deleted', 'security logs', 'compliance'],
      summary: 'Review forensic activity logs of user logins, entry modifications, and deletions.',
      route: '/audit-logs',
      actionLabel: 'View Audit Logs',
      breadcrumbs: 'Sidebar > Audit Logs',
      steps: [
        'From the Admin menu in the sidebar, click \'Audit Logs\'.',
        'The log lists all platform events with Exact Timestamp, User Name, IP Address, Action Type, and Target Record.',
        'Click on any event (e.g. \'ENTRY_UPDATED\' or \'ROLE_CHANGED\') to view the Before & After change diff.',
        'Filter logs by date range or specific user.',
      ],
      tips: 'Audit logs are immutable and comply with standard security and construction compliance requirements.',
    ),
    HelpTopic(
      id: 'check_approvals',
      category: 'history',
      title: 'Where to check pending approvals and approve/reject bills',
      keywords: ['approvals', 'pending approvals', 'approve bill', 'reject entry', 'verify bill', 'site supervisor'],
      summary: 'Review entries submitted by site teams before they affect the official financial balance.',
      route: '/approvals',
      actionLabel: 'Go to Approvals',
      breadcrumbs: 'Sidebar > Approvals',
      steps: [
        'Click \'Approvals\' in the sidebar navigation.',
        'Review the queue of entries submitted from site waiting for managerial verification.',
        'Inspect the item name, amount, unit rate, and attached bill photo.',
        'Click \'Approve\' to approve the bill and update project spend.',
        'Or click \'Reject\', provide a reason (e.g. \'Duplicate bill\' or \'Wrong quantity\'), and return it to the submitter.',
      ],
      tips: 'Site supervisors can be notified automatically when an entry they submitted is approved or rejected.',
    ),
    HelpTopic(
      id: 'create_account_general',
      category: 'account',
      title: 'How to create an account / Sign up for BuildTrack',
      keywords: ['create account', 'sign up', 'register', 'new account', 'join', 'get started'],
      summary: 'Register your company or individual account to get started.',
      route: '/signup',
      actionLabel: 'Go to Sign Up',
      breadcrumbs: 'Login Screen > Create Account',
      steps: [
        'Open BuildTrack on web or mobile and tap \'Sign Up\' / \'Create Account\'.',
        'Enter your Full Name, Work Email, and secure Password.',
        'Provide your Company / Contractor Name and select your Primary Industry (Residential, Commercial, Infrastructure).',
        'Alternatively, tap \'Continue with Google\' for one-click OAuth registration.',
        'Verify your email and log in to begin creating your first project.',
      ],
      tips: 'Your first workspace starts with a free trial so you can explore all features before subscribing.',
    ),
    HelpTopic(
      id: 'subscribe_plan',
      category: 'account',
      title: 'How to subscribe or upgrade your plan',
      keywords: ['subscribe', 'how to subscribe', 'subscription', 'upgrade plan', 'pricing', 'payment', 'pro plan', 'billing'],
      summary: 'Unlock unlimited projects, team seats, voice AI, and cloud storage.',
      route: '/subscription',
      actionLabel: 'Go to Subscription',
      breadcrumbs: 'Sidebar / Profile > Subscription',
      steps: [
        'Click \'Subscription\' in the sidebar menu (or go to Settings > Subscription).',
        'Compare the available tiers: Starter, Professional, or Enterprise.',
        'Select Monthly or Annual billing (annual includes discount).',
        'Click \'Upgrade Now\'.',
        'Complete payment through the secure payment gateway (Cards, NetBanking, UPI).',
        'Your plan activates instantly and receipt is available for download.',
      ],
      tips: 'Invoices for subscription fees include GST/VAT details for tax write-offs.',
    ),
    HelpTopic(
      id: 'edit_profile',
      category: 'account',
      title: 'How to edit profile, change avatar & company info',
      keywords: ['profile', 'edit profile', 'avatar', 'photo', 'phone', 'company name', 'settings'],
      summary: 'Update your contact details, designation, and company branding.',
      route: '/settings',
      actionLabel: 'Open Profile Settings',
      breadcrumbs: 'Top Bar / Sidebar > Settings > Profile',
      steps: [
        'Click your avatar or \'Settings\' in the top header.',
        'In the \'Profile\' section, edit your Display Name, Phone Number, and Title.',
        'Click \'Upload Photo\' to change your profile picture.',
        'Update your Company Name and primary office address.',
        'Click \'Save Profile Changes\'.',
      ],
      tips: 'Your company name and logo set in Profile will appear on all exported PDF project reports.',
    ),
    HelpTopic(
      id: 'change_theme',
      category: 'account',
      title: 'How to change app theme (Dark Noir / Light)',
      keywords: ['theme', 'dark mode', 'light mode', 'appearance', 'styling', 'noir'],
      summary: 'Toggle between Blueprint Noir dark mode and daylight outdoor light mode.',
      route: '/settings',
      actionLabel: 'Change Theme',
      breadcrumbs: 'Settings > Appearance',
      steps: [
        'Open Settings.',
        'Scroll to the \'Appearance & Theme\' section.',
        'Select \'Noir Dark\' for high-contrast indoor viewing or \'Light\' for bright outdoor sunlight conditions.',
        'Select \'System\' to automatically match your device operating system.',
      ],
      tips: 'Dark Noir saves battery life on OLED mobile screens during all-day on-site usage.',
    ),
    HelpTopic(
      id: 'replay_tour',
      category: 'account',
      title: 'How to replay the visual app tour',
      keywords: ['guide', 'tour', 'replay tour', 'walkthrough', 'app guide', 'spotlight'],
      summary: 'Restart the spotlight walkthrough highlighting key buttons across the interface.',
      route: '/',
      actionLabel: 'Start Visual Tour',
      breadcrumbs: 'Sidebar > Help (?) > Replay Tour',
      steps: [
        'Click the Help (?) icon in the sidebar or top bar.',
        'Select \'Replay Visual Tour\'.',
        'Interactive spotlight bubbles will appear over the Dashboard, Projects, Entries, and Reports buttons.',
        'Click \'Next\' to walk through each screen element at your own pace.',
      ],
      tips: 'You can dismiss the tour at any time by pressing \'Skip\' or hitting Escape.',
    ),
    HelpTopic(
      id: 'report_problem',
      category: 'account',
      title: 'How to report a problem, bug, or glitch',
      keywords: ['report problem', 'report a problem', 'report issue', 'report bug', 'problem', 'bug', 'glitch', 'error', 'feedback', 'support', 'app not working', 'something not working', 'contact support', 'shake to report', 'crash'],
      summary: 'Encountered a bug, calculation error, or visual glitch? Submit a report with instant automatic screenshots.',
      route: '/settings',
      actionLabel: 'Report a Problem Now',
      breadcrumbs: 'Sidebar / Profile > Report a Problem',
      steps: [
        'On Web Portal: Click the \'Report a problem\' link located at the bottom of the left sidebar navigation.',
        'On Mobile App: Tap your \'Profile\' avatar at top right, then tap \'Report a problem\' (or simply shake your phone if Shake to Report is enabled).',
        'Select the issue category (e.g. Calculation error, Visual glitch, Crashing, Sync failure).',
        'Describe what happened, what you expected, and optionally attach photos or receipt screenshots.',
        'Click \'Send Report\'. You can track status and developer replies anytime in \'Your Reports\'.',
      ],
      tips: 'On mobile devices, shaking your phone on any screen will automatically capture what went wrong without losing your work.',
    ),
  ];

  /// Returns the localized topic for the given language code (kn, hi, te, ta, ml).
  /// Falls back to English if translation is unavailable.
  static HelpTopic getLocalizedTopic(HelpTopic topic, String langCode) {
    if (langCode.isEmpty || langCode == 'en') return topic;

    final translation = HelpTranslations.getTranslation(langCode, topic.id);
    if (translation == null) return topic;

    return topic.copyWith(
      title: translation.title,
      summary: translation.summary,
      breadcrumbs: translation.breadcrumbs,
      steps: translation.steps,
      tips: translation.tips ?? topic.tips,
      actionLabel: translation.actionLabel ?? topic.actionLabel,
    );
  }

  /// Multilingual search engine: matches queries across English and regional translations.
  static List<HelpTopic> search(String query, {String? category, String langCode = 'en'}) {
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

      // Check all regional language translations (Kannada, Hindi, Telugu, Tamil, Malayalam)
      for (final lang in HelpTranslations.topicTranslations.keys) {
        final tr = HelpTranslations.getTranslation(lang, topic.id);
        if (tr == null) continue;

        final tTitle = tr.title.toLowerCase();
        final tSummary = tr.summary.toLowerCase();

        if (tTitle.contains(q)) score += 50;
        if (tSummary.contains(q)) score += 20;

        for (final tok in tokens) {
          if (tTitle.contains(tok)) score += 15;
          if (tSummary.contains(tok)) score += 8;
          for (final step in tr.steps) {
            if (step.toLowerCase().contains(tok)) {
              score += 5;
              break;
            }
          }
        }
      }

      if (score > 0) scored.add(MapEntry(topic, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }
}
