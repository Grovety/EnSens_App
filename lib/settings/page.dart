import 'package:easy_localization/easy_localization.dart';
import 'package:ensens_utils/ensens_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/bloc.dart';
import 'bloc.dart';

const List<String> _cardTypes = <String>[
  'search_device_pattern',
  'temperature_format',
  'pressure_format',
];

final class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SettingsBloc, SettingsState>(builder: _contentBuilder);

  Widget _contentBuilder(BuildContext context, SettingsState state) {
    if (state.settings == null) {
      return _emptyPage();
    }
    final Map<String, Widget> contentMap = <String, Widget>{
      for (final String type in _cardTypes)
        type: _CardBuilder(type: type, settings: state.settings!)
    };
    return _ContentPage(contentMap: contentMap);
  }

  _ContentPage _emptyPage() =>
      const _ContentPage(contentMap: <String, Widget>{});
}

class _ContentPage extends StatelessWidget {
  const _ContentPage({required this.contentMap});
  final Map<String, Widget> contentMap;

  bool get _debug => false;

  @override
  Widget build(BuildContext context) {
    if (contentMap.isNotEmpty) {
      assert(contentMap.containsKey('search_device_pattern'));
      assert(contentMap.containsKey('temperature_format'));
      assert(contentMap.containsKey('pressure_format'));
    }
    final List<Widget> layout = _buildLayout();
    return ListView.separated(
      itemCount: layout.length,
      itemBuilder: (_, int index) => layout[index],
      separatorBuilder: (_, __) => const SizedBox(height: 4),
    );
  }

  List<Widget> _buildLayout() {
    if (contentMap.isEmpty) {
      return _cardTypes.map((String e) => _emptyCard()).toList();
    }
    return contentMap.entries.map((MapEntry<String, Widget> e) {
      final Widget key = _fittedText(e.key.tr(), size: 16);
      final Widget value =
          Padding(padding: const EdgeInsets.all(2.0), child: e.value);
      final Widget content = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(flex: 2, child: Padding(
            padding: const EdgeInsets.all(4),
            child: key,
          )),
          Padding(
            padding: const EdgeInsets.all(2.0),
            child: _constrFittedBox(
                e.key == 'search_device_pattern'
                    ? SizedBox(height: 46, width: 80, child: value)
                    : value),
          ),
        ],
      );
      return Card(child: content);
    }).toList();
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

  Card _emptyCard() =>
      const Card(child: Center(child: EnsensFittedText(text: '--')));
}

class _CardBuilder extends StatelessWidget {
  const _CardBuilder({required this.type, required this.settings});
  final String type;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final AppBloc appBloc = context.read<AppBloc>();
    final SettingsBloc bloc = context.read<SettingsBloc>();
    const BorderRadius toggleBorderRadius =
        BorderRadius.all(Radius.circular(8));
    final EnsensLabels labels = EnsensLabels();
    switch (type) {
      case 'search_device_pattern':
        return TextField(
            controller:
                TextEditingController(text: settings.searchDevicePattern),
            onSubmitted: (String value) {
              bloc.add(SettingsChanged(
                  settings: settings.copyWith(searchDevicePattern: value)));
              appBloc.add(TryConnect(searchPattern: value, forced: true));
            });

      case 'temperature_format':
        return ToggleButtons(
          borderRadius: toggleBorderRadius,
          isSelected: _boolToList(settings.temperatureCtoF),
          onPressed: (int index) => bloc.add(SettingsChanged(
              settings: settings.copyWith(temperatureCtoF: index > 0))),
          children:
              _toggleContents(<String>[labels.celsius, labels.farengheit]),
        );
      case 'pressure_format':
        return ToggleButtons(
          isSelected: _boolToList(settings.pressureHpaToMmhg),
          borderRadius: toggleBorderRadius,
          onPressed: (int index) => bloc.add(SettingsChanged(
              settings: settings.copyWith(pressureHpaToMmhg: index > 0))),
          children: _toggleContents(<String>[labels.hPa, labels.mmHg]),
        );
      default:
    }
    return const Placeholder();
  }

  List<bool> _boolToList(bool value) =>
      value ? <bool>[false, true] : <bool>[true, false];

  List<Widget> _toggleContents(List<String> labels) => labels
      .map((String e) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: EnsensFittedText(text: e, size: 14)))
      .toList();
}
