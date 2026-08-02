import 'package:flutter/material.dart';

/// App primary (filled) action button; shows a spinner while [busy].
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    this.busy = false,
    required this.onPressed,
    required this.child,
  });

  final bool busy;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : child,
    );
  }
}
