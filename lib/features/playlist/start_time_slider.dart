import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Precise start-time picker built on [CupertinoSlider].
/// Range is 0–[maxMs] with 10 ms steps.
/// The current value floats as a label above the thumb.
class StartTimeSlider extends StatelessWidget {
  const StartTimeSlider({
    super.key,
    required this.valueMs,
    required this.maxMs,
    required this.onChanged,
    this.onChangeEnd,
    this.color,
    this.onNudgeMinus,
    this.onNudgePlus,
  });

  static const int _stepMs = 10;
  // CupertinoSlider thumb radius — used to calculate thumb center x.
  static const double _thumbRadius = 14.0;
  static const double _labelWidth = 80.0;

  final int valueMs;
  final int maxMs;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color? color;
  final VoidCallback? onNudgeMinus;
  final VoidCallback? onNudgePlus;

  static String formatMs(int ms) {
    final m = ms ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).primaryColor;
    final clamped = valueMs.clamp(0, maxMs).toDouble();
    final fraction =
        maxMs > 0 ? valueMs.clamp(0, maxMs) / maxMs.toDouble() : 0.0;

    return Row(
      children: [
        if (onNudgeMinus != null)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 32,
            onPressed: onNudgeMinus,
            child: Icon(CupertinoIcons.minus, color: c, size: 20),
          )
        else
          Text(
            '0:00.000',
            style: TextStyle(color: c.withOpacity(0.45), fontSize: 11),
          ),
        // ── slider with floating value label ──────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final thumbX =
                  _thumbRadius + fraction * (w - 2 * _thumbRadius);
              final labelLeft =
                  (thumbX - _labelWidth / 2).clamp(0.0, w - _labelWidth);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fixed-height row that holds only the floating label.
                  SizedBox(
                    height: 18,
                    child: Stack(
                      children: [
                        Positioned(
                          left: labelLeft,
                          width: _labelWidth,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Text(
                              formatMs(valueMs.clamp(0, maxMs)),
                              style: TextStyle(
                                color: c,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Slider fills the full width via stretch alignment.
                  CupertinoSlider(
                    min: 0,
                    max: maxMs.toDouble(),
                    divisions: maxMs ~/ _stepMs,
                    value: clamped,
                    activeColor: c,
                    thumbColor: CupertinoColors.white,
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd,
                  ),
                ],
              );
            },
          ),
        ),
        if (onNudgePlus != null)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 32,
            onPressed: onNudgePlus,
            child: Icon(CupertinoIcons.plus, color: c, size: 20),
          )
        else
          Text(
            formatMs(maxMs),
            style: TextStyle(color: c.withOpacity(0.45), fontSize: 11),
          ),
      ],
    );
  }
}
