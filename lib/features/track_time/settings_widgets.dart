import 'package:flutter/material.dart';

Widget globalInfoBox(BuildContext context, String label, Widget child) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).primaryColor, width: 1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).hintColor,
              letterSpacing: 0.8,
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

Widget sectionButton(
  BuildContext context, {
  required String label,
  required IconData icon,
  required bool disabled,
  required VoidCallback onPressed,
  bool destructive = false,
}) {
  final color = destructive ? Colors.red : Theme.of(context).primaryColor;
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: disabled ? color.withOpacity(0.3) : color,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: disabled ? null : onPressed,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
