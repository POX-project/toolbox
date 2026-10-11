import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? surfaceColor;
  final Color? borderColor;
  final double blur;
  final VoidCallback? onTap;
  final bool isGlowing;
  final Color? glowColor;
  final Gradient? borderGradient;
  final Gradient? backgroundGradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.surfaceColor,
    this.borderColor,
    this.blur = 0,
    this.onTap,
    this.isGlowing = false,
    this.glowColor,
    this.borderGradient,
    this.backgroundGradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = surfaceColor ?? theme.cardTheme.color ?? theme.colorScheme.surface;
    final border = borderColor ?? theme.colorScheme.outline;

    Widget card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundGradient == null ? bg : null,
        gradient: backgroundGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderGradient == null ? Border.all(color: border, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x30000000) : const Color(0x05000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    if (borderGradient != null) {
      card = Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: borderGradient,
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x30000000) : const Color(0x05000000),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(1),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius - 1),
          ),
          child: child,
        ),
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          highlightColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
          child: card,
        ),
      );
    }

    return card;
  }
}
