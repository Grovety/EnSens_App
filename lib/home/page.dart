import 'package:ensens_utils/ensens_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/bloc.dart';
import '../settings/bloc.dart';
import 'ask_page.dart';
import 'bloc.dart';

const List<String> _cardTypes = <String>[
  'temperature',
  'iaq',
  'voc',
  'co2',
  'pressure',
  'humidity'
];

final class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AppBloc, AppState>(buildWhen: _buildWhen, builder: _builder);

  Widget _builder(BuildContext context, AppState appState) {
    // Checks every state of bloc.
    final bool connected = appState.deviceConnected;
    if (!connected) {
      return _emptyPage();
    }
    return BlocBuilder<HomeBloc, HomeState>(builder: _liveContentBuilder);
  }

  Widget _liveContentBuilder(BuildContext context, HomeState state) {
    if (state.liveData == null) {
      return _emptyPage();
    }
    final Map<String, List<ChartData>?> chartData = <String, List<ChartData>?>{
      'pressure': state.pressureChartData
    };
    final Map<String, Widget> contentMap = <String, Widget>{
      for (final String type in _cardTypes)
        type: _CardBuilder(
          type: type,
          currentData: state.liveData!,
          previousData: state.previousLiveData,
          chartData: chartData,
        ),
    };
    return _ContentPage(contentMap: contentMap);
  }

  bool _buildWhen(AppState previous, AppState current) =>
      previous.deviceConnected != current.deviceConnected;

  _ContentPage _emptyPage() =>
      const _ContentPage(contentMap: <String, Widget>{});
}

class _ContentPage extends StatelessWidget {
  const _ContentPage({required this.contentMap});
  final Map<String, Widget> contentMap;

  @override
  Widget build(BuildContext context) {
    if (contentMap.isNotEmpty) {
      assert(contentMap.containsKey('temperature'));
      assert(contentMap.containsKey('iaq'));
      assert(contentMap.containsKey('voc'));
      assert(contentMap.containsKey('co2'));
      assert(contentMap.containsKey('humidity'));
      assert(contentMap.containsKey('pressure'));
    }
    const double kCommonHeight = 128.0;
    final List<Widget> layout = _buildLayout(kCommonHeight);

    return ListView.separated(
      itemCount: layout.length,
      itemBuilder: (_, int index) => layout[index],
      separatorBuilder: (_, __) => const SizedBox(height: 4),
    );
  }

  Card _emptyCard() =>
      const Card(child: Center(child: EnsensFittedText(text: '--')));

  List<Widget> _buildLayout(double kCommonHeight) {
    return <Widget>[
      SizedBox(
        height: kCommonHeight,
        child: Row(
          children: <String>['temperature', 'iaq']
              .map((String e) => Flexible(child: contentMap[e] ?? _emptyCard()))
              .toList(),
        ),
      ),
      SizedBox(
          height: kCommonHeight,
          child: Row(
              children: <String>['voc', 'co2']
                  .map((String e) =>
                      Flexible(child: contentMap[e] ?? _emptyCard()))
                  .toList())),
      SizedBox(
          height: kCommonHeight * 0.4,
          child: contentMap['humidity'] ?? _emptyCard()),
      SizedBox(
          height: kCommonHeight * 1.4,
          child: contentMap['pressure'] ?? _emptyCard()),
    ];
  }
}

class _CardBuilder extends StatelessWidget {
  const _CardBuilder({
    required this.type,
    required this.currentData,
    required this.previousData,
    required this.chartData,
  });

  final String type;
  final Map<String, num> currentData;
  final Map<String, num>? previousData;
  final Map<String, List<ChartData>?> chartData;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SettingsBloc, SettingsState>(builder: _builder);

  Widget _builder(BuildContext context, SettingsState state) {
    final HomeBloc homeBloc = context.read<HomeBloc>();
    final Settings? settings = state.settings;
    final EnsensAlgorithms algs = EnsensAlgorithms();

    final Map<String, Map<String, Color>> colorMap = EnsensTheme().colorMap;
    final Map<String, Map<int, String>> levelMap = algs.levelMap;

    final Map<String, num> converted =
        homeBloc.getConvertedLiveData(settings, currentData);

    final String typeLabel = homeBloc.getTypeLabel(settings, type);
    final String valueLabel = homeBloc.getValueLabel(type, converted[type]);

    final num? arrowPos =
        algs.getAnglePos(type, currentData[type], previousData?[type]);

    void onAskPressed(String type) {
      final EnsensAskPage page = EnsensAskPage(
          type: type, levelMap: levelMap[type]!, colorMap: colorMap[type]!);
      Navigator.push(context,
          MaterialPageRoute<Widget>(builder: (BuildContext context) => page));
    }

    final List<int> chartBounds = homeBloc.getPressureChartBoundaries(settings);
    assert(chartBounds.length == 2);

    if (type == 'pressure') {
      assert(chartData.containsKey('pressure'));
      final List<ChartData>? source = chartData['pressure'];
      return EnsensPressureCard(
        valueLabel: valueLabel,
        typeLabel: typeLabel,
        arrowPos: arrowPos,
        chartSource: source,
        minChartY: chartBounds[0].toDouble(),
        maxChartY: chartBounds[1].toDouble(),
      );
    } else if (type == 'humidity') {
      return EnsensHumidityCard(
          humidityValue: converted[type]!,
          humidityValueLabel: valueLabel,
          humidityTypeLabel: '% ',
          dewPointValueLabel:
              homeBloc.getValueLabel('dewPoint', converted['dewPoint']),
          dewPointFormat: homeBloc.getFormatOfType(settings, 'dewPoint'),
          colorMap: colorMap[type]!,
          dataMap: levelMap[type]!,
          arrowPos: arrowPos);
    }
    return EnsensCard(
      typeLabel: typeLabel,
      valueLabel: valueLabel,
      value: converted[type],
      colorMap: colorMap[type],
      dataMap: levelMap[type],
      arrowPos: arrowPos,
      askOnPressed: type != 'temperature' ? () => onAskPressed(type) : null,
    );
  }
}
