import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Filled pill-shaped primary action button (Cupertino style).
/// Passing null [onPressed] renders at 50% opacity (disabled).
class DJPrimaryButton extends StatelessWidget {
  const DJPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  /// Override fill color. Defaults to [Theme.primaryColor].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).primaryColor;
    return CupertinoButton(
      color: color,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }
}

/// Text-only button — no border, no background (Apple dialog pattern).
/// Defaults to label 'Cancel'; pass a custom [label] for other uses.
class DJCancelButton extends StatelessWidget {
  const DJCancelButton({
    super.key,
    required this.onPressed,
    this.label = 'Cancel',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
    );
  }
}

/// Icon-only action button with Cupertino press feedback.
/// Replaces [IconButton] outside AppBar.
class DJIconActionButton extends StatelessWidget {
  const DJIconActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final button = CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 40,
      onPressed: onPressed,
      child: Icon(icon, color: color, size: 24),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Icon + label text button with no background.
/// Replaces [TextButton.icon] for secondary actions.
class DJTextIconButton extends StatelessWidget {
  const DJTextIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
