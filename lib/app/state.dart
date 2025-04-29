part of 'bloc.dart';

enum AppTab { home, settings }

// internal
@MappableClass()
final class DeviceInfo with DeviceInfoMappable {
  DeviceInfo({
    required this.id,
    required this.name,
    this.lastDataUpdateTs = 0,
    this.batteryLevel = 0,
  });
  final int id;
  final int batteryLevel;
  final String name;
  final int lastDataUpdateTs;
}

@MappableClass()
final class AppState with AppStateMappable {
  const AppState({
    this.wirelessEnabled = false,
    this.deviceConnected = false,
    this.tab = AppTab.home,
    this.lastMessage = '',
    this.deviceInfo,
  });

  final bool wirelessEnabled;
  final bool deviceConnected;
  final DeviceInfo? deviceInfo;

  final String lastMessage;
  final AppTab tab;
}
