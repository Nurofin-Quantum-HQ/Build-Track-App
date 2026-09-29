import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
class CementHistoryScreen extends StatefulWidget {
  const CementHistoryScreen({super.key});
  @override
  State<CementHistoryScreen> createState() => _CementHistoryScreenState();
}
class _CementHistoryScreenState extends State<CementHistoryScreen> {
  static var primaryBlue = AppColors.primary;
  static var purple = AppColors.primary;
  static const bgColor = AppColors.gradientStart;
  static const textDark = AppColors.textDark;
  static const textGray = AppColors.textLight;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: 'Entry details',
              isSubScreen: true,
              leftIcon: Icons.arrow_back,
              onLeftTap: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStockCard(),
                    const SizedBox(height: 22),
                    _buildMovementHeader(),
                    const SizedBox(height: 14),
                    _movementItem(
                      icon: Icons.local_shipping_outlined,
                      iconBg: const Color(0xFFEEF0FF),
                      iconColor: primaryBlue,
                      name: 'Portland Type II',
                      subtitle: 'Stock Replenishment • #INV-9921',
                      qty: '+450',
                      date: 'OCT 24,\n2023',
                      isPositive: true,
                      accent: primaryBlue,
                    ),
                    const SizedBox(height: 12),
                    _movementItem(
                      icon: Icons.home_work_outlined,
                      iconBg: const Color(0xFFF0EEFF),
                      iconColor: purple,
                      name: 'Portland Type II',
                      subtitle: 'Slab Pouring - Block B • #INV-9884',
                      qty: '-120',
                      date: 'OCT 22,\n2023',
                      isPositive: false,
                      accent: const Color(0xFFE040FB),
                    ),
                    const SizedBox(height: 12),
                    _movementItem(
                      icon: Icons.architecture,
                      iconBg: const Color(0xFFF0EEFF),
                      iconColor: purple,
                      name: 'Quick-Set Specialty',
                      subtitle: 'Column Reinforcement • #INV-9851',
                      qty: '-45',
                      date: 'OCT 20,\n2023',
                      isPositive: false,
                      accent: const Color(0xFFE040FB),
                    ),
                    const SizedBox(height: 12),
                    _movementItem(
                      icon: Icons.local_shipping_outlined,
                      iconBg: const Color(0xFFEEF0FF),
                      iconColor: primaryBlue,
                      name: 'Portland Type II',
                      subtitle: 'Stock Replenishment • #INV-9820',
                      qty: '+200',
                      date: 'OCT 18,\n2023',
                      isPositive: true,
                      accent: primaryBlue,
                    ),
                    const SizedBox(height: 12),
                    _movementItem(
                      icon: Icons.construction_outlined,
                      iconBg: const Color(0xFFF0EEFF),
                      iconColor: purple,
                      name: 'Portland Type II',
                      subtitle: 'Foundation Work • #INV-9799',
                      qty: '-85',
                      date: 'OCT 15,\n2023',
                      isPositive: false,
                      accent: const Color(0xFFE040FB),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildStockCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEEFFF), Color(0xFFF5F0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCDD0FF), width: 2),
      ),
      child: Column(
        children: [
          Text(
            'TOTAL CURRENT STOCK',
            style: TextStyle(
              fontSize: 12,
              color: textGray,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '1,248',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryPurple,
                    letterSpacing: -2,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: '  Units',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textGray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stockBadge(Icons.category_outlined, 'GRADE A-500'),
              const SizedBox(width: 30),
              _stockBadge(Icons.home_work_outlined, 'SECTOR 04'),
            ],
          ),
        ],
      ),
    );
  }
  Widget _stockBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: purple, size: 18),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: purple,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
  Widget _buildMovementHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Movement Logs',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: textDark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Tracking historical distribution',
              style: TextStyle(color: textGray, fontSize: 12.5),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDDE0F0)),
          ),
          child: Row(
            children: [
              Text(
                'Filter',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.tune, color: primaryBlue, size: 16),
            ],
          ),
        ),
      ],
    );
  }
  Widget _movementItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String name,
    required String subtitle,
    required String qty,
    required String date,
    required bool isPositive,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 3.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: textGray, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                qty,
                style: TextStyle(
                  color: isPositive ? primaryBlue : const Color(0xFFE040FB),
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                textAlign: TextAlign.right,
                style: TextStyle(color: textGray, fontSize: 10, height: 1.3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
