import 'dart:async';
import 'dart:developer';
import 'dart:ffi';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

import 'ensens_utils.dart';

enum ConnectionStatus { bleOff, bleOn, disconnected, connected, newData }

abstract class DeviceAPI {
  const DeviceAPI();
  Stream<ConnectionStatus> get connectionStatusStream;
  Future<void> init();
  Future<void> tryConnect({required String searchPattern});
  Future<void> listenDeviceConnection();
  Future<List<Map<String, dynamic>>> getHistory(
      {required DateTime from, DateTime? to});
  Map<String, num> get lastSensorData;
  String get deviceName;
}

final class EnsensDeviceAPI extends DeviceAPI {
  EnsensDeviceAPI()
      : _controller = StreamController<ConnectionStatus>.broadcast(),
        _rawEntryData = SensorData(
                hwId: 0,
                battery: 0,
                temperature: 0,
                voc: 0,
                co2: 0,
                iaq: 0,
                humidity: 0,
                pressure: 0,
                timestamp: 0)
            .toMap()
            .cast<String, num>() {
    final EnsensBleConfig config = EnsensBleConfig();
    _mapCharacteristicToData = <String, String>{
      config.uuidBattery: 'battery',
      config.uuidTemperature: 'temperature',
      config.uuidCo2: 'co2',
      config.uuidVoc: 'voc',
      config.uuidIaq: 'iaq',
      config.uuidHumidity: 'humidity',
      config.uuidPressure: 'pressure',
      config.uuidCurrentTime: 'timestamp',
    };
    _mapReadAPI = <String, num Function(List<int> data, {int offset})>{
      'timestamp': (List<int> data, {int offset = 0}) =>
          _listToByteData(data).getInt32(offset, Endian.little),
      'battery': (List<int> data, {int offset = 0}) => data[offset],
      'temperature': (List<int> data, {int offset = 0}) =>
          _listToByteData(data).getInt16(offset, Endian.little) / 100,
      'co2': (List<int> data, {int offset = 0}) =>
          _listToByteData(data).getUint16(offset, Endian.little),
      'voc': (List<int> data, {int offset = 0}) =>
          _listToByteData(data).getUint16(offset, Endian.little),
      'iaq': (List<int> data, {int offset = 0}) =>
          _listToByteData(data).getUint16(offset, Endian.little),
      'humidity': (List<int> data, {int offset = 0}) =>
          _listToByteData(data).getUint16(offset, Endian.little) / 100,
      'pressure': (List<int> data, {int offset = 0}) =>
          _listToByteData(data).getInt32(offset, Endian.little) / 100,
    };

    _typeOffsetsMap = <String, int>{
      'timestamp': sizeOf<Uint32>(),
      'pressure': sizeOf<Int32>(),
      'temperature': sizeOf<Uint16>(),
      'co2': sizeOf<Uint16>(),
      'voc': sizeOf<Uint16>(),
      'iaq': sizeOf<Uint16>(),
      'humidity': sizeOf<Uint16>(),
    };
  }

  BluetoothDevice? _currentDevice;
  final Map<String, num> _rawEntryData;
  final StreamController<ConnectionStatus> _controller;

  BluetoothCharacteristic? _historyCharacteristicRead;
  BluetoothCharacteristic? _historyCharacteristicWrite;

  late Map<String, num Function(List<int> data, {int offset})> _mapReadAPI;
  late Map<String, String> _mapCharacteristicToData;
  late Map<String, int> _typeOffsetsMap;

  void _disconnect() {
    if (_currentDevice != null && _currentDevice!.isConnected) {
      _currentDevice!.disconnect();
    }
    _controller.add(ConnectionStatus.disconnected);
    _currentDevice = null;
  }

  @override
  Stream<ConnectionStatus> get connectionStatusStream =>
      _controller.stream.asBroadcastStream();

  @override
  String get deviceName =>
      _currentDevice != null ? _currentDevice!.advName : '';

  @override
  Map<String, num> get lastSensorData => _rawEntryData;

  @override
  Future<void> init() async {
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (state == BluetoothAdapterState.on) {
        _controller.add(ConnectionStatus.bleOn);
      } else if (state != BluetoothAdapterState.turningOn) {
        _controller.add(ConnectionStatus.bleOff);
        if (_currentDevice != null) {
          _disconnect();
        }
      }
    });
  }

  @override
  Future<void> tryConnect({required String searchPattern}) async {
    if (_currentDevice != null) {
      _disconnect();
    }
    // Check permissions
    await Geolocator.checkPermission();
    await Geolocator.requestPermission();
    // Wait for Bluetooth enabled & permission granted
    await FlutterBluePlus.adapterState
        .where(
            (BluetoothAdapterState state) => state == BluetoothAdapterState.on)
        .first;
    _controller.add(ConnectionStatus.bleOn);

    try {
      await FlutterBluePlus.startScan(withKeywords: <String>[searchPattern]);
    } catch (e) {
      await FlutterBluePlus.startScan(withKeywords: <String>[searchPattern]);
    }
    
    final BluetoothDevice device = await _waitCorrectDevice(searchPattern);
    await FlutterBluePlus.stopScan();

    try {
      await device.connect(timeout: const Duration(seconds: 20));
      // Wait until connection
      await device.connectionState
          .where((BluetoothConnectionState state) =>
              state == BluetoothConnectionState.connected)
          .first;
    } catch (e) {
      tryConnect(searchPattern: searchPattern); // Recursive call
      return;
    }

    _currentDevice = device;
    _controller.add(ConnectionStatus.connected);
    if (kDebugMode) {
      print('${_currentDevice!.remoteId}: "${_currentDevice!.advName}" found!');
    }
  }

  Future<BluetoothDevice> _waitCorrectDevice(String searchPattern) async {
    final List<ScanResult> devices = await FlutterBluePlus.scanResults
        .where((List<ScanResult> results) => results.isNotEmpty)
        .first;
    return devices.last.device;
  }

  @override
  Future<void> listenDeviceConnection() async {
    if (_currentDevice == null) {
      throw ArgumentError('No current device!');
    }
    // Wait until connection
    await _currentDevice!.connectionState
        .where((BluetoothConnectionState state) =>
            state == BluetoothConnectionState.connected)
        .first;
    final List<BluetoothService> services =
        await _currentDevice!.discoverServices();

    final EnsensBleConfig config = EnsensBleConfig();
    for (final BluetoothService service in services) {
      for (final BluetoothCharacteristic characteristic
          in service.characteristics) {
        final String uuid = characteristic.uuid.toString();
        if (uuid == config.uuidCurrentTime) {
          // Write current time
          await _setCurrentTime(characteristic);
          continue;
        }
        if (uuid == config.uuidHistoryRead) {
          _historyCharacteristicRead = characteristic;
          continue;
        }
        if (uuid == config.uuidHistoryWrite) {
          _historyCharacteristicWrite = characteristic;
          continue;
        }
        if (!_mapCharacteristicToData.containsKey(uuid)) {
          continue;
        }
        final String type = _mapCharacteristicToData[uuid]!;
        if (!_rawEntryData.containsKey(type)) {
          continue;
        }
        List<int> rawData = <int>[];
        try {
          rawData = await characteristic.read();
        } catch (e) {
          if (_currentDevice != null && _currentDevice!.isDisconnected) {
            _disconnect();
          }
          return;
        }
        final num data = _mapReadAPI[type]!(rawData);
        _rawEntryData[type] = data;
        final StreamSubscription<List<int>> subscription =
            characteristic.onValueReceived.listen(
          (List<int> event) async {
            if (event.isEmpty) {
              return;
            }
            final String type = _mapCharacteristicToData[uuid]!;
            final num? currentValue = _rawEntryData[type];
            final num newData = _mapReadAPI[type]!(event);
            if (currentValue != newData) {
              _rawEntryData[type] = newData;
              _controller.add(ConnectionStatus.newData);
            }
          },
        );
        try {
          await characteristic.setNotifyValue(true);
        } catch (_) {
          if (_currentDevice != null && _currentDevice!.isDisconnected) {
            _disconnect();
          }
        }
        if (_currentDevice != null) {
          _currentDevice!.cancelWhenDisconnected(subscription);
        }
      }
    }
    _rawEntryData['timestamp'] =
        DateTime.now().copyWith(millisecond: 0).millisecondsSinceEpoch;
    _controller.add(ConnectionStatus.newData);
    final StreamSubscription<BluetoothConnectionState> subscription =
        _currentDevice!.connectionState
            .listen((BluetoothConnectionState state) async {
      if (state == BluetoothConnectionState.disconnected) {
        _disconnect();
      }
    });
    _currentDevice!
        .cancelWhenDisconnected(subscription, delayed: true, next: true);
  }

  Future<void> _setCurrentTime(BluetoothCharacteristic characteristic) async {
    if (_currentDevice != null && !_currentDevice!.isConnected) {
      return;
    }
    // Write current time
    final DateTime now = DateTime.now();
    const int fractions256 = 0;
    const int reason = 0;
    final List<int> request = _uint16toBytes(now.year) +
        <int>[
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
          now.weekday,
          fractions256,
          reason
        ];
    try {
      if (_currentDevice != null && _currentDevice!.isConnected) {
        await characteristic.write(request);
      }
    } catch (_) {} // ignore 'GATT_UNLIKELY'
    try {
      // Check
      final List<int> response = await characteristic.read();
      if (!const ListEquality<int>().equals(
          request.take(request.length - 2).toList(),
          response.take(request.length - 2).toList())) {
        throw ArgumentError(
            'Failed to write requested period! Response: $response');
      }
    } catch (error) {
      if (kDebugMode) {
        print(error);
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory(
      {required DateTime from, DateTime? to}) async {
    final List<Map<String, dynamic>> empty = <Map<String, dynamic>>[];
    if (_historyCharacteristicRead == null ||
        _historyCharacteristicWrite == null ||
        _currentDevice == null) {
      return empty;
    }
    final EnsensConfig config = EnsensConfig();
    to ??= DateTime.now();

    final Duration diff = to.difference(from);
    final int diffMinutes = diff.inMinutes;

    final bool isLivePreviousData = from.day == to.day && // 5 minutes
        diffMinutes == config.kPreviousLiveDataMinutes;
    final bool isSingleHistory = from.day == to.day && // 15 minutes
        diffMinutes == config.kHistoryUpdateMinutes;

    if (isLivePreviousData || isSingleHistory) {
      const int start = 0;
      final int end = isLivePreviousData ? 0 : 1;
      final List<int> raw = await _requestHistory(start, end);
      final List<Map<String, num>> parsed = _parseHistory(raw);
      return parsed;
    }

    final int neededCountEntries = diffMinutes ~/ 15;
    final int mtu = await _currentDevice!.requestMtu(512); // try set maximum
    final int bytesLenFromPartRequest = mtu - mtu % 2;
    final int bytesStep = EnsensBleConfig().historyBytesLen;
    final int partCountEntries = bytesLenFromPartRequest ~/ bytesStep;
    final int requestsCount = neededCountEntries ~/ partCountEntries;
    final List<int> allEntries = <int>[];

    int start = 0;
    int end = 0;
    for (int i = 0; i < requestsCount; i++) {
      end = neededCountEntries - (i * partCountEntries);
      start = end - partCountEntries;
      final List<int> rawPart = await _requestHistory(start, end);
      if (rawPart.isNotEmpty && (rawPart.length < bytesStep)) {
        log('Warning! '
            'Part: Failed to read required amount of history entries! '
            'Skipping...');
        continue;
      }
      allEntries.addAll(rawPart);
    }
    if (allEntries.isNotEmpty && (allEntries.length < bytesStep)) {
      throw UnimplementedError(
          'Failed to read required amount of history entries!');
    }
    final List<Map<String, num>> parsed = _parseHistory(allEntries);
    if (parsed.isNotEmpty) {
      final DateTime historyFrom = DateTime.fromMillisecondsSinceEpoch(
          parsed.first['timestamp']! as int);
      final DateTime historyTo =
          DateTime.fromMillisecondsSinceEpoch(parsed.last['timestamp']! as int);
      if (to.difference(historyFrom).isNegative) {
        throw UnimplementedError(
            "History 'from' is bigger than requested time!");
      }
      if (to.difference(historyTo).isNegative &&
          to.difference(historyTo).inMinutes > 4) {
        throw UnimplementedError("History 'to' is bigger than requested time!");
      }
      if (historyTo.difference(historyFrom).isNegative) {
        throw UnimplementedError('Incorrect order of data!');
      }
    }
    return parsed;
  }

  Future<List<int>> _requestHistory(int startId, int endId) async {
    final List<int> request = _uint16toBytes(endId) + _uint16toBytes(startId);
    List<int> response = <int>[];
    try {
      await _historyCharacteristicWrite!.write(request);
      response = await _historyCharacteristicWrite!.read();
      if (!const ListEquality<int>().equals(request, response)) {
        throw ArgumentError(
            'Failed to write requested period! Requres: $request. Response: $response');
      }
      response = await _historyCharacteristicRead!.read();
    } catch (error) {
      if (kDebugMode) {
        print(error);
      }
      if (_currentDevice != null && _currentDevice!.isDisconnected) {
        _disconnect();
        return <int>[];
      }
    }
    return response;
  }

  List<Map<String, num>> _parseHistory(List<int> data) {
    if (data.isEmpty) {
      return <Map<String, num>>[];
    }

    final int bytesStep = EnsensBleConfig().historyBytesLen;

    final DateTime now = DateTime.now();
    if (data.length == bytesStep) {
      final Map<String, num> entry = _parseHistoryEntry(data, 0);
      entry['timestamp'] =
          now.copyWith(second: 0, millisecond: 0).millisecondsSinceEpoch;
      return <Map<String, num>>[entry];
    }

    final List<Map<String, num>> entries = <Map<String, num>>[];
    final int targetEntriesCount = data.length ~/ bytesStep;

    final int minutesStep = EnsensConfig().kHistoryUpdateMinutes;

    // Process entries from the end
    // because we have to update the timestamp relatively current time.
    Duration diff;
    for (int i = 0; i < targetEntriesCount; i++) {
      final int offset = data.length - (bytesStep * i) - bytesStep;
      final Map<String, num> entry = _parseHistoryEntry(data, offset);

      /* TO BE RETURNED
      final int currentMs = (entry['timestamp']! as int) * 1000;
      final DateTime currentTs = DateTime.fromMillisecondsSinceEpoch(currentMs);
      */

      DateTime currentTs;
      diff = Duration(minutes: minutesStep * i);
      currentTs = now.copyWith(millisecond: 0).subtract(diff);

      entry['timestamp'] =
          currentTs.copyWith(millisecond: 0).millisecondsSinceEpoch;
      entries.add(entry);
    }
    return entries.reversed.toList();
  }

  Map<String, num> _parseHistoryEntry(List<int> data, int offset) {
    final Map<String, num> entry = <String, num>{};
    int offsetInside = 0;
    for (final String key in _typeOffsetsMap.keys) {
      entry[key] = _mapReadAPI[key]!(data, offset: offset + offsetInside);
      offsetInside += _typeOffsetsMap[key]!;
    }
    entry['hwId'] = 0;
    entry['battery'] = 0;
    return entry;
  }

  Uint8List _uint16toBytes(int value) =>
      Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);

  ByteData _listToByteData(List<int> value) =>
      ByteData.view(Uint8List.fromList(value).buffer);
}

final class FakeDeviceAPI extends DeviceAPI {
  FakeDeviceAPI()
      : _status = ConnectionStatus.bleOff,
        _controller = StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _status;
  final StreamController<ConnectionStatus> _controller;

  @override
  Stream<ConnectionStatus> get connectionStatusStream =>
      _controller.stream.asBroadcastStream();

  @override
  Future<void> init() async {
    _status = ConnectionStatus.bleOn;
    await Future<void>.delayed(const Duration(seconds: 1));
    Timer.periodic(
      const Duration(seconds: 2),
      (Timer timer) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        switch (_status) {
          case ConnectionStatus.bleOff:
            _status = ConnectionStatus.bleOn;
          case ConnectionStatus.bleOn:
            break;
          case ConnectionStatus.disconnected:
            _status = ConnectionStatus.connected;
          case ConnectionStatus.connected:
            _status = ConnectionStatus.newData;
          case ConnectionStatus.newData:
            break;
        }
        _controller.add(_status);
      },
    );
  }

  @override
  String get deviceName => 'Fake device';

  @override
  Future<void> tryConnect({required String searchPattern}) async {
    await _controller.stream
        .where((ConnectionStatus event) =>
            event.index >= ConnectionStatus.bleOn.index)
        .first;
    _status = ConnectionStatus.connected;
    _controller.add(_status);
  }

  @override
  Map<String, num> get lastSensorData => EnsensAlgorithms()
      .getRandomData(0, DateTime.now())
      .toMap()
      .cast<String, num>();

  @override
  Future<void> listenDeviceConnection() async {
    // Wait connection
    await _controller.stream
        .where((ConnectionStatus event) =>
            event.index >= ConnectionStatus.connected.index)
        .first;
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory(
      {required DateTime from, DateTime? to}) async {
    final List<SensorData> converted =
        EnsensAlgorithms().getRandomDataPeriod(0, from, to ??= DateTime.now());
    return converted.map((SensorData e) => e.toMap()).toList();
  }
}
