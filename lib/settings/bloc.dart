import 'package:dart_mappable/dart_mappable.dart';
import 'package:ensens_utils/ensens_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../home/bloc.dart';

part 'bloc.mapper.dart';
part 'state.dart';
part 'event.dart';

final class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required EnsensStorage storage, required HomeBloc homeBloc})
      : _storage = storage,
        _homeBloc = homeBloc,
        super(const SettingsState()) {
    on<InitRequested>(_initRequrested);
    on<SettingsChanged>(_settingsChanged);
    on<ShowAppMessage>(_showAppMessage);

    add(const InitRequested());
  }

  final EnsensStorage _storage;
  final HomeBloc _homeBloc;

  Future<void> _initRequrested(
      InitRequested event, Emitter<SettingsState> emit) async {
    final Settings settings = await _storage.getSettings();
    emit(state.copyWith(settings: settings, lastMessage: ''));
    add(SettingsChanged(settings: settings));
  }

  Future<void> _settingsChanged(
      SettingsChanged event, Emitter<SettingsState> emit) async {
    assert(state.settings != null);
    if (state.settings == event.settings) {
      return;
    }

    final EnsensLabels labels = EnsensLabels();
    final Settings newSettings = event.settings;
    String message = '';
    if (state.settings?.pressureHpaToMmhg != newSettings.pressureHpaToMmhg) {
      final String format =
          newSettings.pressureHpaToMmhg ? labels.mmHg : labels.hPa;
      message = 'Pressure format: $format';
      _homeBloc.add(const GraphsUpdateRequested());
    } else if (state.settings?.temperatureCtoF != newSettings.temperatureCtoF) {
      final String format =
          newSettings.temperatureCtoF ? labels.farengheit : labels.celsius;
      message = 'Temperature format: $format';
    } else if (state.settings?.searchDevicePattern !=
        newSettings.searchDevicePattern) {
      final String newSearchPattern = newSettings.searchDevicePattern;
      message = 'Device search pattern: $newSearchPattern';
    }
    await _storage.updateSettings(newSettings);
    emit(state.copyWith(settings: newSettings, lastMessage: message));
  }

  void _showAppMessage(ShowAppMessage event, Emitter<SettingsState> emit) {
    emit(state.copyWith(lastMessage: event.message));
  }
}
