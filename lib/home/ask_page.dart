import 'package:easy_localization/easy_localization.dart';
import 'package:ensens_utils/ensens_utils.dart';
import 'package:flutter/material.dart';

class EnsensAskPage extends StatelessWidget {
  const EnsensAskPage(
      {super.key,
      required this.type,
      required this.levelMap,
      required this.colorMap});

  final String type;
  final Map<int, String> levelMap;
  final Map<String, Color> colorMap;
  @override
  Widget build(BuildContext context) {
    final Color white = Theme.of(context).colorScheme.secondary;

    final List<List<Widget>> tableRows =
        List<List<Widget>>.generate(levelMap.length, (int index) {
      final Map<String, Widget> map = _buildTableRowData(index);
      final List<Widget> aligned = <Widget>[
        Align(
            heightFactor: 2.2,
            alignment: Alignment.bottomRight,
            child: map['value']),
        Center(child: map['colorBox']),
        Align(alignment: Alignment.centerLeft, child: map['textLevel']),
      ];
      return aligned
          .map((Widget e) =>
              Padding(padding: const EdgeInsets.all(4.0), child: e))
          .toList();
    });

    final Map<String, Widget> contentMap = <String, Widget>{
      'desc': Text('${type}_desc'.tr()),
      'table': Table(
          columnWidths: <int, TableColumnWidth>{
            for (int i = 0; i < 3; i++) i: const IntrinsicColumnWidth()
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: tableRows.reversed
              .map((List<Widget> e) => TableRow(children: e))
              .toList()),
    };
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: white)),
          title: Text(type.toUpperCase(), style: TextStyle(color: white))),
      body: EnsensGradientBackground(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: ListView(
              children: <Widget>[contentMap['desc']!, contentMap['table']!]
                  .map((Widget e) => Card(
                      child: Padding(
                          padding: const EdgeInsets.all(4.0), child: e)))
                  .toList()),
        ),
      ),
    );
  }

  Map<String, Widget> _buildTableRowData(int index) {
    final MapEntry<int, String> levelEntry = levelMap.entries.elementAt(index);
    final MapEntry<String, Color> colorEntry =
        colorMap.entries.elementAt(index);

    final Map<String, Widget> content = <String, Widget>{
      'value': Text(levelEntry.key.toString()),
      'colorBox': EnsensFractBox(
          width: 1.1,
          color: colorEntry.value,
          child: const SizedBox(height: 40)),
      'textLevel': Text(levelEntry.value.tr()),
    };
    const BoxConstraints constraints =
        BoxConstraints(minWidth: 10, maxWidth: 100);
    content.entries.map((MapEntry<String, Widget> e) =>
        MapEntry<String, Widget>(
            e.key, ConstrainedBox(constraints: constraints, child: e.value)));
    return content;
  }
}
