import 'package:flutter/cupertino.dart';

/// App primary (filled) action button; shows a spinner while [busy].
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    this.busy = false,
    required this.onPressed,
    required this.child,
  });

  final bool busy;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton.filled(
      onPressed: busy ? null : onPressed,
      child: busy ? const CupertinoActivityIndicator() : child,
    );
  }
}
