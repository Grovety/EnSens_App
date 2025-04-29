part of 'bloc.dart';

@MappableClass()
final class SettingsState with SettingsStateMappable {
  const SettingsState({
    this.settings,
    this.lastMessage = '',
  });
  final Settings? settings;

  final String lastMessage;
}
