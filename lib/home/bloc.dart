import 'package:dart_mappable/dart_mappable.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ensens_utils/ensens_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'bloc.mapper.dart';
part 'state.dart';
part 'event.dart';

@MappableClass()
final class HistoryTables with HistoryTablesMappable {
  HistoryTables({this.lastTwoDays});
  final List<Map<String, Object?>>? lastTwoDays;
}

final class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required EnsensStorage storage})
      : _storage = storage,
        super(const HomeState()) {
    on<GraphsUpdateRequested>(_graphsUpdateRequested);
    on<HomeDataUpdate>(_dataUpdate);
    on<HomeDataReset>(_dataReset);
  }

  final EnsensStorage _storage;

  bool _graphIsUpdating = false;
  bool get graphIsUpdating => _graphIsUpdating;

  DateTime get historyTsFrom {
    final DateTime now = DateTime.now();
    final int maxDays = EnsensConfig().kHistoryMaxLenDays;
    return DateTime(now.year, now.month, now.day - maxDays);
  }

  Future<void> _graphsUpdateRequested(
      GraphsUpdateRequested event, Emitter<HomeState> emit) async {
    if (_graphIsUpdating) {
      return;
    }
    assert(_storage.deviceId != null);
    final List<Map<String, dynamic>> data = await _storage.getHistory(
        columns: <String>['timestamp', 'pressure'],
        deviceId: _storage.deviceId,
        where: 'timestamp >= ${historyTsFrom.millisecondsSinceEpoch}'
            ' AND timestamp <= ${DateTime.now().millisecondsSinceEpoch}');

    if (data.isEmpty) {
      return;
    }
    const String type = 'pressure';
    assert(data.first.keys.contains(type));
    _graphIsUpdating = true;
    final Settings settings = await _storage.getSettings();

    final DateTime now = DateTime.now();
    final DateTime firstDate =
        DateTime.fromMillisecondsSinceEpoch(data.first['timestamp'] as int);
    final DateTime lastDate =
        DateTime.fromMillisecondsSinceEpoch(data.last['timestamp'] as int);
    assert(now.difference(lastDate).inDays <= 0);
    assert(
        now.difference(firstDate).inDays <= EnsensConfig().kHistoryMaxLenDays);

    bool isSameDay(DateTime e) =>
        (now.year == e.year) && (now.month == e.month) && (now.day == e.day);

    final List<ChartData> chartData = <ChartData>[];
    DateTime? prevTs;
    for (final Map<String, dynamic> e in data) {
      final DateTime ts =
          DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int)
              .copyWith(second: 0, millisecond: 0);
      if ((prevTs != null) &&
          (ts.hour == prevTs.hour) &&
          (ts.difference(prevTs).inMinutes < 60)) {
        prevTs = ts;
        continue;
      }
      final num x = isSameDay(ts) ? ts.hour : ts.hour - 24;
      final num rawY = e[type] as num;
      final int y = _pressureHpaToMmhg(settings, rawY);
      prevTs = ts;
      chartData.add(ChartData(x: x, y: y));
    }
    emit(state.copyWith(pressureChartData: chartData));
    _graphIsUpdating = false;
  }

  Future<void> _dataUpdate(
      HomeDataUpdate event, Emitter<HomeState> emit) async {
    final Map<String, num> newData = event.liveData;
    if (newData.isEmpty) {
      return;
    }
    assert(newData.containsKey('temperature'));
    assert(newData.containsKey('humidity'));
    if (newData['temperature'] != null && newData['humidity'] != null) {
      newData['dewPoint'] = EnsensAlgorithms()
          .getDewPoint(newData['temperature']!, newData['humidity']!) as double;
    }
    emit(state.copyWith(
        liveData: event.liveData,
        previousLiveData: event.previousLiveData.isNotEmpty
            ? event.previousLiveData
            : state.previousLiveData));
  }

  Future<void> _dataReset(HomeDataReset event, Emitter<HomeState> emit) async {
    emit(state.copyWith(
        liveData: null, previousLiveData: null, pressureChartData: null));
  }

  // min, max
  List<int> getPressureChartBoundaries(Settings? settings) {
    final PressureParams conf = EnsensConfig().pressure;
    assert(settings != null);
    final bool hpaToMmhg = settings!.pressureHpaToMmhg;
    return hpaToMmhg
        ? <int>[conf.lowMmHg, conf.highMmHg]
        : <int>[conf.lowHpa, conf.highHpa];
  }

  Map<String, num> getConvertedLiveData(
      Settings? settings, Map<String, num> data) {
    if (settings == null) {
      return <String, num>{};
    }
    final EnsensAlgorithms algs = EnsensAlgorithms();
    final Map<String, num> newData = Map<String, num>.from(data);
    final num convertedT = (settings.temperatureCtoF
        ? algs.getTemperatureCtoF(newData['temperature']!)
        : newData['temperature']!);
    final num convertedDP = (settings.temperatureCtoF
        ? algs.getTemperatureCtoF(newData['dewPoint']!)
        : newData['dewPoint']!);
    final num convertedP = (settings.pressureHpaToMmhg
        ? algs.getPressureHpaToMmhg(newData['pressure']!)
        : newData['pressure']!);
    newData['temperature'] = convertedT.toInt();
    newData['iaq'] = newData['iaq']!.toInt();
    newData['voc'] = newData['voc']!.toInt();
    newData['co2'] = newData['co2']!.toInt();
    newData['pressure'] = convertedP;
    newData['dewPoint'] = convertedDP;
    return newData;
  }

  String getFormatOfType(Settings? settings, String type) {
    if (settings == null) {
      return '';
    }
    final String formatT = settings.temperatureCtoF
        ? EnsensLabels().farengheit
        : EnsensLabels().celsius;
    final String formatP =
        settings.pressureHpaToMmhg ? EnsensLabels().mmHg : EnsensLabels().hPa;
    final Map<String, String> map = <String, String>{
      'temperature': formatT,
      'pressure': formatP,
      'voc': 'ppb'.tr(),
      'co2': 'ppm'.tr(),
      'dewPoint': formatT,
    };
    return map.containsKey(type) ? map[type]! : '';
  }

  String getTypeLabel(Settings? settings, String type) {
    if (type == 'temperature' || type == 'pressure') {
      return getFormatOfType(settings, type);
    } else if (type == 'iaq') {
      return type.tr().toUpperCase();
    }
    final String label = '${type.tr().toUpperCase()}, ';
    return label + getFormatOfType(settings, type);
  }

  String getValueLabel(String type, num? value) {
    if (value == null) {
      return '--';
    }
    if (type == 'dewPoint') {
      return value.toStringAsFixed(1);
    }
    if (type == 'humidity') {
      return value.toStringAsFixed(0);
    }
    if (type == 'temperature') {
      return '${value > 0 ? '+' : ''}$value';
    }
    return value.toInt().toString();
  }

  int _pressureHpaToMmhg(Settings? settings, num value) {
    assert(settings != null);
    return (settings!.pressureHpaToMmhg
            ? EnsensAlgorithms().getPressureHpaToMmhg(value)
            : value)
        .toInt();
  }
}
