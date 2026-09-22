import 'package:flutter/material.dart';

/// Drop-in replacement for `GestureDetector(onTap: ...)` that adds the
/// Material ripple/press feedback a tappable element is expected to have —
/// most of this app's custom buttons and cards had none at all.
class Tappable extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  const Tappable({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: child,
      ),
    );
    if (semanticLabel == null) return button;
    return Semantics(button: true, label: semanticLabel, child: button);
  }
}
