import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
enum UserRole { admin, supervisor, mason }
class UserSession extends ChangeNotifier {
  static final UserSession _instance = UserSession._();
  factory UserSession() => _instance;
  UserSession._();
  static const String _kSessionKey = 'buildtrack_user_session';
  static String _userId = '';
  static UserRole _role = UserRole.mason;
  static String? _profilePhoto;
  static String _companyName = '';
  static String _companyFontStyle = 'Inter';
  static String? _companyLogo;
  static String _rawRoleName = '';
  static List<String> _overseesRoles = [];
  static List<String> _projectIds = [];
  static String get projectId =>
      _projectIds.isNotEmpty ? _projectIds.first : '';
  static set projectId(String value) {
    if (value.isEmpty) {
      _projectIds = [];
    } else if (!_projectIds.contains(value)) {
      _projectIds = [value, ..._projectIds];
    }
    _instance.notifyListeners();
  }
  static List<String> _permissions = [];
  static bool _initialized = false;
  static String get userId => _userId;
  static UserRole get role => _role;
  static String get companyName => _companyName;
  static String get companyFontStyle => _companyFontStyle;
  static String? get companyLogo => _companyLogo;
  static List<String> get projectIds => List.unmodifiable(_projectIds);
  static List<String> get overseesRoles => List.unmodifiable(_overseesRoles);
  static List<String> get permissions => List.unmodifiable(_permissions);
  static bool get isInitialized => _initialized;
  static String? get profilePhoto => _profilePhoto;
  static bool get isAdmin => _role == UserRole.admin;
  static bool get isSupervisor => _role == UserRole.supervisor;
  static bool get isMason => _role == UserRole.mason;

  static TextStyle getCompanyTextStyle({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double? letterSpacing,
  }) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
    switch (_companyFontStyle.toLowerCase().trim()) {
      case 'outfit':
        return GoogleFonts.outfit(textStyle: baseStyle);
      case 'poppins':
        return GoogleFonts.poppins(textStyle: baseStyle);
      case 'montserrat':
        return GoogleFonts.montserrat(textStyle: baseStyle);
      case 'roboto':
        return GoogleFonts.roboto(textStyle: baseStyle);
      case 'playfair display':
        return GoogleFonts.playfairDisplay(textStyle: baseStyle);
      case 'cinzel':
        return GoogleFonts.cinzel(textStyle: baseStyle);
      case 'caveat':
        return GoogleFonts.caveat(textStyle: baseStyle);
      case 'inter':
      default:
        return GoogleFonts.inter(textStyle: baseStyle);
    }
  }
  static bool hasProjectAccess(String pid) {
    if (isAdmin) return true;
    return _projectIds.any((id) => id.trim() == pid.trim());
  }
  static String get roleLabel {
    if (_rawRoleName.isNotEmpty) return _rawRoleName;
    switch (_role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.mason:
        return 'Mason';
    }
  }
  static bool hasPermission(String key) {
    if (isAdmin) return true;
    return _permissions.contains(key);
  }
  static Future<void> fromLoginResponse(Map<String, dynamic> user) async {
    _userId = user['id']?.toString() ?? '';
    final rawRoleStr = user['role']?.toString() ?? '';
    _rawRoleName = _toDisplayName(rawRoleStr);
    _role = _parseRole(rawRoleStr);
    final rawIds = user['projectIds'];
    if (rawIds is List) {
      _projectIds = rawIds
          .where((e) => e != null && e.toString().isNotEmpty)
          .map((e) => e.toString())
          .toList();
    } else {
      final legacyId = user['projectId']?.toString() ?? '';
      _projectIds = legacyId.isNotEmpty ? [legacyId] : [];
    }
    final raw = user['permissions'];
    if (raw is List) {
      _permissions = raw.map((e) => e.toString()).toList();
    } else {
      _permissions = [];
    }
    final rawOversees = user['overseesRoles'];
    if (rawOversees is List) {
      _overseesRoles = rawOversees.map((e) => e.toString()).toList();
    } else {
      _overseesRoles = [];
    }
    _profilePhoto = user['profilePhoto']?.toString();
    _companyName = user['companyName']?.toString() ?? '';
    _companyFontStyle = user['companyFontStyle']?.toString() ?? 'Inter';
    _companyLogo = user['companyLogo']?.toString();
    _initialized = true;
    await _persist();
    _instance.notifyListeners();
    debugPrint(
      '[UserSession] fromLoginResponse → '
      'role=$roleLabel (_raw=$_rawRoleName) company=$_companyName font=$_companyFontStyle projectIds=$_projectIds permissions=$_permissions',
    );
  }
  static Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSessionKey);
      if (raw == null || raw.isEmpty) {
        _initialized = true;
        _instance.notifyListeners();
        return;
      }
      final data = json.decode(raw) as Map<String, dynamic>;
      _userId = data['id']?.toString() ?? '';
      _profilePhoto = data['profilePhoto']?.toString();
      _companyName = data['companyName']?.toString() ?? '';
      _companyFontStyle = data['companyFontStyle']?.toString() ?? 'Inter';
      _companyLogo = data['companyLogo']?.toString();
      _role = _parseRole(data['role']?.toString());
      _rawRoleName = data['rawRoleName']?.toString() ?? _enumToDisplay(_role);
      final rawProj = data['projectIds'];
      if (rawProj is List) {
        _projectIds = rawProj.map((e) => e.toString()).toList();
      } else {
        final legacyId = data['projectId']?.toString() ?? '';
        _projectIds = legacyId.isNotEmpty ? [legacyId] : [];
      }
      final rawPerms = data['permissions'];
      if (rawPerms is List) {
        _permissions = rawPerms.map((e) => e.toString()).toList();
      } else {
        _permissions = [];
      }
      final rawOversees = data['overseesRoles'];
      if (rawOversees is List) {
        _overseesRoles = rawOversees.map((e) => e.toString()).toList();
      } else {
        _overseesRoles = [];
      }
      _initialized = true;
      _instance.notifyListeners();
      debugPrint(
        '[UserSession] loadFromPrefs → '
        'role=$roleLabel (_raw=$_rawRoleName) company=$_companyName font=$_companyFontStyle projectIds=$_projectIds',
      );
    } catch (e) {
      debugPrint('[UserSession] loadFromPrefs error: $e');
      _initialized = true;
      _instance.notifyListeners();
    }
  }
  static Future<void> clear() async {
    _userId = '';
    _role = UserRole.mason;
    _rawRoleName = '';
    _companyName = '';
    _companyFontStyle = 'Inter';
    _companyLogo = null;
    _projectIds = [];
    _overseesRoles = [];
    _permissions = [];
    _profilePhoto = null;
    _initialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
    _instance.notifyListeners();
    debugPrint('[UserSession] cleared');
  }
  static void set({
    required String userId,
    required UserRole role,
    List<String> projectIds = const [],
    List<String> overseesRoles = const [],
    String projectId = '',
    List<String> permissions = const [],
    String rawRoleName = '',
    String? profilePhoto,
    String companyName = '',
    String companyFontStyle = 'Inter',
    String? companyLogo,
  }) {
    _userId = userId;
    _role = role;
    _rawRoleName = rawRoleName.isNotEmpty ? rawRoleName : _enumToDisplay(role);
    _profilePhoto = profilePhoto;
    _companyName = companyName;
    _companyFontStyle = companyFontStyle;
    _companyLogo = companyLogo;
    final merged = List<String>.from(projectIds);
    if (projectId.isNotEmpty && !merged.contains(projectId)) {
      merged.insert(0, projectId);
    }
    _projectIds = merged;
    _overseesRoles = List<String>.from(overseesRoles);
    _permissions = List<String>.from(permissions);
    _initialized = true;
    _instance.notifyListeners();
  }
  static String _toDisplayName(String? roleStr) {
    if (roleStr == null || roleStr.trim().isEmpty) return 'Worker';
    final trimmed = roleStr.trim();
    switch (trimmed.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'supervisor':
        return 'Supervisor';
      case 'mason':
        return 'Mason';
      case 'worker':
        return 'Worker';
      default:
        return trimmed[0].toUpperCase() + trimmed.substring(1);
    }
  }
  static String _enumToDisplay(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.mason:
        return 'Mason';
    }
  }
  static UserRole _parseRole(String? roleStr) {
    switch (roleStr?.toLowerCase().trim()) {
      case 'admin':
        return UserRole.admin;
      case 'supervisor':
        return UserRole.supervisor;
      case 'mason':
      case 'worker':
        return UserRole.mason;
      default:
        debugPrint(
          '[UserSession] _parseRole: unknown role "$roleStr" '
          '→ defaulting to UserRole.mason',
        );
        return UserRole.mason;
    }
  }
  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kSessionKey,
        json.encode({
          'id': _userId,
          'role': roleLabel,
          'rawRoleName': _rawRoleName,
          'companyName': _companyName,
          'companyFontStyle': _companyFontStyle,
          'companyLogo': _companyLogo,
          'projectIds': _projectIds,
          'projectId': projectId,
          'permissions': _permissions,
          'overseesRoles': _overseesRoles,
          'profilePhoto': _profilePhoto,
        }),
      );
    } catch (e) {
      debugPrint('[UserSession] _persist error: $e');
    }
  }
  static void simulateAdmin() => set(
    userId: 'sim_admin',
    role: UserRole.admin,
    projectIds: ['proj_001'],
    rawRoleName: 'Admin',
  );
  static void simulateSupervisor() => set(
    userId: 'sim_sup',
    role: UserRole.supervisor,
    projectIds: ['proj_001', 'proj_002'],
    rawRoleName: 'Supervisor',
    permissions: const [
      'view_assigned_project',
      'submit_daily_update',
      'upload_photos',
      'upload_videos',
      'submit_checklist',
      'report_issue',
      'report_delay',
      'approve_updates',
      'reject_updates',
      'add_supervisor_remarks',
      'view_progress_dashboard',
      'view_issue_tracker',
      'view_delay_tracker',
      'view_media_gallery',
      'view_reports',
      'view_projects',
      'add_entries',
      'approve_payments',
      'mark_paid',
    ],
  );
  static void simulateMason() => set(
    userId: 'sim_mason',
    role: UserRole.mason,
    projectIds: ['proj_001'],
    rawRoleName: 'Mason',
    permissions: const [
      'view_assigned_project',
      'submit_daily_update',
      'upload_photos',
      'upload_videos',
      'submit_checklist',
      'report_issue',
      'report_delay',
      'view_projects',
      'add_entries',
    ],
  );
  static void simulateContractor() => set(
    userId: 'sim_contractor',
    role: UserRole.mason,
    projectIds: ['proj_001'],
    rawRoleName: 'Contractor',
    permissions: const [
      'view_assigned_project',
      'submit_daily_update',
      'upload_photos',
    ],
  );
}
