import 'package:ensens_utils/ensens_utils.dart';
import 'package:flutter/material.dart';

final class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator(
      {super.key, required this.active, required this.level});
  final bool active;
  final int? level;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final IconData icon = level != null
        ? EnsensAlgorithms().getBatteryLevelIcon(level!)
        : Icons.battery_unknown;
    final Color color = active && level != null
        ? theme.colorScheme.secondary
        : theme.unselectedWidgetColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        Text('${level ?? '--'}%', style: TextStyle(color: color)),
        Icon(icon, color: color),
      ],
    );
  }
}
