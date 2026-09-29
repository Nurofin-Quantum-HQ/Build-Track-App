import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:flutter/material.dart';
class _EntryType {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String route;
  const _EntryType({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.route,
  });
}
const _entryTypes = [
  _EntryType(
    id: 'material',
    title: 'Material',
    subtitle: 'Log concrete, steel, timber or any raw material used on site.',
    icon: Icons.inventory_2_outlined,
    iconColor: AppColors.primaryBlue,
    iconBg: Color(0xFFEEF0FF),
    route: '/add-material',
  ),
  _EntryType(
    id: 'labour',
    title: 'Labour',
    subtitle: 'Record worker hours, headcount and wages for the shift.',
    icon: Icons.people_outline,
    iconColor: Color(0xFF2E7D32),
    iconBg: Color(0xFFE8F5E9),
    route: '/add-labour',
  ),
  _EntryType(
    id: 'equipment',
    title: 'Equipment',
    subtitle: 'Track machinery usage, fuel consumption and operating costs.',
    icon: Icons.construction_outlined,
    iconColor: Color(0xFFE65100),
    iconBg: Color(0xFFFFF3E0),
    route: '/add-equipment',
  ),
];
void showAddEntryPopup(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AddEntrySheet(parentContext: context),
  );
}
class _AddEntrySheet extends StatefulWidget {
  final BuildContext parentContext;
  const _AddEntrySheet({required this.parentContext});
  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}
class _AddEntrySheetState extends State<_AddEntrySheet> {
  static const textDark = AppColors.textDark;
  static const textGray = AppColors.textLight;
  String? _selectedId;
  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE0F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'What are you adding?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select the entry type to log for the current shift.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: textGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ..._entryTypes.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EntryCard(
                    type: type,
                    isSelected: _selectedId == type.id,
                    onTap: () {
                      setState(() => _selectedId = type.id);
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (!mounted) return;
                        Navigator.pop(context);
                        Navigator.pushNamed(widget.parentContext, type.route);
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _EntryCard extends StatelessWidget {
  final _EntryType type;
  final bool isSelected;
  final VoidCallback onTap;
  const _EntryCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });
  static primaryBlue = AppColors.primary;
  static const textDark = AppColors.textDark;
  static const textGray = AppColors.textLight;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F2FF) : const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? primaryBlue : const Color(0xFFE0E5FF),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryBlue.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? type.iconColor.withValues(alpha: 0.18)
                        : type.iconBg,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(type.icon, color: type.iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        type.subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: textGray,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSelected
                      ? Container(
                          key: const ValueKey('check'),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        )
                      : const Icon(
                          key: ValueKey('chevron'),
                          Icons.chevron_right,
                          color: textGray,
                          size: 22,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
