import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'bt_theme.dart';
import 'bt_text.dart';

// ─────────────────────────────────────────────────────────────── nav bars

/// Large title header for tab roots (DESIGN.md §6 BtNavBar large).
class BtLargeHeader extends StatelessWidget {
  const BtLargeHeader({super.key, required this.title, this.caption, this.trailing, this.onCaptionTap});
  final String title;
  final String? caption;
  final VoidCallback? onCaptionTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Large titles sit below a 44pt nav row on iOS; keep that air even where there's no status bar (web).
      padding: const EdgeInsets.fromLTRB(Bt.gutter, 24, Bt.gutter, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (caption != null)
                  InkWell(
                    onTap: onCaptionTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(child: Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.subhead(context))),
                        if (onCaptionTap != null) const Icon(Icons.expand_more_rounded, size: 18, color: Bt.ink2),
                      ]),
                    ),
                  ),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.largeTitle(context)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Inline header for pushed screens: back · centred title · trailing.
class BtNavBar extends StatelessWidget implements PreferredSizeWidget {
  const BtNavBar({super.key, required this.title, this.subtitle, this.trailing, this.onBack, this.close = false, this.showBack = true});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool close;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      minimum: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 56,
        child: Row(children: [
          const SizedBox(width: 4),
          if (showBack)
            BtIconButton(
              icon: close ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
              size: close ? 24 : 20,
              semantic: close ? 'Close' : 'Back',
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: Bt.touch),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: BtText.navTitle(context)),
              if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
            ]),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: Bt.touch),
            child: trailing == null ? const SizedBox(width: Bt.touch) : Center(child: trailing),
          ),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}

class BtIconButton extends StatelessWidget {
  const BtIconButton({super.key, required this.icon, required this.onTap, this.semantic, this.size = 22, this.color = Bt.ink, this.filled = false, this.badge});
  final IconData icon;
  final VoidCallback? onTap;
  final String? semantic;
  final double size;
  final Color color;
  final bool filled;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantic,
      child: Material(
        color: filled ? Bt.card : Colors.transparent,
        shape: CircleBorder(side: filled ? const BorderSide(color: Bt.line) : BorderSide.none),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: Bt.touch,
            height: Bt.touch,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              Icon(icon, size: size, color: color),
              if (badge != null && badge! > 0) Positioned(top: 4, right: 4, child: BtCountBadge(count: badge!)),
            ]),
          ),
        ),
      ),
    );
  }
}

class BtCountBadge extends StatelessWidget {
  const BtCountBadge({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(color: Bt.red, borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white, width: 2)),
      alignment: Alignment.center,
      child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1)),
    );
  }
}

// ─────────────────────────────────────────────────────────────── surfaces

enum BtCardVariant { plain, attention, notice, danger }

class BtCard extends StatelessWidget {
  const BtCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.variant = BtCardVariant.plain, this.margin});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BtCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    Color bg = Bt.card;
    BorderSide side = const BorderSide(color: Bt.line);
    switch (variant) {
      case BtCardVariant.attention:
        side = BorderSide(color: bt.brand, width: 1.5);
        break;
      case BtCardVariant.notice:
        bg = Bt.amberSoft;
        side = BorderSide.none;
        break;
      case BtCardVariant.danger:
        bg = Bt.redSoft;
        side = BorderSide.none;
        break;
      case BtCardVariant.plain:
        break;
    }
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rCard), side: side),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Grouped list container (iOS-Settings style).
class BtGroup extends StatelessWidget {
  const BtGroup({super.key, required this.children, this.insetDividers = true, this.margin});
  final List<Widget> children;
  final bool insetDividers;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, thickness: 1, color: Bt.line, indent: insetDividers ? 68 : 16));
      items.add(children[i]);
    }
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Bt.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rCard), side: const BorderSide(color: Bt.line)),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}

/// The workhorse list row.
class BtRow extends StatelessWidget {
  const BtRow({super.key, this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.showChevron = false, this.titleColor, this.subtitleColor, this.minHeight = 56, this.subtitleMaxLines = 1, this.titleWeight = FontWeight.w500});
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? titleColor;
  final Color? subtitleColor;
  final double minHeight;
  final int subtitleMaxLines;
  final FontWeight titleWeight;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: titleWeight, color: titleColor ?? Bt.ink)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, maxLines: subtitleMaxLines, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: subtitleColor ?? Bt.ink3)),
                  ),
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (showChevron) ...[const SizedBox(width: 4), const Icon(Icons.chevron_right_rounded, color: Bt.placeholder, size: 22)],
          ]),
        ),
      ),
    );
  }
}

/// Label / value row for detail lists.
class BtValueRow extends StatelessWidget {
  const BtValueRow({super.key, required this.label, required this.value, this.onTap, this.valueColor, this.trailing});
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? valueColor;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Text(label, style: BtText.subhead(context)),
            const SizedBox(width: 16),
            Expanded(child: Text(value, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w500, color: valueColor ?? (onTap != null ? context.bt.brand : Bt.ink)))),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ]),
        ),
      ),
    );
  }
}

class BtTile extends StatelessWidget {
  const BtTile({super.key, required this.icon, this.bg, this.fg, this.size = 40});
  final IconData icon;
  final Color? bg;
  final Color? fg;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? Bt.fill, borderRadius: BorderRadius.circular(Bt.rTile)),
      child: Icon(icon, size: size * .55, color: fg ?? Bt.ink),
    );
  }
}

/// Entry-type icon tile: material / labour / equipment (fixed icons, DESIGN §6).
class BtTypeTile extends StatelessWidget {
  const BtTypeTile({super.key, required this.type});
  final String? type;
  static IconData iconFor(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('labour') || t.contains('labor') || t.contains('wage')) return Icons.groups_outlined;
    if (t.contains('equip') || t.contains('machin') || t.contains('expense')) return Icons.local_shipping_outlined;
    return Icons.inventory_2_outlined;
  }

  @override
  Widget build(BuildContext context) => BtTile(icon: iconFor(type));
}

class BtSectionHeader extends StatelessWidget {
  const BtSectionHeader({super.key, required this.title, this.action, this.onAction, this.caption = false});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final bool caption;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Text(title, style: caption ? BtText.caption(context) : BtText.headline(context))),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(minimumSize: const Size(44, 36), padding: const EdgeInsets.symmetric(horizontal: 8), foregroundColor: Bt.ink2),
            child: Text(action!, style: BtText.subhead(context, weight: FontWeight.w500)),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────── buttons

enum BtButtonVariant { primary, accent, secondary, destructive, quiet }

class BtButton extends StatelessWidget {
  const BtButton({super.key, required this.label, required this.onPressed, this.variant = BtButtonVariant.primary, this.icon, this.small = false, this.loading = false, this.expand = true});
  final String label;
  final VoidCallback? onPressed;
  final BtButtonVariant variant;
  final IconData? icon;
  final bool small;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final h = variant == BtButtonVariant.quiet ? 44.0 : (small ? 40.0 : Bt.buttonH);
    final radius = BorderRadius.circular(small ? 12 : Bt.rButton);
    final disabled = onPressed == null || loading;
    Color fg;
    BoxDecoration deco;
    switch (variant) {
      case BtButtonVariant.primary:
        fg = Colors.white;
        deco = BoxDecoration(color: disabled ? bt.brand.withValues(alpha: .45) : bt.brand, borderRadius: radius);
        break;
      case BtButtonVariant.accent:
        fg = bt.onAccent;
        deco = BoxDecoration(gradient: bt.signature, borderRadius: radius);
        break;
      case BtButtonVariant.secondary:
        fg = Bt.ink;
        deco = BoxDecoration(color: Bt.card, borderRadius: radius, border: Border.all(color: Bt.line));
        break;
      case BtButtonVariant.destructive:
        fg = Bt.red;
        deco = BoxDecoration(color: Bt.card, borderRadius: radius, border: Border.all(color: Bt.line));
        break;
      case BtButtonVariant.quiet:
        fg = Bt.ink2;
        deco = const BoxDecoration();
        break;
    }
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: small ? 18 : 20, color: fg), const SizedBox(width: 8)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.button(context, size: small || variant == BtButtonVariant.quiet ? 15 : 17, color: fg).copyWith(fontWeight: variant == BtButtonVariant.quiet ? FontWeight.w500 : FontWeight.w600))),
          ]);
    return Semantics(
      button: true,
      enabled: !disabled,
      child: Opacity(
        opacity: disabled && variant != BtButtonVariant.primary ? .5 : 1,
        child: Container(
          height: h,
          width: expand ? double.infinity : null,
          decoration: deco,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: disabled ? null : onPressed,
              child: Padding(padding: EdgeInsets.symmetric(horizontal: small ? 14 : 18), child: Center(child: child)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom action bar (white, hairline). Put inside Scaffold.bottomNavigationBar.
class BtCtaBar extends StatelessWidget {
  const BtCtaBar({super.key, required this.children, this.vertical = false});
  final List<Widget> children;
  final bool vertical;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Bt.card, border: Border(top: BorderSide(color: Bt.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: vertical
              ? Column(mainAxisSize: MainAxisSize.min, children: children)
              : Row(children: [
                  for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 12), children[i]],
                ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── chips, badges, segmented

class BtChip extends StatelessWidget {
  const BtChip({super.key, required this.label, this.selected = false, this.onTap, this.icon, this.trailingIcon});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final fg = selected ? Colors.white : Bt.ink;
    return Material(
      color: selected ? bt.brand : Bt.card,
      shape: StadiumBorder(side: selected ? BorderSide.none : const BorderSide(color: Bt.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
              Text(label, style: BtText.subhead(context, weight: FontWeight.w500, color: fg)),
              if (trailingIcon != null) ...[const SizedBox(width: 4), Icon(trailingIcon, size: 18, color: fg)],
            ]),
          ),
        ),
      ),
    );
  }
}

enum BtTone { neutral, brand, green, amber, red }

class BtBadge extends StatelessWidget {
  const BtBadge({super.key, required this.label, this.tone = BtTone.neutral});
  final String label;
  final BtTone tone;

  /// Maps backend approval / payment / project / task statuses to a tone.
  static BtTone toneFor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.contains('reject') || s.contains('cancel') || s.contains('overdue') || s.contains('critical')) return BtTone.red;
    if (s.contains('pending') || s.contains('partial') || s.contains('hold') || s.contains('not paid') || s.contains('due') || s.contains('risk')) return BtTone.amber;
    if (s.contains('approved') || s.contains('paid') || s.contains('complete') || s.contains('done') || s.contains('settled') || s.contains('track')) return BtTone.green;
    if (s.contains('progress') || s.contains('active')) return BtTone.brand;
    return BtTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    late Color bg, fg;
    switch (tone) {
      case BtTone.neutral:
        bg = Bt.fill;
        fg = Bt.ink2;
        break;
      case BtTone.brand:
        bg = bt.brandSoft;
        fg = bt.brand;
        break;
      case BtTone.green:
        bg = Bt.greenSoft;
        fg = Bt.green;
        break;
      case BtTone.amber:
        bg = Bt.amberSoft;
        fg = Bt.amber;
        break;
      case BtTone.red:
        bg = Bt.redSoft;
        fg = Bt.red;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, maxLines: 1, style: BtText.caption(context, color: fg, weight: FontWeight.w500)),
    );
  }
}

class BtSegmented<T> extends StatelessWidget {
  const BtSegmented({super.key, required this.segments, required this.value, required this.onChanged});
  final Map<T, String> segments;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        for (final e in segments.entries)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 36,
                alignment: Alignment.center,
                decoration: e.key == value
                    ? BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(9), boxShadow: const [BoxShadow(color: Color(0x1F101828), blurRadius: 2, offset: Offset(0, 1))])
                    : null,
                child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, weight: e.key == value ? FontWeight.w600 : FontWeight.w500, color: e.key == value ? Bt.ink : Bt.ink2)),
              ),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────── fields

/// Label above any field.
class BtField extends StatelessWidget {
  const BtField({super.key, required this.label, required this.child, this.optional = false, this.helper, this.error});
  final String label;
  final Widget child;
  final bool optional;
  final String? helper;
  final String? error;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: label, style: BtText.subhead(context, weight: FontWeight.w500)),
        if (optional) TextSpan(text: ' · optional', style: BtText.subhead(context, color: Bt.ink3)),
      ])),
      const SizedBox(height: 6),
      child,
      if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(error!, style: BtText.caption(context, color: Bt.red))),
      if (error == null && helper != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(helper!, style: BtText.caption(context))),
    ]);
  }
}

/// InputDecoration for TextField / TextFormField / DropdownButtonFormField.
InputDecoration btInput(BuildContext context, {String? hint, Widget? prefix, Widget? suffix, String? prefixText, String? suffixText, String? errorText}) {
  final bt = context.bt;
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: BtText.body(context, color: Bt.placeholder),
    prefixIcon: prefix,
    suffixIcon: suffix,
    prefixText: prefixText,
    prefixStyle: BtText.body(context, color: Bt.ink2),
    suffixText: suffixText,
    suffixStyle: BtText.body(context, color: Bt.ink2),
    errorText: errorText,
    filled: true,
    fillColor: Bt.card,
    isDense: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: b(Bt.inputBorder),
    enabledBorder: b(Bt.inputBorder),
    focusedBorder: b(bt.brand, 2),
    errorBorder: b(Bt.red),
    focusedErrorBorder: b(Bt.red, 2),
    disabledBorder: b(Bt.line),
  );
}

class BtSwitch extends StatelessWidget {
  const BtSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: context.bt.brand);
}

/// A tappable field-looking row (pickers: date, where, dropdown sheets).
class BtPickerField extends StatelessWidget {
  const BtPickerField({super.key, required this.text, this.placeholder = false, this.onTap, this.icon = Icons.expand_more_rounded, this.leading});
  final String text;
  final bool placeholder;
  final VoidCallback? onTap;
  final IconData icon;
  final IconData? leading;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? Bt.fill : Bt.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rInput), side: const BorderSide(color: Bt.inputBorder)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Bt.rInput),
        onTap: onTap,
        child: SizedBox(
          height: Bt.fieldH,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              if (leading != null) ...[Icon(leading, size: 18, color: Bt.ink3), const SizedBox(width: 10)],
              Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, color: placeholder ? Bt.placeholder : Bt.ink))),
              Icon(icon, size: 20, color: Bt.ink3),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── progress & stats

class BtProgress extends StatelessWidget {
  const BtProgress({super.key, required this.value, this.work = false, this.color, this.thin = false});
  final double value; // 0..1
  final bool work;
  final Color? color;
  final bool thin;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final h = thin ? 6.0 : 8.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(h / 2),
      child: Container(
        height: h,
        color: Bt.fill,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(decoration: BoxDecoration(color: work ? null : (color ?? bt.brand), gradient: work ? bt.progressWork : null)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── states

class BtEmpty extends StatelessWidget {
  const BtEmpty({super.key, required this.title, this.message, this.icon = Icons.inbox_outlined, this.action, this.onAction});
  final String title;
  final String? message;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        BtTile(icon: icon, size: 56),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: BtText.headline(context)),
        if (message != null) ...[const SizedBox(height: 4), Text(message!, textAlign: TextAlign.center, style: BtText.subhead(context))],
        if (action != null) ...[const SizedBox(height: 16), BtButton(label: action!, onPressed: onAction, small: true, expand: false)],
      ]),
    );
  }
}

class BtErrorCard extends StatelessWidget {
  const BtErrorCard({super.key, this.message = "Couldn't load", this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    return BtCard(
      variant: BtCardVariant.danger,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Bt.red, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: BtText.subhead(context, color: Bt.red))),
        if (onRetry != null) TextButton(onPressed: onRetry, child: Text('Retry', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.red))),
      ]),
    );
  }
}

class BtSkeleton extends StatelessWidget {
  const BtSkeleton({super.key, this.height = 56, this.width, this.radius = 12});
  final double height;
  final double? width;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(height: height, width: width, decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(radius)));
}

/// A few skeleton rows inside a group.
class BtSkeletonList extends StatelessWidget {
  const BtSkeletonList({super.key, this.count = 3});
  final int count;
  @override
  Widget build(BuildContext context) => Column(children: [for (var i = 0; i < count; i++) const Padding(padding: EdgeInsets.only(bottom: 8), child: BtSkeleton(height: 64, radius: 16))]);
}

// ─────────────────────────────────────────────────────────────── avatar

class BtAvatar extends StatelessWidget {
  const BtAvatar({super.key, required this.name, this.image, this.size = 40, this.self = false});
  final String name;
  final ImageProvider? image;
  final double size;
  final bool self;
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: self ? Bt.ink : Bt.fill,
      backgroundImage: image,
      child: image == null ? Text(initials(name), style: TextStyle(fontSize: size * .36, fontWeight: FontWeight.w600, color: self ? Colors.white : Bt.ink)) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────── sheets

/// Opens a BuildTrack bottom sheet (grabber, title, close, scrim).
Future<T?> showBtSheet<T>(BuildContext context, {required String title, String? subtitle, required Widget Function(BuildContext) builder, bool scroll = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Bt.card,
    barrierColor: Bt.scrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
    builder: (ctx) {
      final body = Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BtSheetHeader(title: title, subtitle: subtitle),
          Flexible(
            child: scroll
                ? SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), child: builder(ctx))
                : Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), child: builder(ctx)),
          ),
        ]),
      );
      return SafeArea(top: false, child: body);
    },
  );
}

class BtSheetHeader extends StatelessWidget {
  const BtSheetHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 8),
      Container(width: 40, height: 5, decoration: BoxDecoration(color: Bt.inputBorder, borderRadius: BorderRadius.circular(3))),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: BtText.title(context)),
              if (subtitle != null) Text(subtitle!, style: BtText.caption(context)),
            ]),
          ),
          Material(
            color: Bt.fill,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(width: 36, height: 36, child: Icon(Icons.close_rounded, size: 18, color: Bt.ink)),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// Standard confirm dialog (destructive actions end with "…" on the button that opens it).
Future<bool> btConfirm(BuildContext context, {required String title, String? message, required String confirmLabel, bool destructive = true, String cancelLabel = 'Cancel'}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: Bt.scrim,
    builder: (ctx) => AlertDialog(
      backgroundColor: Bt.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: BtText.title(ctx, size: 18)),
      content: message == null ? null : Text(message, style: BtText.body(ctx, color: Bt.ink2)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel, style: BtText.body(ctx, weight: FontWeight.w500, color: Bt.ink2))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel, style: BtText.body(ctx, weight: FontWeight.w600, color: destructive ? Bt.red : ctx.bt.brand))),
      ],
    ),
  );
  return r ?? false;
}

/// Standard snackbar.
void btToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    content: Text(message, style: const TextStyle(color: Colors.white)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? Bt.red : Bt.ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
  ));
}
