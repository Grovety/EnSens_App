import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ensens_utils.dart';

final class EnsensAlgorithms {
  Map<String, Map<int, String>> get levelMap => <String, Map<int, String>>{
        'iaq': _iaqLevelMap,
        'voc': _vocLevelMap,
        'co2': _co2LevelMap,
        'humidity': _humidityLevelMap,
      };

  IconData getBatteryLevelIcon(num currentLevel) {
    final bool correctValue = currentLevel >= 0 || currentLevel <= 100;
    if (!correctValue) {
      throw ArgumentError('Incorrect battery level value!');
    }
    final Map<int, IconData> batteryStages = <int, IconData>{
      0: Icons.battery_0_bar,
      10: Icons.battery_1_bar,
      30: Icons.battery_2_bar,
      40: Icons.battery_3_bar,
      50: Icons.battery_4_bar,
      70: Icons.battery_5_bar,
      80: Icons.battery_6_bar,
      100: Icons.battery_full,
    };
    final num pos = getNearestKey(batteryStages.keys, currentLevel.toInt());
    return batteryStages[pos]!;
  }

  num? getAnglePos(String type, num? current, num? previous) {
    if (current == null || previous == null) {
      return null;
    }
    final num diff = current - previous;
    final Map<String, Map<double, int>> angleDiffMaps =
        <String, Map<double, int>>{
      'temperature': _temperatureDiffAngles,
      'iaq': _iaqDiffAngles,
      'voc': _vocDiffAngles,
      'co2': _co2DiffAngles,
      'humidity': _humidityDiffAngles,
      'pressure': _pressureDiffAngles,
    };
    final num key = getNearestKey(angleDiffMaps[type]!.keys, diff);
    final num pos = angleDiffMaps[type]![key]!;
    return pos;
  }

  String getHumidityLevelType(num humidity) {
    final num pos = getNearestKey(_humidityLevelMap.keys, humidity.toInt());
    return _humidityLevelMap[pos]!;
  }

  DateTime mostRecentWeekday({DateTime? date, int? weekday}) {
    final DateTime from = date ?? DateTime.now();
    return DateTime(
        from.year, from.month, from.day - (from.weekday - (weekday ?? 0)) % 7);
  }

  DateTime mostRecentDay({DateTime? date, int? day}) {
    final DateTime from = date ?? DateTime.now();
    return DateTime(from.year, from.month, from.day - (day ?? 0));
  }

  num getNearestKey(Iterable<num> array, num value) {
    final List<num> sortedArray = array.toList()..sort();
    num closest = array.first;
    num bestClosenessDiff = (closest - value).abs();
    for (final num element in sortedArray.skip(1)) {
      final num closenessDiff = (element - value).abs();
      if (closenessDiff > bestClosenessDiff) {
        continue;
      }
      closest = element;
      bestClosenessDiff = closenessDiff;
    }
    return closest;
  }

  num getTemperatureCtoF(num temperatureC) => (temperatureC * 9 / 5) + 32;
  num getPressureHpaToMmhg(num pressureHpa) => pressureHpa * 0.75;

  num getDewPoint(num temperature, num humidityPercent) {
    // constant coeffiecients
    const num a = 17.27;
    const num b = 237.7;
    // func
    final num tRh =
        a * temperature / (b + temperature) + math.log(humidityPercent / 100);
    // dew point
    final num dewPoint = (b * tRh) / (a - tRh);
    return dewPoint;
  }

  SensorData getRandomData(int deviceId, DateTime ts) {
    const double temperature = 23;
    const double humidity = 30;
    const double pressure = 1000;
    const double co2 = 700;
    const double voc = 100;
    const double iaq = 50;
    const int battery = 50;
    final math.Random random = math.Random();
    final DateTime timestamp =
        DateTime(ts.year, ts.month, ts.day, ts.hour, ts.minute);
    return SensorData(
      hwId: deviceId,
      battery: battery + random.nextInt(50),
      temperature: temperature + random.nextInt(2) + random.nextDouble(),
      voc: voc.toInt() + random.nextInt(100) + random.nextDouble(),
      co2: co2.toInt() + random.nextInt(200) + random.nextDouble(),
      iaq: iaq.toInt() + random.nextInt(100) + random.nextDouble(),
      humidity: humidity + random.nextInt(2) + random.nextDouble(),
      pressure: pressure + random.nextInt(100) + random.nextDouble(),
      timestamp: timestamp
          .add(Duration(seconds: random.nextInt(60)))
          .millisecondsSinceEpoch,
    );
  }

  List<SensorData> getRandomDataPeriod(int deviceId, DateTime from, DateTime to,
      {int minuteStep = 15}) {
    final DateTime now = DateTime.now();
    final List<SensorData> allData = <SensorData>[];
    if (to.difference(from).inMinutes <= 15) {
      minuteStep = 5;
    }
    // Fill previous days
    for (int month = from.month; month <= to.month; month++) {
      for (int day = from.day; day < to.day; day++) {
        for (int hour = 0; hour < 24; hour++) {
          for (int minute = 0; minute < 60; minute += minuteStep) {
            final SensorData data = getRandomData(
                deviceId, DateTime(now.year, now.month, day, hour, minute));
            allData.add(data);
          }
        }
      }
    }
    // Fill current day
    for (int hour = from.hour; hour < to.hour; hour++) {
      for (int minute = 0; minute <= 60; minute += minuteStep) {
        final SensorData data = getRandomData(
            deviceId, DateTime(to.year, to.month, to.day, hour, minute));
        allData.add(data);
      }
    }
    // Fill current hour
    for (int minute = from.minute; minute < to.minute; minute += minuteStep) {
      final SensorData data = getRandomData(
          deviceId, DateTime(to.year, to.month, to.day, to.hour, minute));
      allData.add(data);
    }
    return allData;
  }

  final Map<int, String> _iaqLevelMap = <int, String>{
    0: 'good',
    51: 'average',
    101: 'littleBad',
    151: 'bad',
    201: 'worse',
    301: 'veryBad',
  };

  final Map<int, String> _vocLevelMap = <int, String>{
    0: 'excellent',
    65: 'good',
    220: 'moderate',
    660: 'poor',
    2200: 'unhealthy',
  };

  final Map<int, String> _co2LevelMap = <int, String>{
    0: 'healthy',
    400: 'comfort',
    1000: 'normal',
    2500: 'poor',
    4000: 'unhealthy',
    8000: 'risky',
    10000: 'critical',
  };

  final Map<int, String> _humidityLevelMap = <int, String>{
    0: 'tooDry',
    10: 'comfortable',
    25: 'normal',
    50: 'uncomfortable',
    85: 'dangerous',
  };

  final Map<double, int> _temperatureDiffAngles = <double, int>{
    0.8: 4, // up
    0.4: 3,
    0.6: 2,
    0.2: 1,
    0.0: 0, // mid (right)
    -0.2: -1,
    -0.6: -2,
    -0.4: -3,
    -0.8: -4, // down
  };

  final Map<double, int> _iaqDiffAngles = <double, int>{
    4: 4, // up
    3: 3,
    2: 2,
    1: 1,
    0.0: 0, // mid (right)
    -1: -1,
    -2: -2,
    -3: -3,
    -4: -4, // down
  };

  final Map<double, int> _vocDiffAngles = <double, int>{
    5: 4, // up
    3.75: 3,
    2.5: 2,
    1.25: 1,
    0.0: 0, // mid (right)
    -1.25: -1,
    -2.5: -2,
    -3.75: -3,
    -5: -4, // down
  };

  final Map<double, int> _co2DiffAngles = <double, int>{
    10: 4, // up
    7.5: 3,
    5: 2,
    2.5: 1,
    0.5: 0, // mid (right)
    -0.5: -1,
    -2.5: -2,
    -5: -3,
    -10: -4, // down
  };

  final Map<double, int> _humidityDiffAngles = <double, int>{
    0.8: 4, // up
    0.4: 3,
    0.6: 2,
    0.2: 1,
    0.0: 0, // mid (right)
    -0.2: -1,
    -0.6: -2,
    -0.4: -3,
    -0.8: -4, // down
  };

  // hpa
  final Map<double, int> _pressureDiffAngles = <double, int>{
    0.43: 4, // up
    0.32: 3,
    0.21: 2,
    0.1: 1,
    0.0: 0, // mid (right)
    -0.1: -1,
    -0.21: -2,
    -0.32: -3,
    -0.43: -4, // down
  };
}
