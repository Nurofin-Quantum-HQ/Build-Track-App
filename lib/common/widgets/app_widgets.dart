import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/design/design.dart';
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacingMd),
    this.margin = const EdgeInsets.only(bottom: AppTheme.spacingMd),
    this.color,
    this.borderRadius = AppTheme.radiusLg,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final double borderRadius;  
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius < 22 ? 22 : borderRadius),
        boxShadow: Bt.shadow,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return BtPressable(onTap: onTap, scale: .98, child: card);
  }
}
enum AppButtonVariant { primary, secondary, outline, danger }
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _resolveColors();
    final isPrimary = variant == AppButtonVariant.primary;
    return SizedBox(
      width: double.infinity,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isPrimary
                ? Bt.ink
                : (variant == AppButtonVariant.outline
                      ? Colors.white
                      : bg),
            borderRadius: BorderRadius.circular(Bt.rButton),
            border: variant == AppButtonVariant.outline
                ? Border.all(color: AppColors.cardBorder, width: 1)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Bt.rButton),
            child: InkWell(
              borderRadius: BorderRadius.circular(Bt.rButton),
              onTap: (enabled && !isLoading) ? onPressed : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: fg,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: fg, size: 18),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              label,
                              style: BtText.button(context, color: fg),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  (Color bg, Color fg, Color border) _resolveColors() {
    switch (variant) {
      case AppButtonVariant.primary:
        return (Bt.ink, Bt.bone, Bt.ink);
      case AppButtonVariant.secondary:
        return (Bt.ink, Bt.bone, Bt.ink);
      case AppButtonVariant.outline:
        return (Colors.white, AppTheme.textDark, AppColors.cardBorder);
      case AppButtonVariant.danger:
        return (
          Colors.white,
          AppTheme.error,
          AppColors.cardBorder,
        );
    }
  }
}
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final bool obscureText;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.label.copyWith(color: AppTheme.textMedium)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          validator: validator,
          enabled: enabled,
          style: AppTheme.bodyLarge.copyWith(color: AppTheme.textDark),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppTheme.textLight, size: 20)
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? AppTheme.surface : AppTheme.background,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
      ],
    );
  }
}
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.label.copyWith(color: AppTheme.textMedium)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.divider, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: hint != null
                  ? Text(
                      hint!,
                      style: AppTheme.body.copyWith(color: AppTheme.textLight),
                    )
                  : null,
              items: items,
              onChanged: onChanged,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textDark),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppTheme.textLight,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
      ],
    );
  }
}
enum AppStatus { completed, inProgress, notStarted, delayed, issue }
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({super.key, required this.status});
  final AppStatus status;
  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _resolve();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
  (String label, Color bg, Color fg) _resolve() {
    switch (status) {
      case AppStatus.completed:
        return (
          'Completed',
          AppColors.badgeSuccessBg,
          AppColors.badgeSuccessText,
        );
      case AppStatus.inProgress:
        return (
          'In Progress',
          AppColors.badgeWarningBg,
          AppColors.badgeWarningText,
        );
      case AppStatus.notStarted:
        return ('Not Started', AppColors.badgeInfoBg, AppColors.badgeInfoText);
      case AppStatus.delayed:
        return ('Delayed', const Color(0xFFFDECEF), AppTheme.error);
      case AppStatus.issue:
        return ('Issue', AppColors.badgePendingBg, AppColors.badgePendingText);
    }
  }
}
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTheme.heading3),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: AppTheme.body.copyWith(
                  color: Bt.ink2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
class AppDivider extends StatelessWidget {
  AppDivider({super.key, this.verticalPadding = AppTheme.spacingMd});
  final double verticalPadding;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Divider(color: AppTheme.divider, thickness: 1),
    );
  }
}
class AppProgressBar extends StatelessWidget {
  AppProgressBar({
    super.key,
    required this.label,
    required this.percent,
    this.color,
  });
  final String label;
  final double percent;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.body),
            Text(
              '${(percent * 100).round()}%',
              style: AppTheme.body.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 6,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Bt.fill,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color ?? context.bt.accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: context.bt.accentSoft, borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, size: 28, color: context.bt.accentInk),
            ),
            const SizedBox(height: 14),
            Text(message, style: AppTheme.heading3.copyWith(fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: AppTheme.spacingMd),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final String status;
  Color get _color {
    switch (status) {
      case 'approved':
        return AppColors.badgeSuccessText;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.badgeWarningText;
    }
  }
  Color get _bg {
    switch (status) {
      case 'approved':
        return AppColors.badgeSuccessBg;
      case 'rejected':
        return const Color(0xFFFDECEF);
      default:
        return AppColors.badgeWarningBg;
    }
  }
  IconData get _icon {
    switch (status) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty_outlined;
    }
  }
  String get _label {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: 12),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
