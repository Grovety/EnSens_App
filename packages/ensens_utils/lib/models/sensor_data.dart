import 'package:dart_mappable/dart_mappable.dart';

part 'sensor_data.mapper.dart';

class ChartData {
  ChartData({required this.x, required this.y});
  final num x;
  final int y;
}

@MappableClass()
class SensorData with SensorDataMappable {
  SensorData({
    required this.hwId,
    required this.battery,
    required this.temperature,
    required this.voc,
    required this.co2,
    required this.iaq,
    required this.humidity,
    required this.pressure,
    required this.timestamp,
  });
  final int hwId;
  final int battery;
  final double temperature;
  final double voc;
  final double co2;
  final double iaq;
  final double humidity;
  final double pressure;
  final int timestamp;
}
