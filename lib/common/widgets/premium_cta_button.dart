import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_gradients.dart';
import 'package:flutter/material.dart';

enum CtaVariant { primary, secondary, outline }

class PremiumCtaButton extends StatelessWidget {
  const PremiumCtaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isFullWidth = false,
    this.isLoading = false,
    this.variant = CtaVariant.primary,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isFullWidth;
  final bool isLoading;
  final CtaVariant variant;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == CtaVariant.primary;
    final isSecondary = variant == CtaVariant.secondary;

    BoxDecoration decoration;
    Color textColor;
    Color spinnerColor;

    if (isPrimary) {
      decoration = BoxDecoration(
        gradient: AppGradients.primaryButton,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      );
      textColor = Colors.white;
      spinnerColor = Colors.white;
    } else if (isSecondary) {
      decoration = BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
      );
      textColor = Colors.white;
      spinnerColor = Colors.white;
    } else {
      decoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0D5DD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      );
      textColor = const Color(0xFF344054);
      spinnerColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: decoration,
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: spinnerColor,
                  ),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: textColor, size: 18),
                        const SizedBox(width: 7),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
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
