import 'package:buildtrack_mobile/controller/entry_model.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
class EntryPermissions {
  EntryPermissions._();
  static bool canEdit({
    required String status,
    required String createdBy,
    required String projectId,
  }) {
    if (status == 'approved') return false;
    if (UserSession.isAdmin) return true;
    if (UserSession.isSupervisor) {
      return UserSession.hasProjectAccess(projectId);
    }
    if (UserSession.isMason) {
      return createdBy == UserSession.userId;
    }
    return false;
  }
  static bool canDelete({
    required String status,
    required String createdBy,
    required String projectId,
  }) {
    return canEdit(status: status, createdBy: createdBy, projectId: projectId);
  }
  static bool canApprove() {
    return RoleManager.canApproveEntries;
  }
  static bool canView({required String createdBy, required String projectId}) {
    if (UserSession.isAdmin) return true;
    if (UserSession.isSupervisor) {
      return UserSession.hasProjectAccess(projectId);
    }
    if (UserSession.isMason) {
      return createdBy == UserSession.userId || UserSession.hasProjectAccess(projectId);
    }
    return UserSession.hasProjectAccess(projectId);
  }
  static List<Entry> filterEntries(List<Entry> entries) {
    if (UserSession.isAdmin) return entries;
    return entries
        .where((e) => canView(createdBy: e.createdBy, projectId: e.projectId))
        .toList();
  }
  static List<Map<String, dynamic>> filterMaps(
    List<Map<String, dynamic>> entries,
  ) {
    if (UserSession.isAdmin) return entries;
    return entries
        .where(
          (e) => canView(
            createdBy: e['createdBy'] as String? ?? '',
            projectId: e['projectId'] as String? ?? '',
          ),
        )
        .toList();
  }
}
