import 'package:dart_mappable/dart_mappable.dart';

part 'settings.mapper.dart';

@MappableClass()
final class Settings with SettingsMappable {
  Settings({
    this.searchDevicePattern = '',
    this.temperatureCtoF = false,
    this.pressureHpaToMmhg = false,
  });

  final String searchDevicePattern;
  final bool temperatureCtoF;
  final bool pressureHpaToMmhg;
}
