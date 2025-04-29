part of 'bloc.dart';

@MappableClass()
final class SettingsEvent with SettingsEventMappable {
  const SettingsEvent();
}

final class InitRequested extends SettingsEvent {
  const InitRequested();
}

final class ShowAppMessage extends SettingsEvent {
  const ShowAppMessage({required this.message});
  final String message;
}

final class SettingsChanged extends SettingsEvent {
  const SettingsChanged({required this.settings});
  final Settings settings;
}
