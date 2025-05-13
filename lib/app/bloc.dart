import 'package:dart_mappable/dart_mappable.dart';
import 'package:ensens_utils/device_api.dart';
import 'package:ensens_utils/ensens_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../home/bloc.dart';
import '../settings/bloc.dart';

part 'bloc.mapper.dart';
part 'state.dart';
part 'event.dart';

final class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc(
      {required SettingsBloc settingsBloc,
      required HomeBloc homeBloc,
      required DeviceAPI deviceAPI,
      required EnsensStorage storage})
      : _settingsBloc = settingsBloc,
        _homeBloc = homeBloc,
        _deviceAPI = deviceAPI,
        _storage = storage,
        super(const AppState()) {
    on<InitRequested>(_initRequrested);
    on<TryConnect>(_tryConnect);
    on<BleOff>(_bleOff);
    on<BleOn>(_bleOn);
    on<DeviceConnected>(_connected);
    on<DeviceDisconnected>(_disconnected);
    on<NewData>(_newData);
    on<ReadHistory>(_readHistory);
    on<TabChanged>(_tabChanged);
    on<ShowAppMessage>(_showAppMessage);

    if (_settingsBloc.state.settings == null) {
      ArgumentError('Settings was not initialized!');
    }

    add(const InitRequested());
  }
  final SettingsBloc _settingsBloc;
  final HomeBloc _homeBloc;
  final DeviceAPI _deviceAPI;
  final EnsensStorage _storage;

  bool _readyToReadHistoryFromDevice = false;
  bool _isConnecting = false;

  int? get _deviceId => state.deviceInfo?.id;

  Future<void> _initRequrested(
      InitRequested event, Emitter<AppState> emit) async {
    final int historyLen = await _storage.getHistoryLength();
    if (historyLen > 0) {
      // order history
      add(const ShowAppMessage(message: 'Updating history...'));
      final List<Map<String, dynamic>> all = await _storage.getHistory();
      await _storage.recreateHistory();
      await _storage.addHistory(all);
    }
    await _deviceAPI.init();
    ConnectionStatus previousEvent = ConnectionStatus.bleOff;
    _deviceAPI.connectionStatusStream.listen((ConnectionStatus event) async {
      if (_settingsBloc.state.settings == null) {
        previousEvent = event;
        return; // This can be after life reload.
      }
      if (previousEvent != event || event == ConnectionStatus.newData) {
        switch (event) {
          case ConnectionStatus.bleOff:
            add(const BleOff());
          case ConnectionStatus.bleOn:
            add(const BleOn());
          case ConnectionStatus.disconnected:
            add(const DeviceDisconnected());
            if (state.wirelessEnabled) {
              add(TryConnect(
                  searchPattern:
                      _settingsBloc.state.settings!.searchDevicePattern));
            }
          case ConnectionStatus.connected:
            if (state.wirelessEnabled) {
              add(const DeviceConnected());
            }
          case ConnectionStatus.newData:
            if (state.wirelessEnabled && state.deviceConnected) {
              add(const NewData());
            }
        }
      }
      previousEvent = event;
    });
  }

  void _bleOff(BleOff event, Emitter<AppState> emit) {
    // DISABLE INDICATOR
    emit(state.copyWith(wirelessEnabled: false));
    // DATA LOST
    add(const ShowAppMessage(message: 'Please enable Bluetooth.'));
    add(const DeviceDisconnected());
  }

  void _bleOn(BleOn event, Emitter<AppState> emit) {
    // ENABLE INDICATOR
    emit(state.copyWith(wirelessEnabled: true));
    add(const ShowAppMessage(message: 'Bluetooth enabled. Connecting...'));
    final String? searchPattern =
        _settingsBloc.state.settings?.searchDevicePattern;
    if (searchPattern == null) {
      return;
    }
    // TRY CONNECT
    add(TryConnect(searchPattern: searchPattern));
  }

  void _disconnected(DeviceDisconnected event, Emitter<AppState> emit) {
    final String deviceName = _deviceAPI.deviceName;
    // DISABLE INDICATORS
    emit(state.copyWith(deviceConnected: false, deviceInfo: null));
    _storage.deviceId = null; // update storage
    // DATA LOST
    add(ShowAppMessage(
        message:
            'Disconnected${deviceName.isNotEmpty ? ' from $deviceName' : ''}.'));
    _homeBloc.add(const HomeDataReset());
  }

  Future<void> _connected(DeviceConnected event, Emitter<AppState> emit) async {
    if (!state.wirelessEnabled) {
      throw ArgumentError('BLE disabled! Device cant be connected!');
    }
    final String name = _deviceAPI.deviceName;
    // CHECK DEVICE
    final bool exists = await _storage.deviceExists(name);
    final int? deviceId = exists
        ? await _storage.getDeviceId(name)
        : await _storage.addDevice(name);
    if (deviceId == null) {
      throw ArgumentError('Device ID not found and cant insert!');
    }
    _storage.deviceId = deviceId; // update storage
    // ENABLE INDICATORS
    emit(state.copyWith(
        deviceConnected: true,
        deviceInfo: DeviceInfo(id: deviceId, name: name)));
    add(ShowAppMessage(message: 'Connected to $name'));
    _readyToReadHistoryFromDevice = true;

    // LISTEN CONNECTION
    await _deviceAPI.listenDeviceConnection();
  }

  Future<void> _newData(NewData event, Emitter<AppState> emit) async {
    if (!state.deviceConnected) {
      throw ArgumentError('Device disconnected! Cant receive new data!');
    }
    final DeviceInfo? device = state.deviceInfo;
    if (device == null) {
      return;
    }

    // READ CURRENT LIVE DATA
    final Map<String, num> last = _deviceAPI.lastSensorData;
    final Map<String, num> previous = await _getPreviousLiveData();
    if (last.isEmpty) {
      return;
    }
    assert(last.containsKey('battery'));
    emit(state.copyWith(
        deviceInfo: device.copyWith(batteryLevel: last['battery']! as int)));

    _homeBloc.add(HomeDataUpdate(liveData: last, previousLiveData: previous));

    if (_readyToReadHistoryFromDevice) {
      add(const ReadHistory());
    }
  }

  Future<void> _readHistory(ReadHistory event, Emitter<AppState> emit) async {
    if (_deviceId == null) {
      return;
    }
    int historyLength = await _storage.getHistoryLength();
    final DateTime now = DateTime.now()
      ..copyWith(second: 0, millisecond: 0, microsecond: 0);
    // empty history case
    // download data from device, update storage and update graph
    if (historyLength == 0) {
      final DateTime fromTs = EnsensAlgorithms()
          .mostRecentDay(day: EnsensConfig().kHistoryMaxLenDays);
      await _storeHistoryFromDevice(fromTs, now);
      if (!_homeBloc.graphIsUpdating) {
        _homeBloc.add(const GraphsUpdateRequested());
        return;
      }
    }
    DateTime? lastHistoryTs = await _storage.getLastHistoryTs();
    DateTime? firstHistoryTs = await _storage.getFirstHistoryTs();

    final int maxDays = EnsensConfig().kHistoryMaxLenDays;
    final DateTime targetFrom =
        DateTime(now.year, now.month, now.day - maxDays);

    // outdated data:
    // delete old rows
    if (firstHistoryTs != null &&
        now.difference(firstHistoryTs).inDays > maxDays) {
      // delete all not relevant data
      // that starts from more than required days for display on graph
      await _deleteHistory(firstHistoryTs, targetFrom);
      historyLength = await _storage.getHistoryLength();
      lastHistoryTs = await _storage.getLastHistoryTs();
      firstHistoryTs = await _storage.getFirstHistoryTs();
    }

    if (lastHistoryTs == null || firstHistoryTs == null) {
      lastHistoryTs = now;
      firstHistoryTs = targetFrom;
    }
    // actual data:
    // read exist history and update it or graph if needed
    int minutesDiff = now.difference(lastHistoryTs).inMinutes;
    final List<ChartData>? prshChart = _homeBloc.state.pressureChartData;
    final bool noChartData = prshChart == null || prshChart.isEmpty;
    bool needsUpdateChart = noChartData && !_homeBloc.graphIsUpdating;
    if (!needsUpdateChart &&
        minutesDiff < EnsensConfig().kHistoryUpdateMinutes) {
      return; // debug: comment this line
    }
    // try read from device
    if (minutesDiff >= EnsensConfig().kHistoryUpdateMinutes) {
      await _storeHistoryFromDevice(lastHistoryTs, now);
      final DateTime previousTs = lastHistoryTs;
      lastHistoryTs = await _storage.getLastHistoryTs()
        ?..copyWith(second: 0, millisecond: 0, microsecond: 0);
      minutesDiff = lastHistoryTs!.difference(previousTs).inMinutes;
      if (minutesDiff > 0) {
        needsUpdateChart = true;
      }
    }

    if (!needsUpdateChart) {
      return;
    }
    while (_homeBloc.graphIsUpdating) {}
    _homeBloc.add(const GraphsUpdateRequested());
  }

  void _tabChanged(TabChanged event, Emitter<AppState> emit) {
    emit(state.copyWith(tab: event.tab));
  }

  void _showAppMessage(ShowAppMessage event, Emitter<AppState> emit) {
    emit(state.copyWith(lastMessage: event.message));
  }

  Future<void> _tryConnect(TryConnect event, Emitter<AppState> emit) async {
    if (_isConnecting && !event.forced) {
      return;
    }
    _isConnecting = true;
    await _deviceAPI.tryConnect(searchPattern: event.searchPattern);
    _isConnecting = false;
  }

  Future<int> _deleteHistory(DateTime from, DateTime to,
      {int? deviceId}) async {
    final List<Map<String, dynamic>> found = await _storage.getHistory(
        columns: <String>['_id'],
        deviceId: deviceId ?? _deviceId!,
        where: 'timestamp >= ${from.millisecondsSinceEpoch} AND '
            'timestamp <= ${to.millisecondsSinceEpoch}');
    final List<int> keys =
        found.map((Map<String, dynamic> e) => e['_id'] as int).toList();
    final int deleted = await _storage.deleteHistory(keys);
    return deleted;
  }

  Future<Map<String, num>> _getPreviousLiveData() async {
    final List<Map<String, dynamic>> raw = await _deviceAPI.getHistory(
        from: DateTime.now().subtract(
            Duration(minutes: EnsensConfig().kPreviousLiveDataMinutes)));
    if (raw.isEmpty) {
      return <String, num>{};
    }
    return raw.first.cast<String, num>();
  }

  Future<bool> _storeHistoryFromDevice(DateTime from, DateTime to) async {
    assert(_deviceId != null);
    _readyToReadHistoryFromDevice = false;
    add(const ShowAppMessage(message: 'Reading history from the sensor...'));
    final List<Map<String, dynamic>> newHistory =
        await _deviceAPI.getHistory(from: from, to: to);
    if (newHistory.isEmpty) {
      _readyToReadHistoryFromDevice = true;
      return false;
    }
    // Update device id. Remove seconds and milliseconds.
    newHistory.map((Map<String, dynamic> e) {
      final DateTime rawTs =
          DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int);
      final DateTime ts = rawTs.copyWith(second: 0, millisecond: 0);
      e['timestamp'] = ts.millisecondsSinceEpoch;
      e['hwId'] = _deviceId;
    }).toList();
    add(const ShowAppMessage(message: 'Updating history...'));
    await _storage.addHistory(newHistory);
    _readyToReadHistoryFromDevice = true;
    return true;
  }
}
