import 'package:flutter/material.dart';
import 'package:flutter_awesome_icon/awesome_icons.dart';

class AppAwesomeIcon extends StatelessWidget {
  final String icon;
  final double size;
  final Color? color;
  final bool isBold;

  const AppAwesomeIcon({
    super.key,
    required this.icon,
    this.size = 20,
    this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    if (isBold) {
      return AwesomeIconsBold(
        icon: icon,
        size: size,
        fill: effectiveColor,
      );
    }
    return AwesomeIconsOutline(
      icon: icon,
      size: size,
      strokeColor: effectiveColor,
    );
  }
}
