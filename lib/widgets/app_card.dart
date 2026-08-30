import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

class const AppCard({
  required final Widget child,
  final EdgeInsetsGeometry? padding = const EdgeInsets.all(ELayout.spaceLg),
  final EdgeInsetsGeometry? margin,
}) extends StatelessWidget {
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
