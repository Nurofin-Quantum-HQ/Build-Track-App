import 'package:flutter/material.dart';

class ShowcaseKeys {
  static final GlobalKey createProject = GlobalKey();
  static final GlobalKey addEntry = GlobalKey();
  static final GlobalKey reports = GlobalKey();
  static final GlobalKey projects = GlobalKey();
  static final GlobalKey sidebarMenu = GlobalKey();
  static final GlobalKey helpButton = GlobalKey();
  static final GlobalKey voiceAI = GlobalKey();
  static final GlobalKey progress = GlobalKey();
  static final GlobalKey recentEntries = GlobalKey();
  static final GlobalKey inventoryAdd = GlobalKey();
  static final GlobalKey inventoryFilters = GlobalKey();
  static final GlobalKey reportMain = GlobalKey();
  static final GlobalKey roleMain = GlobalKey();
  static final GlobalKey inventoryTab = GlobalKey();
  static final GlobalKey profileIcon = GlobalKey();
  
  // Dashboard expanded
  static final GlobalKey quickAddEntry = GlobalKey();
  
  // Add Entry Screen
  static final GlobalKey addEntryManualTab = GlobalKey();
  static final GlobalKey addEntryVoiceTab = GlobalKey();
  static final GlobalKey addEntrySubmit = GlobalKey();
  
  // Projects Screen
  static final GlobalKey projectsAssignRoleBtn = GlobalKey();
  static final GlobalKey projectsCard = GlobalKey();
  
  // Reports Screen
  static final GlobalKey reportAskAI = GlobalKey();
  static final GlobalKey reportFilters = GlobalKey();
  static final GlobalKey reportDetailsList = GlobalKey();
  static final GlobalKey reportCSV = GlobalKey();
  
  // Assign Roles Screen
  static final GlobalKey assignRoleProjectDropdown = GlobalKey();
  static final GlobalKey assignRoleRoleDropdown = GlobalKey();
  static final GlobalKey assignRoleSubmit = GlobalKey();
  static final GlobalKey assignRoleList = GlobalKey();
  static final GlobalKey assignRoleUserDetails = GlobalKey();
  static final GlobalKey assignRolePermissions = GlobalKey();
  
  // Inventory Screen
  static final GlobalKey inventoryProjectContext = GlobalKey();
  static final GlobalKey inventoryMaterials = GlobalKey();
  static final GlobalKey inventoryTools = GlobalKey();
  static final GlobalKey inventoryStats = GlobalKey();
  
  // Profile Screen
  static final GlobalKey profileFields = GlobalKey();
  static final GlobalKey profileSubscription = GlobalKey();

  // Dashboard Financial Metrics
  static final GlobalKey dashboardTotalCost = GlobalKey();
  static final GlobalKey dashboardTotalRevenue = GlobalKey();
  static final GlobalKey dashboardNetCashFlow = GlobalKey();

  // Add Entry specific modes
  static final GlobalKey addEntryMaterial = GlobalKey();
  static final GlobalKey addEntryLabour = GlobalKey();
  static final GlobalKey addEntryEquipment = GlobalKey();
  static final GlobalKey addEntryCSV = GlobalKey();

  // Homescreen Budget
  static final GlobalKey dashboardTotalBudget = GlobalKey();

  // Reports Dropdowns
  static final GlobalKey reportProjectDropdown = GlobalKey();
  static final GlobalKey reportPhaseDropdown = GlobalKey();
  static final GlobalKey reportActivityDropdown = GlobalKey();
}
