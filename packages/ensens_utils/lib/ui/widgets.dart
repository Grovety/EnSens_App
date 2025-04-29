import 'package:bordered_text/bordered_text.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../ensens_utils.dart';

class EnsensGradientBackground extends StatelessWidget {
  const EnsensGradientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: EnsensTheme().surfaceGradient),
      child: child,
    );
  }
}

class EnsensFittedPosArrowIcon extends StatelessWidget {
  const EnsensFittedPosArrowIcon({
    super.key,
    required this.arrowPos,
    required this.color,
    this.size = 14,
    this.heightFactor,
  });

  final num arrowPos;
  final double size;
  final Color color;
  final double? heightFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
        heightFactor: heightFactor ?? (arrowPos >= 0 ? 1.2 : 1.8),
        alignment: Alignment.bottomRight,
        child: FittedBox(
          child:
              EnsensPosArrowIcon(arrowPos: arrowPos, size: size, color: color),
        ));
  }
}

class EnsensFittedText extends StatelessWidget {
  const EnsensFittedText({
    super.key,
    required this.text,
    this.size,
    this.color,
    this.debug = false,
  });

  final String text;
  final double? size;
  final Color? color;
  final bool debug;

  @override
  Widget build(BuildContext context) {
    final Color primaryTextColor = Theme.of(context).colorScheme.inversePrimary;
    final Decoration? debugDecor = debug
        ? BoxDecoration(border: Border.all(color: Colors.blue, width: 2))
        : null;
    final TextStyle style =
        TextStyle(fontSize: size ?? 24, color: color ?? primaryTextColor);
    return FittedBox(
        fit: BoxFit.scaleDown,
        child:
            Container(decoration: debugDecor, child: Text(text, style: style)));
  }
}

class EnsensFractBox extends StatelessWidget {
  const EnsensFractBox({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.color,
    this.debug = false,
  });

  final Widget? child;
  final double? height;
  final double? width;
  final bool debug;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Decoration? debugDecor = debug
        ? BoxDecoration(border: Border.all(color: Colors.blue, width: 2))
        : null;
    return FractionallySizedBox(
      heightFactor: height,
      widthFactor: width,
      child: Container(decoration: debugDecor, color: color, child: child),
    );
  }
}

class EnsensPosArrowIcon extends StatelessWidget {
  const EnsensPosArrowIcon({
    super.key,
    required this.arrowPos,
    required this.color,
    required this.size,
  });

  final num arrowPos;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Map<int, double> arrowAngles = <int, double>{
      4: 0, // up
      3: 0.05,
      2: 0.10,
      1: 0.20,
      0: 0.25, // mid (right)
      -1: 0.30,
      -2: 0.40,
      -3: 0.45,
      -4: 0.5, // down
    };
    return EnsensArrowIcon(
        angle: arrowAngles[arrowPos]!, color: color, size: size);
  }
}

class EnsensArrowIcon extends StatelessWidget {
  const EnsensArrowIcon({
    super.key,
    required this.angle,
    required this.color,
    required this.size,
  });

  final double angle;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    const double baseUpAngle = -90 / 360;
    return RotationTransition(
      turns: AlwaysStoppedAnimation<double>(baseUpAngle + angle),
      child: Icon(Icons.arrow_right_alt_outlined, size: size, color: color),
    );
  }
}

class EnsensGauge extends StatelessWidget {
  const EnsensGauge({
    super.key,
    required this.value,
    required this.categoryWidth,
    required this.dataMap,
    required this.colorMap,
    this.isVertical = true,
    this.markerHeight,
    this.tag,
    this.tagSize,
  });

  final double value;
  final double categoryWidth;
  final Map<int, String> dataMap;
  final Map<String, Color> colorMap;
  final bool isVertical;
  final double? markerHeight;
  final String? tag;
  final double? tagSize;

  @override
  Widget build(BuildContext context) {
    final LinearMarkerPointer markerPointer = LinearWidgetPointer(
        position: LinearElementPosition.outside,
        offset: categoryWidth,
        value: value,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (tag != null) EnsensFittedText(text: tag!, size: tagSize),
            LinearShapePointer(
                value: value,
                offset: categoryWidth,
                width: categoryWidth,
                height: markerHeight ?? categoryWidth * 8),
          ],
        ));

    final double maximum = dataMap.keys.elementAt(dataMap.length - 1) +
        (dataMap.keys.elementAt(dataMap.length - 2) / 2);
    return SfLinearGauge(
      showLabels: false,
      showAxisTrack: false,
      showTicks: false,
      // isMirrored: true,
      orientation: isVertical
          ? LinearGaugeOrientation.vertical
          : LinearGaugeOrientation.horizontal,
      animationDuration: 0,
      maximum: maximum,
      ranges: List<LinearGaugeRange>.generate(colorMap.length, (int index) {
        final double start = dataMap.keys.elementAt(index).toDouble();
        final double next = index + 1 < colorMap.length
            ? dataMap.keys.elementAt(index + 1).toDouble()
            : maximum;
        final double end = start + next;
        return LinearGaugeRange(
            startValue: start,
            endValue: end,
            startWidth: categoryWidth,
            midWidth: categoryWidth,
            endWidth: categoryWidth,
            color: colorMap.values.elementAt(index));
      }),
      markerPointers: <LinearMarkerPointer>[markerPointer],
    );
  }
}

class EnsensValueChart extends StatelessWidget {
  const EnsensValueChart({
    super.key,
    required this.dataSource,
    required this.type,
    required this.minY,
    required this.maxY,
  });

  final List<ChartData> dataSource;
  final String type;
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final Color thinBorderColor = Theme.of(context).unselectedWidgetColor;
    final MajorGridLines thinGridLines = MajorGridLines(
        width: 1, color: EnsensTheme().light.unselectedWidgetColor);
    const MajorGridLines emptyGridLines = MajorGridLines(width: 0);

    const AxisLine emptyAxis = AxisLine(width: 0);
    const MajorTickLines emptyTics = MajorTickLines(size: 0);

    final LineSeries<ChartData, num> lineSeries = LineSeries<ChartData, num>(
      dataSource: dataSource,
      xValueMapper: (ChartData data, num index) => data.x,
      yValueMapper: (ChartData data, int index) => data.y,
      animationDuration: 0,
      color: EnsensTheme().airChartSeriesColor,
    );

    final ColumnSeries<ChartData, num> columnSeries =
        ColumnSeries<ChartData, num>(
      dataSource: dataSource,
      xValueMapper: (ChartData data, num index) => data.x,
      yValueMapper: (ChartData data, int index) => data.y,
      animationDuration: 0,
      color: EnsensTheme().pressureChartSeriesColor,
    );

    final ChartAxis xAxis = NumericAxis(
      axisLine: emptyAxis,
      majorGridLines: thinGridLines,
      majorTickLines: emptyTics,
      minimum: EnsensConfig().pressure.lowX.toDouble(),
      maximum: EnsensConfig().pressure.highX.toDouble(),
      interval: EnsensConfig().pressure.intervalX.toDouble(),
      // ignore: avoid_redundant_argument_values
      maximumLabels: 3,
    );

    final ChartAxis yAxis = NumericAxis(
      axisLine: emptyAxis,
      majorGridLines: emptyGridLines,
      majorTickLines: emptyTics,
      maximum: maxY,
      minimum: minY,
      interval: 20,
      maximumLabels: 4, // seems doesnt work
    );

    final CartesianSeries<ChartData, num> series =
        type == 'pressure' ? columnSeries : lineSeries;

    return EnsensFractBox(
      child: SfCartesianChart(
        plotAreaBorderColor: thinBorderColor,
        // X, Y
        primaryXAxis: xAxis,
        primaryYAxis: yAxis,
        // Data
        series: <CartesianSeries<ChartData, num>>[series],
      ),
    );
  }
}

class EnsensIndicatorPlank extends StatelessWidget {
  const EnsensIndicatorPlank(
      {super.key, required this.tag, required this.indicatorColor});

  final String tag;
  final Color indicatorColor;

  @override
  Widget build(BuildContext context) {
    TextStyle getTextStyle({required Color color}) =>
        TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500);

    final Card card = Card(
      shape: StadiumBorder(
        side: BorderSide(width: 6, color: indicatorColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: BorderedText(
            strokeCap: StrokeCap.butt,
            strokeColor: Colors.black,
            strokeWidth: (indicatorColor == Colors.black ||
                    indicatorColor == Colors.pink.shade900)
                ? 0
                : 1,
            child: Text(tag, style: getTextStyle(color: indicatorColor))),
      ),
    );
    return Row(children: <Widget>[
      Flexible(
        fit: FlexFit.tight,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0), child: card),
      ),
    ]);
  }
}
