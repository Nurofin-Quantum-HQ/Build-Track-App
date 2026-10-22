import 'package:buildtrack_mobile/controller/user_session.dart';
class RoleManager {
  RoleManager._();
  static bool get isAdmin => UserSession.isAdmin;
  static bool get isSupervisor => UserSession.isSupervisor;
  static bool get isMason => UserSession.isMason;
  static bool get canCreateProject =>
      isAdmin || UserSession.hasPermission('create_project');
  static bool get canEditProject =>
      isAdmin || UserSession.hasPermission('edit_project');
  static bool get canDeleteProject =>
      isAdmin || UserSession.hasPermission('delete_project');
  static bool get canViewAllProjects =>
      isAdmin || UserSession.hasPermission('view_all_projects');
  static bool get canViewAssignedProject =>
      UserSession.hasPermission('view_assigned_project') ||
      UserSession.hasPermission('view_projects');
  static bool get canViewProjects =>
      isAdmin || canViewAllProjects || canViewAssignedProject;
  static bool get canManageBuildingType =>
      isAdmin || UserSession.hasPermission('manage_building_type');
  static bool get canManageFloors =>
      isAdmin || UserSession.hasPermission('manage_floors');
  static bool get canManagePhases =>
      isAdmin || UserSession.hasPermission('manage_phases');
  static bool get canManageActivities =>
      isAdmin || UserSession.hasPermission('manage_activities');
  static bool get canManageChecklists =>
      isAdmin || UserSession.hasPermission('manage_checklists');
  static bool get canManageContractors =>
      isAdmin || UserSession.hasPermission('manage_contractors');
  static bool get canManageUsers =>
      isAdmin || UserSession.hasPermission('manage_users');
  static bool get canAssignRoles =>
      isAdmin || UserSession.hasPermission('assign_roles');
  static bool get canAssignProject =>
      isAdmin || UserSession.hasPermission('assign_project');
  static bool get canAssignTasks =>
      isAdmin || isSupervisor || UserSession.hasPermission('assign_tasks');
  static bool get canAssignRole => canAssignRoles;
  static bool get canManageTeam =>
      isAdmin || UserSession.hasPermission('manage_team');
  static bool get canSubmitDailyUpdate =>
      UserSession.hasPermission('submit_daily_update') ||
      UserSession.hasPermission('add_entries');
  static bool get canUploadPhotos =>
      UserSession.hasPermission('upload_photos') ||
      UserSession.hasPermission('add_entries');
  static bool get canUploadVideos => UserSession.hasPermission('upload_videos');
  static bool get canSubmitChecklist =>
      UserSession.hasPermission('submit_checklist') ||
      UserSession.hasPermission('add_entries');
  static bool get canReportIssue =>
      UserSession.hasPermission('report_issue') ||
      UserSession.hasPermission('add_entries');
  static bool get canReportDelay =>
      UserSession.hasPermission('report_delay') ||
      UserSession.hasPermission('add_entries');
  static bool get canAddEntries =>
      isAdmin ||
      canSubmitDailyUpdate ||
      UserSession.hasPermission('add_entries');
  static bool get canApproveUpdates =>
      isAdmin ||
      UserSession.hasPermission('approve_updates') ||
      UserSession.hasPermission('approve_payments');
  static bool get canRejectUpdates =>
      isAdmin ||
      UserSession.hasPermission('reject_updates') ||
      UserSession.hasPermission('approve_payments');
  static bool get canAddSupervisorRemarks =>
      isAdmin || UserSession.hasPermission('add_supervisor_remarks');
  static bool get canApprovePayments =>
      isAdmin ||
      UserSession.hasPermission('approve_payments') ||
      canApproveUpdates;
  static bool get canViewProgressDashboard =>
      isAdmin ||
      UserSession.hasPermission('view_progress_dashboard') ||
      UserSession.hasPermission('view_projects');
  static bool get canViewIssueTracker =>
      isAdmin || UserSession.hasPermission('view_issue_tracker');
  static bool get canViewDelayTracker =>
      isAdmin || UserSession.hasPermission('view_delay_tracker');
  static bool get canViewMediaGallery =>
      isAdmin || UserSession.hasPermission('view_media_gallery');
  /// Budget figures (project budget, budget used/left). Admins always; others
  /// only when granted "Project budget" in Assign Role (permission key below).
  static const viewProjectBudgetKey = 'view_project_budget';
  static bool get canViewProjectBudget =>
      isAdmin || UserSession.hasPermission(viewProjectBudgetKey);
  static bool get canViewReports =>
      isAdmin || UserSession.hasPermission('view_reports');
  static bool get canManageExpenses =>
      isAdmin || UserSession.hasPermission('manage_expenses');
  static bool get canMarkPaid =>
      isAdmin || UserSession.hasPermission('mark_paid');
  static bool get canViewPaymentReports =>
      isAdmin ||
      UserSession.hasPermission('view_payment_reports') ||
      UserSession.hasPermission('view_reports');
  static bool get canUploadDocuments =>
      isAdmin || UserSession.hasPermission('upload_documents');
  static bool get canViewDocuments =>
      isAdmin || UserSession.hasPermission('view_documents');
  static bool get canManageMaterialMaster =>
      isAdmin || UserSession.hasPermission('manage_material_master');
  static bool get canManageLabourMaster =>
      isAdmin || UserSession.hasPermission('manage_labour_master');
  static bool get canManageEquipmentMaster =>
      isAdmin || UserSession.hasPermission('manage_equipment_master');
  static bool get canManageInventory =>
      isAdmin ||
      canManageMaterialMaster ||
      canManageLabourMaster ||
      canManageEquipmentMaster;
  static bool get canViewContractorPerformance =>
      isAdmin || UserSession.hasPermission('view_contractor_performance');
  static bool get canViewNotifications => true;
  static bool get canEditProfile => true;
  static bool get canDeleteEntries => isAdmin || canApprovePayments;
  static bool get canApproveEntries => isAdmin || canApprovePayments;
  static bool get canUpdateProgress => canAddEntries;
  static bool get canViewTeamAccess => isAdmin;
  static const _restrictedRoutes = <String, bool Function()>{
    '/assign-role': _checkAssignRole,
    '/reports': _checkReports,
    '/create-workspace': _checkAdmin,
    '/logs': _checkLogs,
  };
  static bool _checkAssignRole() => canAssignRoles;
  static bool _checkReports() => canViewReports;
  static bool _checkAdmin() => isAdmin;
  static bool _checkLogs() => isAdmin || canViewReports;
  static bool canNavigate(String route) {
    final check = _restrictedRoutes[route];
    if (check == null) return true;
    return check();
  }
}
