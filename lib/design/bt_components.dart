import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'bt_motion.dart';
import 'bt_theme.dart';
import 'bt_text.dart';

// ─────────────────────────────────────────────────────────────── press feedback

/// Scales its child to .97 while pressed (spring back on release).
/// Cheap: one implicit animation, no controller kept alive.
class BtPressable extends StatefulWidget {
  const BtPressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = .97, this.borderRadius, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  State<BtPressable> createState() => _BtPressableState();
}

class _BtPressableState extends State<BtPressable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final scales = BtMotion.isFull(context); // Reduced / Off: no press scale
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: scales && _down ? widget.scale : 1,
          duration: scales ? (_down ? const Duration(milliseconds: 90) : const Duration(milliseconds: 380)) : Duration.zero,
          curve: _down ? Curves.easeOut : Bt.spring,
          child: widget.child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── nav bars

/// Large title header for tab roots.
class BtLargeHeader extends StatelessWidget {
  const BtLargeHeader({super.key, required this.title, this.caption, this.trailing, this.onCaptionTap});
  final String title;
  final String? caption;
  final VoidCallback? onCaptionTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(child: Text(caption!.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.mono(context))),
                        if (onCaptionTap != null) const Icon(Icons.expand_more_rounded, size: 16, color: Bt.ink3),
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
              size: close ? 22 : 19,
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
  const BtIconButton({super.key, required this.icon, required this.onTap, this.semantic, this.size = 22, this.color = Bt.ink, this.filled = false, this.badge, this.background});
  final IconData icon;
  final VoidCallback? onTap;
  final String? semantic;
  final double size;
  final Color color;
  final bool filled;
  final int? badge;

  /// Overrides the fill (e.g. glass on the noir hero: `Colors.white.withValues(alpha: .09)`).
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? (filled ? Bt.card : Colors.transparent);
    return BtPressable(
      onTap: onTap,
      scale: .9,
      semanticLabel: semantic,
      child: Container(
        width: Bt.touch,
        height: Bt.touch,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle, boxShadow: filled && background == null ? Bt.shadow : null),
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          Icon(icon, size: size, color: color),
          if (badge != null && badge! > 0) Positioned(top: 3, right: 3, child: BtCountBadge(count: badge!)),
        ]),
      ),
    );
  }
}

class BtCountBadge extends StatelessWidget {
  const BtCountBadge({super.key, required this.count, this.ring = Colors.white});
  final int count;
  final Color ring;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(color: Bt.redBright, borderRadius: BorderRadius.circular(9), border: Border.all(color: ring, width: 2)),
      alignment: Alignment.center,
      child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1)),
    );
  }
}

// ─────────────────────────────────────────────────────────────── surfaces

enum BtCardVariant { plain, attention, notice, danger, ink }

/// The paper card: white, radius 22, soft layered shadow (no hairline).
/// `ink` = noir card for the "signature" moments.
class BtCard extends StatelessWidget {
  const BtCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.variant = BtCardVariant.plain, this.margin});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BtCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    Color bg = Bt.card;
    Border? border;
    List<BoxShadow>? shadow = Bt.shadow;
    switch (variant) {
      case BtCardVariant.attention:
        border = Border.all(color: bt.accent, width: 1.5);
        break;
      case BtCardVariant.notice:
        bg = Bt.amberSoft;
        shadow = null;
        break;
      case BtCardVariant.danger:
        bg = Bt.redSoft;
        shadow = null;
        break;
      case BtCardVariant.ink:
        bg = Bt.noir;
        shadow = Bt.shadowLg;
        break;
      case BtCardVariant.plain:
        break;
    }
    Widget card = Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Bt.rCard), border: border, boxShadow: shadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Bt.rCard),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (variant == BtCardVariant.ink) {
      card = DefaultTextStyle.merge(style: const TextStyle(color: Bt.bone), child: IconTheme.merge(data: const IconThemeData(color: Bt.bone), child: card));
    }
    if (onTap != null) card = BtPressable(onTap: onTap, scale: .98, child: card);
    return Padding(padding: margin ?? EdgeInsets.zero, child: card);
  }
}

/// Grouped list container.
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
      child: Container(
        decoration: BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(Bt.rCard), boxShadow: Bt.shadow),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Bt.rCard),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}

/// The workhorse list row.
class BtRow extends StatelessWidget {
  const BtRow({super.key, this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.showChevron = false, this.titleColor, this.subtitleColor, this.minHeight = 60, this.subtitleMaxLines = 1, this.titleWeight = FontWeight.w500});
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
      splashColor: Bt.ink.withValues(alpha: .04),
      highlightColor: Bt.ink.withValues(alpha: .03),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            Text(label, style: BtText.subhead(context)),
            const SizedBox(width: 16),
            Expanded(child: Text(value, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w500, color: valueColor ?? (onTap != null ? context.bt.accentInk : Bt.ink)))),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ]),
        ),
      ),
    );
  }
}

class BtTile extends StatelessWidget {
  const BtTile({super.key, required this.icon, this.bg, this.fg, this.size = 42});
  final IconData icon;
  final Color? bg;
  final Color? fg;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? Bt.fill, borderRadius: BorderRadius.circular(size * .33)),
      child: Icon(icon, size: size * .52, color: fg ?? Bt.ink),
    );
  }
}

/// Entry-type icon tile: material / labour / equipment (fixed icons).
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
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Text(caption ? title.toUpperCase() : title, style: caption ? BtText.mono(context) : BtText.headline(context))),
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

enum BtButtonVariant { primary, accent, secondary, destructive, quiet, onDark }

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
    final h = variant == BtButtonVariant.quiet ? 44.0 : (small ? 42.0 : Bt.buttonH);
    final radius = BorderRadius.circular(small ? 14 : Bt.rButton);
    final disabled = onPressed == null || loading;
    Color fg;
    BoxDecoration deco;
    switch (variant) {
      case BtButtonVariant.primary:
        fg = Bt.bone;
        deco = BoxDecoration(color: disabled && !loading ? Bt.ink.withValues(alpha: .35) : Bt.ink, borderRadius: radius);
        break;
      case BtButtonVariant.accent:
        fg = bt.onAccent;
        deco = BoxDecoration(
          color: bt.accent,
          borderRadius: radius,
          boxShadow: disabled ? null : [BoxShadow(color: bt.accent.withValues(alpha: .45), blurRadius: 26, spreadRadius: -12, offset: const Offset(0, 10))],
        );
        break;
      case BtButtonVariant.secondary:
        fg = Bt.ink;
        deco = BoxDecoration(color: Bt.card, borderRadius: radius, border: Border.all(color: Bt.inputBorder));
        break;
      case BtButtonVariant.destructive:
        fg = Bt.red;
        deco = BoxDecoration(color: Bt.card, borderRadius: radius, border: Border.all(color: Bt.inputBorder));
        break;
      case BtButtonVariant.quiet:
        fg = Bt.ink2;
        deco = const BoxDecoration();
        break;
      case BtButtonVariant.onDark:
        fg = Bt.bone;
        deco = BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: radius, border: Border.all(color: Colors.white.withValues(alpha: .14)));
        break;
    }
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: small ? 18 : 20, color: fg), const SizedBox(width: 8)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.button(context, size: small || variant == BtButtonVariant.quiet ? 15 : 16, color: fg).copyWith(fontWeight: variant == BtButtonVariant.quiet ? FontWeight.w500 : FontWeight.w600))),
          ]);
    return Semantics(
      button: true,
      enabled: !disabled,
      child: Opacity(
        opacity: disabled && variant != BtButtonVariant.primary && !loading ? .5 : 1,
        child: BtPressable(
          onTap: disabled ? null : onPressed,
          child: Container(
            height: h,
            width: expand ? double.infinity : null,
            decoration: deco,
            padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Bottom action bar. Put inside Scaffold.bottomNavigationBar.
/// Content fades out under it (no hairline) so the CTA floats on the page.
class BtCtaBar extends StatelessWidget {
  const BtCtaBar({super.key, required this.children, this.vertical = false});
  final List<Widget> children;
  final bool vertical;
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, stops: const [.72, 1], colors: [bg, bg.withValues(alpha: 0)]),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: vertical
              ? Column(mainAxisSize: MainAxisSize.min, children: children)
              : Row(children: [
                  for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 10), children[i]],
                ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── chips, badges, segmented

class BtChip extends StatelessWidget {
  const BtChip({super.key, required this.label, this.selected = false, this.onTap, this.icon, this.trailingIcon, this.onDark = false});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Glass style for chips placed on the noir hero.
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    Border? border;
    if (onDark) {
      bg = selected ? Bt.bone : Colors.white.withValues(alpha: .08);
      fg = selected ? Bt.noir : Bt.bone;
      border = selected ? null : Border.all(color: Colors.white.withValues(alpha: .12));
    } else {
      bg = selected ? Bt.ink : Bt.card;
      fg = selected ? Bt.bone : Bt.ink;
      border = selected ? null : Border.all(color: Bt.inputBorder);
    }
    return BtPressable(
      onTap: onTap,
      scale: .95,
      child: AnimatedContainer(
        duration: Bt.fast,
        curve: Bt.ease,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Bt.rChip), border: border),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
          Text(label, style: BtText.subhead(context, weight: FontWeight.w500, color: fg)),
          if (trailingIcon != null) ...[const SizedBox(width: 4), Icon(trailingIcon, size: 18, color: fg)],
        ]),
      ),
    );
  }
}

enum BtTone { neutral, brand, green, amber, red }

/// Status pill with a leading dot.
class BtBadge extends StatelessWidget {
  const BtBadge({super.key, required this.label, this.tone = BtTone.neutral, this.dot = true});
  final String label;
  final BtTone tone;
  final bool dot;

  /// Maps backend approval / payment / project / task statuses to a tone.
  static BtTone toneFor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.contains('reject') || s.contains('cancel') || s.contains('overdue') || s.contains('critical') || s.contains('not paid')) return BtTone.red;
    if (s.contains('pending') || s.contains('partial') || s.contains('hold') || s.contains('due') || s.contains('risk')) return BtTone.amber;
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
        bg = bt.accentSoft;
        fg = bt.accentInk;
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
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot && tone != BtTone.neutral) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)), const SizedBox(width: 6)],
        Text(label, maxLines: 1, style: BtText.caption(context, color: fg, weight: FontWeight.w600).copyWith(fontSize: 12)),
      ]),
    );
  }
}

/// Segmented control with a sliding white thumb.
class BtSegmented<T> extends StatelessWidget {
  const BtSegmented({super.key, required this.segments, required this.value, required this.onChanged, this.onDark = false});
  final Map<T, String> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final keys = segments.keys.toList();
    final idx = keys.indexOf(value).clamp(0, keys.length - 1);
    final n = keys.length;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: onDark ? Colors.white.withValues(alpha: .07) : Bt.ink.withValues(alpha: .06), borderRadius: BorderRadius.circular(16)),
      child: Stack(children: [
        AnimatedAlign(
          duration: BtMotion.moving(context, Bt.medium),
          curve: Bt.ease,
          alignment: Alignment(n == 1 ? 0 : -1 + 2 * idx / (n - 1), 0),
          child: FractionallySizedBox(
            widthFactor: 1 / n,
            heightFactor: 1,
            child: Container(
              decoration: BoxDecoration(
                color: onDark ? Colors.white.withValues(alpha: .14) : Bt.card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: onDark ? null : const [BoxShadow(color: Color(0x240C0E12), blurRadius: 3, offset: Offset(0, 1))],
              ),
            ),
          ),
        ),
        Row(children: [
          for (final e in segments.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: e.key == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(e.key),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: Bt.fast,
                      style: BtText.subhead(context,
                          weight: e.key == value ? FontWeight.w600 : FontWeight.w500,
                          color: onDark ? (e.key == value ? Colors.white : Bt.onNoir2) : (e.key == value ? Bt.ink : Bt.ink2)),
                      child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              ),
            ),
        ]),
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
      const SizedBox(height: 7),
      child,
      if (error != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(error!, style: BtText.caption(context, color: Bt.red))),
      if (error == null && helper != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(helper!, style: BtText.caption(context))),
    ]);
  }
}

/// InputDecoration for TextField / TextFormField / DropdownButtonFormField.
InputDecoration btInput(BuildContext context, {String? hint, Widget? prefix, Widget? suffix, String? prefixText, String? suffixText, String? errorText}) {
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: b(Bt.inputBorder),
    enabledBorder: b(Bt.inputBorder),
    focusedBorder: b(Bt.ink, 2),
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
  Widget build(BuildContext context) => CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: context.bt.accent);
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
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

/// Progress bar that grows into place (once per value change).
class BtProgress extends StatelessWidget {
  const BtProgress({super.key, required this.value, this.work = false, this.color, this.thin = false, this.onDark = false});
  final double value; // 0..1
  final bool work;
  final Color? color;
  final bool thin;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final h = thin ? 6.0 : 8.0;
    final reduce = Bt.reduceMotion(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(h / 2),
      child: Container(
        height: h,
        color: onDark ? Colors.white.withValues(alpha: .10) : Bt.ink.withValues(alpha: .08),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduce ? v : 0, end: v),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 1100),
          curve: Bt.ease,
          builder: (_, t, _) => FractionallySizedBox(
            widthFactor: t,
            heightFactor: 1,
            child: DecoratedBox(decoration: BoxDecoration(color: color ?? bt.accent, borderRadius: BorderRadius.circular(h / 2))),
          ),
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
    final bt = context.bt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        BtTile(icon: icon, size: 60, bg: bt.accentSoft, fg: bt.accentInk),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: BtText.title(context, size: 19)),
        if (message != null) ...[const SizedBox(height: 6), Text(message!, textAlign: TextAlign.center, style: BtText.subhead(context))],
        if (action != null) ...[const SizedBox(height: 18), BtButton(label: action!, onPressed: onAction, small: true, expand: false)],
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

/// Shimmering placeholder block.
class BtSkeleton extends StatefulWidget {
  const BtSkeleton({super.key, this.height = 56, this.width, this.radius = 14});
  final double height;
  final double? width;
  final double radius;
  @override
  State<BtSkeleton> createState() => _BtSkeletonState();
}

class _BtSkeletonState extends State<BtSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Bt.reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final x = -1.5 + 3 * _c.value;
          return Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(x - 1, 0),
                end: Alignment(x + 1, 0),
                colors: const [Color(0xFFEAE7E1), Color(0xFFF5F3EF), Color(0xFFEAE7E1)],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A few skeleton rows.
class BtSkeletonList extends StatelessWidget {
  const BtSkeletonList({super.key, this.count = 3});
  final int count;
  @override
  Widget build(BuildContext context) => Column(children: [for (var i = 0; i < count; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: BtSkeleton(height: 66, radius: 20))]);
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
    final bt = context.bt;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: self ? bt.accent : Bt.noir3,
      backgroundImage: image,
      child: image == null ? Text(initials(name), style: TextStyle(fontSize: size * .36, fontWeight: FontWeight.w600, color: self ? bt.onAccent : Bt.bone)) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────── sheets

/// Slide-in style for bottom sheets, following the Motion setting: Full = the
/// usual eased slide, Reduced = a quick one, Off = instant. Pass the caller's
/// `context` (read once, when the sheet opens).
AnimationStyle btSheetStyle(BuildContext context, {int ms = 520, int reverseMs = 260}) {
  switch (BtMotion.peek(context)) {
    case BtMotionLevel.full:
      return AnimationStyle(duration: Duration(milliseconds: ms), curve: Bt.ease, reverseDuration: Duration(milliseconds: reverseMs));
    case BtMotionLevel.reduced:
      return const AnimationStyle(duration: Duration(milliseconds: 160), curve: Curves.easeOut, reverseDuration: Duration(milliseconds: 120));
    case BtMotionLevel.off:
      return AnimationStyle.noAnimation;
  }
}

/// For sheets that keep Flutter's default slide when motion is Full.
AnimationStyle? btSheetStyleDefault(BuildContext context) => BtMotion.peek(context) == BtMotionLevel.full ? null : btSheetStyle(context);

/// Opens a BuildTrack bottom sheet (grabber, title, close, scrim).
Future<T?> showBtSheet<T>(BuildContext context, {required String title, String? subtitle, required Widget Function(BuildContext) builder, bool scroll = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Bt.card,
    barrierColor: Bt.scrim,
    sheetAnimationStyle: btSheetStyle(context),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
    builder: (ctx) {
      final body = Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BtSheetHeader(title: title, subtitle: subtitle),
          Flexible(
            child: scroll
                ? SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 18), child: builder(ctx))
                : Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 18), child: builder(ctx)),
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
      const SizedBox(height: 10),
      Container(width: 40, height: 5, decoration: BoxDecoration(color: Bt.inputBorder, borderRadius: BorderRadius.circular(3))),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: BtText.d3(context)),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: BtText.caption(context))),
            ]),
          ),
          BtIconButton(icon: Icons.close_rounded, size: 18, semantic: 'Close', background: Bt.fill, onTap: () => Navigator.of(context).maybePop()),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: Text(title, style: BtText.d3(ctx)),
      content: message == null ? null : Text(message, style: BtText.body(ctx, color: Bt.ink2)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(children: [
          Expanded(child: BtButton(label: cancelLabel, variant: BtButtonVariant.secondary, small: true, onPressed: () => Navigator.pop(ctx, false))),
          const SizedBox(width: 10),
          Expanded(
            child: destructive
                ? Semantics(
                    button: true,
                    child: BtPressable(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Bt.redBright, borderRadius: BorderRadius.circular(14)),
                        child: Text(confirmLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.button(ctx, size: 15, color: Colors.white)),
                      ),
                    ),
                  )
                : BtButton(label: confirmLabel, small: true, onPressed: () => Navigator.pop(ctx, true)),
          ),
        ]),
      ],
    ),
  );
  return r ?? false;
}

/// Standard snackbar.
void btToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    content: Row(children: [
      Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: error ? const Color(0xFFFF8A8E) : const Color(0xFF4ADBA4), size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: BtText.subhead(context, color: Bt.bone, weight: FontWeight.w500))),
    ]),
    behavior: SnackBarBehavior.floating,
    backgroundColor: Bt.noir,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
  ));
}
