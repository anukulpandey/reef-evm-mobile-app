import 'package:flutter/material.dart';

import '../../core/theme/styles.dart';

class SendAmountSlider extends StatelessWidget {
  const SendAmountSlider({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            showValueIndicator: ShowValueIndicator.never,
            overlayShape: SliderComponentShape.noOverlay,
            valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
            valueIndicatorColor: Styles.secondaryAccentColorDark,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            thumbColor: Styles.secondaryAccentColorDark,
            inactiveTickMarkColor: const Color(0xffc0b8dc),
            trackShape: const _GradientRectSliderTrackShape(
              gradient: Styles.buttonGradient,
              darkenInactive: true,
            ),
            activeTickMarkColor: const Color(0xffffffff),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
            thumbShape: const _ThumbShape(),
          ),
          child: Slider(
            value: value,
            onChanged: enabled ? onChanged : null,
            inactiveColor: Colors.white24,
            divisions: 100,
            label: '${(value * 100).toInt()}%',
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0%',
                style: TextStyle(
                  color: Color(0xFF7E7892),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                '50%',
                style: TextStyle(
                  color: Color(0xFF7E7892),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                '100%',
                style: TextStyle(
                  color: Color(0xFF7E7892),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GradientRectSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _GradientRectSliderTrackShape({
    this.gradient = const LinearGradient(
      colors: [Colors.lightBlue, Colors.blue],
    ),
    this.darkenInactive = true,
  });

  final LinearGradient gradient;
  final bool darkenInactive;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activeTrackColorTween = ColorTween(
      begin: sliderTheme.disabledActiveTrackColor,
      end: sliderTheme.activeTrackColor,
    );
    final inactiveTrackColorTween = darkenInactive
        ? ColorTween(
            begin: sliderTheme.disabledInactiveTrackColor,
            end: sliderTheme.inactiveTrackColor,
          )
        : activeTrackColorTween;

    final activePaint = Paint()
      ..shader = gradient.createShader(trackRect)
      ..color =
          activeTrackColorTween.evaluate(enableAnimation) ?? Colors.transparent;
    final inactivePaint = Paint()
      ..shader = gradient.createShader(trackRect)
      ..color =
          inactiveTrackColorTween.evaluate(enableAnimation) ??
          Colors.transparent;

    final leftTrackPaint = textDirection == TextDirection.ltr
        ? activePaint
        : inactivePaint;
    final rightTrackPaint = textDirection == TextDirection.ltr
        ? inactivePaint
        : activePaint;

    final trackRadius = Radius.circular(trackRect.height / 2);
    final activeTrackRadius = Radius.circular(trackRect.height / 2 + 1);

    context.canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        trackRect.left,
        trackRect.top,
        thumbCenter.dx,
        trackRect.bottom,
        topLeft: textDirection == TextDirection.ltr
            ? activeTrackRadius
            : trackRadius,
        bottomLeft: textDirection == TextDirection.ltr
            ? activeTrackRadius
            : trackRadius,
      ),
      leftTrackPaint,
    );

    context.canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        thumbCenter.dx,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
        topRight: textDirection == TextDirection.rtl
            ? activeTrackRadius
            : trackRadius,
        bottomRight: textDirection == TextDirection.rtl
            ? activeTrackRadius
            : trackRadius,
      ),
      rightTrackPaint,
    );
  }
}

class _ThumbShape extends RoundSliderThumbShape {
  const _ThumbShape();

  final _indicatorShape = const PaddleSliderValueIndicatorShape();

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    super.paint(
      context,
      center,
      activationAnimation: activationAnimation,
      enableAnimation: enableAnimation,
      sliderTheme: sliderTheme,
      value: value,
      textScaleFactor: textScaleFactor,
      sizeWithOverflow: sizeWithOverflow,
      isDiscrete: isDiscrete,
      labelPainter: labelPainter,
      parentBox: parentBox,
      textDirection: textDirection,
    );

    _indicatorShape.paint(
      context,
      center,
      activationAnimation: const AlwaysStoppedAnimation(1),
      enableAnimation: enableAnimation,
      labelPainter: labelPainter,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      value: value,
      textScaleFactor: 0.8,
      sizeWithOverflow: sizeWithOverflow,
      isDiscrete: isDiscrete,
      textDirection: textDirection,
    );
  }
}
