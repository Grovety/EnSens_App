import 'package:flutter/material.dart';

final class EnsensTheme {
  LinearGradient get surfaceGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFE5E5FF), Color(0xFFDCDCDC)],
      );

  LinearGradient get airQualityGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF63B4FF), Color(0xFF364CC3)],
      );

  ThemeData get light {
    const Color darkBlue = Color(0xFF364CC3);
    return ThemeData(
      appBarTheme: const AppBarTheme(color: darkBlue),
      colorScheme: ColorScheme.light(
        inversePrimary: Colors.black,
        primary: darkBlue,
        outline: Colors.grey.shade600,
        secondary: Colors.white,
        surface: Colors.blueGrey.shade50,
        secondaryContainer: const Color(0xFFE0E5E6),
      ),
      unselectedWidgetColor: Colors.grey.shade400,
    );
  }

  Color get airChartSeriesColor => const Color(0xFFFF00FF);
  Color get pressureChartSeriesColor => light.primaryColor;

  Map<String, Map<String, Color>> get colorMap => <String, Map<String, Color>>{
        'iaq': _iaqColorMap,
        'voc': _vocColorMap,
        'co2': _co2ColorMap,
        'humidity': _humidityColorMap,
      };

  final Map<String, Color> _humidityColorMap = <String, Color>{
    'tooDry': Colors.lightGreenAccent,
    'comfortable': Colors.green,
    'normal': Colors.green.shade700,
    'uncomfortable': Colors.blue.shade900,
    'dangerous': Colors.purple.shade900,
  };

  final Map<String, Color> _iaqColorMap = <String, Color>{
    'good': Colors.green,
    'average': Colors.limeAccent,
    'littleBad': Colors.orange,
    'bad': Colors.red,
    'worse': Colors.pink.shade900,
    'veryBad': Colors.black,
  };

  final Map<String, Color> _vocColorMap = <String, Color>{
    'excellent': Colors.green,
    'good': Colors.green.shade200,
    'moderate': Colors.yellow,
    'poor': Colors.orange,
    'unhealthy': Colors.red,
  };

  final Map<String, Color> _co2ColorMap = <String, Color>{
    'healthy': Colors.blue,
    'comfort': Colors.green,
    'normal': Colors.yellow,
    'poor': Colors.orange.shade400,
    'unhealthy': Colors.orange.shade800,
    'risky': Colors.orange.shade900,
    'critical': Colors.red,
  };
}
