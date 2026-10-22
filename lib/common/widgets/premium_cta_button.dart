import 'package:buildtrack_mobile/design/design.dart';
import 'package:flutter/material.dart';

enum CtaVariant { primary, secondary, outline }

/// Legacy CTA kept for API compatibility — now drawn in the V2 style:
/// primary = accent fill, secondary = glass (for noir surfaces), outline = white.
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
    final bt = context.bt;
    final isPrimary = variant == CtaVariant.primary;
    final isSecondary = variant == CtaVariant.secondary;

    BoxDecoration decoration;
    Color textColor;

    if (isPrimary) {
      decoration = BoxDecoration(
        color: bt.accent,
        borderRadius: BorderRadius.circular(Bt.rButton),
        boxShadow: [BoxShadow(color: bt.accent.withValues(alpha: .45), blurRadius: 26, spreadRadius: -12, offset: const Offset(0, 10))],
      );
      textColor = bt.onAccent;
    } else if (isSecondary) {
      decoration = BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(Bt.rButton),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      );
      textColor = Bt.bone;
    } else {
      decoration = BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.circular(Bt.rButton),
        border: Border.all(color: Bt.inputBorder),
      );
      textColor = Bt.ink;
    }

    return Semantics(
      button: true,
      enabled: onTap != null && !isLoading,
      child: BtPressable(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: isFullWidth ? double.infinity : null,
          height: Bt.buttonH,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: decoration,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: textColor),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: textColor, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(label, style: BtText.button(context, color: textColor)),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
