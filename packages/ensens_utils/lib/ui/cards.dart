import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../ensens_utils.dart';

class EnsensPressureCard extends StatelessWidget {
  const EnsensPressureCard({
    super.key,
    required this.valueLabel,
    required this.typeLabel,
    required this.arrowPos,
    required this.chartSource,
    this.minChartY,
    this.maxChartY,
  });

  final String? typeLabel;
  final String? valueLabel;
  final num? arrowPos;
  final List<ChartData>? chartSource;

  final double? minChartY;
  final double? maxChartY;

  bool get _debug => false;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    final Map<String, Widget> contentMap = <String, Widget>{
      'valueAndType': Row(
        children: <Widget>[
          _fractionalBox(Icon(Icons.speed, size: 22, color: primaryColor)),
          _fittedText(' $valueLabel ', size: 22),
          _fittedText('$typeLabel ', size: 16),
          if (arrowPos != null)
            _fractionalBox(EnsensFittedPosArrowIcon(
                arrowPos: arrowPos!, color: primaryColor)),
        ],
      ),
      'chart': _fractionalBox(EnsensValueChart(
        dataSource: chartSource ?? <ChartData>[],
        type: 'pressure',
        minY: minChartY,
        maxY: maxChartY,
      )),
    };

    return EnsensStackedCard(children: <Widget>[
      Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: _fractionalBox(
            FittedBox(fit: BoxFit.fitWidth, child: contentMap['valueAndType']),
          ),
        ),
      ),
      Align(
          alignment: Alignment.bottomCenter,
          child: _fractionalBox(contentMap['chart'], height: 0.8)),
    ]);
  }

  Widget _fittedText(String text, {double? size, Color? color}) =>
      EnsensFittedText(text: text, size: size, debug: _debug, color: color);

  Widget _fractionalBox(Widget? child, {double? height, double? width}) =>
      EnsensFractBox(height: height, width: width, debug: _debug, child: child);
}

class EnsensHumidityCard extends StatelessWidget {
  const EnsensHumidityCard({
    super.key,
    required this.humidityValue,
    required this.humidityValueLabel,
    required this.humidityTypeLabel,
    required this.dewPointValueLabel,
    required this.dewPointFormat,
    required this.arrowPos,
    required this.dataMap,
    required this.colorMap,
  });

  final num humidityValue;
  final String humidityTypeLabel;
  final String humidityValueLabel;
  final String dewPointValueLabel;
  final String dewPointFormat;
  final num? arrowPos;
  final Map<int, String> dataMap;
  final Map<String, Color> colorMap;

  bool get _debug => false;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Map<String, Widget> contentMap = <String, Widget>{
      'humidityAndType': Row(
        children: <Widget>[
          _fractionalBox(FittedBox(
              child: Icon(Icons.water_drop_rounded,
                  size: 22, color: primaryColor))),
          _fittedText(' $humidityValueLabel', size: 20),
          _fittedText('% ', size: 12),
          if (arrowPos != null)
            _fractionalBox(EnsensFittedPosArrowIcon(
                arrowPos: arrowPos!, color: primaryColor))
        ],
      ),
      'dewPointAndType': Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FittedBox(
              fit: BoxFit.fill,
              child: _fittedText('${'dew_point'.tr()}: ', size: 14)),
          _fittedText(dewPointValueLabel, size: 20),
          _fittedText(' $dewPointFormat', size: 12),
        ],
      )
    };

    final List<Widget> layout = <Widget>[
      Align(
          alignment: Alignment.centerLeft,
          child: _constrFittedBox(contentMap['humidityAndType'], wScale: 0.4)),
      Align(
          alignment: Alignment.centerRight,
          child: _constrFittedBox(contentMap['dewPointAndType'], wScale: 0.6)),
    ];
    return EnsensStackedCard(children: layout);
  }

  Widget _fittedText(String text, {double? size, Color? color}) =>
      EnsensFittedText(text: text, size: size, debug: _debug, color: color);

  Widget _fractionalBox(Widget? child, {double? height, double? width}) =>
      EnsensFractBox(height: height, width: width, debug: _debug, child: child);

  Widget _constrFittedBox(Widget? child,
      {double wScale = 0.5, double maxWidth = 180}) {
    return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: _fractionalBox(FittedBox(fit: BoxFit.fitWidth, child: child),
            width: wScale));
  }
}

class EnsensCard extends StatelessWidget {
  const EnsensCard({
    super.key,
    this.typeLabel,
    this.value,
    this.valueLabel,
    this.arrowPos,
    this.dataMap,
    this.colorMap,
    this.askOnPressed,
    this.debug = false,
  });

  final num? value;
  final String? typeLabel;
  final String? valueLabel;
  final num? arrowPos;
  final Map<int, String>? dataMap;
  final Map<String, Color>? colorMap;
  final void Function()? askOnPressed;
  final bool debug;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    Widget fittedText(String text, {double? size, Color? color}) =>
        EnsensFittedText(text: text, size: size, debug: debug, color: color);

    Widget fractionalBox(Widget? child, {double? height, double? width}) =>
        EnsensFractBox(
            height: height, width: width, debug: debug, child: child);

    final Map<String, Widget> contentMap = <String, Widget>{
      'type': fittedText(typeLabel ?? '--', size: 12),
      if (askOnPressed != null)
        'ask': EnsensSmallCardButton(
            onPressed: askOnPressed,
            child: fittedText('?', color: primaryColor)),
      'fakeCenter': debug ? const Placeholder() : const SizedBox(),
      'labelAndArrow': Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Flexible>[
          Flexible(flex: 5, child: fittedText(valueLabel ?? '--')),
          Flexible(
              child: arrowPos != null
                  ? fractionalBox(EnsensFittedPosArrowIcon(
                      arrowPos: arrowPos!, color: primaryColor))
                  : const SizedBox()),
        ],
      ),
      'verticalIndicator': value != null && colorMap != null && dataMap != null
          ? EnsensGauge(
              value: value!.toDouble(),
              colorMap: colorMap!,
              dataMap: dataMap!,
              categoryWidth: 8)
          : const SizedBox(),
    };

    final List<Widget> layout = <Widget>[
      Align(alignment: Alignment.topRight, child: contentMap['type']),
      Align(
          alignment: Alignment.bottomLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: fractionalBox(contentMap['ask'], height: 0.26, width: 0.24),
          )),
      Center(
          child:
              fractionalBox(contentMap['fakeCenter'], height: 0.3, width: 0.3)),
      Center(
          heightFactor: 1,
          widthFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: fractionalBox(contentMap['labelAndArrow'],
                height: 0.7, width: 0.7),
          )),
      Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: fractionalBox(
                FittedBox(
                    fit: BoxFit.fill, child: contentMap['verticalIndicator']),
                height: 0.54,
                width: 0.22),
          )),
    ];
    return EnsensStackedCard(children: layout);
  }
}

class EnsensSmallCardButton extends StatelessWidget {
  const EnsensSmallCardButton({
    super.key,
    required this.child,
    required this.onPressed,
  });

  final Widget child;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = Theme.of(context).colorScheme.secondaryContainer;
    return FloatingActionButton(
      heroTag: key,
      backgroundColor: bgColor,
      onPressed: onPressed,
      child: Padding(padding: const EdgeInsets.all(2.0), child: child),
    );
  }
}

class EnsensStackedCard extends StatelessWidget {
  const EnsensStackedCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Stack(children: children),
      ),
    );
  }
}
