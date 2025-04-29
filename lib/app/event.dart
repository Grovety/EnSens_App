part of 'bloc.dart';

@MappableClass()
final class AppEvent with AppEventMappable {
  const AppEvent();
}

final class InitRequested extends AppEvent {
  const InitRequested();
}

final class BleOff extends AppEvent {
  const BleOff();
}

final class BleOn extends AppEvent {
  const BleOn();
}

final class DeviceConnected extends AppEvent {
  const DeviceConnected();
}

final class DeviceDisconnected extends AppEvent {
  const DeviceDisconnected();
}

final class DataLost extends AppEvent {
  const DataLost();
}

final class NewData extends AppEvent {
  const NewData();
}

final class ReadHistory extends AppEvent {
  const ReadHistory();
}

final class TryConnect extends AppEvent {
  const TryConnect({
    required this.searchPattern,
    this.forced = false,
  });
  final String searchPattern;
  final bool forced;
}

final class ShowAppMessage extends AppEvent {
  const ShowAppMessage({required this.message});
  final String message;
}

final class TabChanged extends AppEvent {
  const TabChanged({required this.tab});
  final AppTab tab;
}
