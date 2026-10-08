import 'package:flutter/material.dart';

/// The djSports logo with a little stage-light flash on tap: two quick
/// blinks, a small pulse and – when [version] is given – the version glows
/// amber. [onTap] runs after [onTapDelay], so the flash is seen before a
/// new screen opens.
class FlashingLogo extends StatefulWidget {
  const FlashingLogo({
    super.key,
    this.size = 70,
    this.version,
    this.versionColor = Colors.white70,
    this.onTap,
    this.onTapDelay = const Duration(milliseconds: 300),
    this.tooltip,
  });

  final double size;
  final String? version;
  final Color versionColor;
  final VoidCallback? onTap;
  final Duration onTapDelay;
  final String? tooltip;

  @override
  State<FlashingLogo> createState() => _FlashingLogoState();
}

class _FlashingLogoState extends State<FlashingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Two blinks of light over the logo.
  late final Animation<double> _flash = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0, end: 0.9), weight: 1),
    TweenSequenceItem(tween: Tween<double>(begin: 0.9, end: 0), weight: 2),
    TweenSequenceItem(tween: Tween<double>(begin: 0, end: 0.7), weight: 1),
    TweenSequenceItem(tween: Tween<double>(begin: 0.7, end: 0), weight: 3),
  ]).animate(_controller);

  /// A small pulse in size.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.12), weight: 1),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.12,
        end: 1,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 3,
    ),
  ]).animate(_controller);

  /// The version glows amber, then fades back.
  late final Animation<double> _highlight = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 1),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 3),
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 2),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    _controller.forward(from: 0);
    final onTap = widget.onTap;
    if (onTap == null) return;
    await Future<void>.delayed(widget.onTapDelay);
    if (mounted) onTap();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final logo = GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: _scale.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/djsports/djsports_v12_round.png',
                    width: size,
                    height: size,
                  ),
                  // The flash: white light from the centre of the logo.
                  IgnorePointer(
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: _flash.value),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.version != null)
              Text(
                widget.version!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Color.lerp(
                    widget.versionColor,
                    Colors.amberAccent,
                    _highlight.value,
                  ),
                  fontWeight: _highlight.value > 0.5
                      ? FontWeight.w800
                      : FontWeight.normal,
                  shadows: [
                    Shadow(
                      color: Colors.amberAccent.withValues(
                        alpha: 0.8 * _highlight.value,
                      ),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    final tooltip = widget.tooltip;
    return tooltip == null ? logo : Tooltip(message: tooltip, child: logo);
  }
}
