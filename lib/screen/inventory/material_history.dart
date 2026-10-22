import 'package:buildtrack_mobile/design/design.dart';
import 'package:flutter/material.dart';
class CementHistoryScreen extends StatefulWidget {
  const CementHistoryScreen({super.key});
  @override
  State<CementHistoryScreen> createState() => _CementHistoryScreenState();
}
class _CementHistoryScreenState extends State<CementHistoryScreen> {
  // Blueprint Noir palette (the screen's demo content below is unchanged).
  static const primaryBlue = Bt.ink;
  static const purple = Bt.ink2;
  static const bgColor = Bt.ground;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: BtNavBar(title: 'Entry details', onBack: () => Navigator.maybePop(context)),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
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
                      iconBg: const Color(0xFFE8F1FC),
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
                      iconBg: const Color(0xFFE8F1FC),
                      iconColor: purple,
                      name: 'Portland Type II',
                      subtitle: 'Slab Pouring - Block B • #INV-9884',
                      qty: '-120',
                      date: 'OCT 22,\n2023',
                      isPositive: false,
                      accent: const Color(0xFF0B63CE),
                    ),
                    const SizedBox(height: 12),
                    _movementItem(
                      icon: Icons.architecture,
                      iconBg: const Color(0xFFE8F1FC),
                      iconColor: purple,
                      name: 'Quick-Set Specialty',
                      subtitle: 'Column Reinforcement • #INV-9851',
                      qty: '-45',
                      date: 'OCT 20,\n2023',
                      isPositive: false,
                      accent: const Color(0xFF0B63CE),
                    ),
                    const SizedBox(height: 12),
                    _movementItem(
                      icon: Icons.local_shipping_outlined,
                      iconBg: const Color(0xFFE8F1FC),
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
                      iconBg: const Color(0xFFE8F1FC),
                      iconColor: purple,
                      name: 'Portland Type II',
                      subtitle: 'Foundation Work • #INV-9799',
                      qty: '-85',
                      date: 'OCT 15,\n2023',
                      isPositive: false,
                      accent: const Color(0xFF0B63CE),
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
    return BtReveal(
      child: BtCard(
        variant: BtCardVariant.ink,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TOTAL CURRENT STOCK', style: BtText.mono(context, color: context.bt.accent)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('1,248', style: BtText.d0(context, color: Bt.bone)),
                const SizedBox(width: 8),
                Text('Units', style: BtText.body(context, color: Bt.onNoir2)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _stockBadge(Icons.category_outlined, 'GRADE A-500'),
                const SizedBox(width: 22),
                _stockBadge(Icons.home_work_outlined, 'SECTOR 04'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _stockBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Bt.onNoir2, size: 16),
        const SizedBox(width: 6),
        Text(label, style: BtText.mono(context, color: Bt.onNoir2)),
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
            Text('MOVEMENT LOGS', style: BtText.mono(context)),
            const SizedBox(height: 4),
            Text('Tracking historical distribution', style: BtText.title(context, size: 18)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Bt.card,
            borderRadius: BorderRadius.circular(Bt.rChip),
            border: Border.all(color: Bt.inputBorder),
          ),
          child: Row(
            children: [
              Text('Filter', style: BtText.caption(context, color: Bt.ink, weight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Icon(Icons.tune, color: Bt.ink, size: 16),
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
    return BtCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          BtTile(icon: icon, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: BtText.headline(context)),
                const SizedBox(height: 2),
                Text(subtitle, style: BtText.caption(context)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(qty, style: BtText.num(BtText.title(context, size: 19).copyWith(color: isPositive ? Bt.green : Bt.red))),
              const SizedBox(height: 2),
              Text(date, textAlign: TextAlign.right, style: BtText.caption(context).copyWith(fontSize: 12, height: 1.3)),
            ],
          ),
        ],
      ),
    );
  }
}
