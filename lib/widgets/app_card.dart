import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(ELayout.spaceLg),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final surface = ESurface(
      kind: ESurfaceKind.row,
      padding: padding,
      child: child,
    );
    if (margin == null) return surface;
    return Padding(padding: margin!, child: surface);
  }
}
