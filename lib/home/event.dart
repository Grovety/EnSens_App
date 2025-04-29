part of 'bloc.dart';

@MappableClass()
final class HomeEvent with HomeEventMappable {
  const HomeEvent();
}

final class HomeDataUpdate extends HomeEvent {
  const HomeDataUpdate({
    required this.liveData,
    required this.previousLiveData,
  });
  final Map<String, num> liveData;
  final Map<String, num> previousLiveData;
}

final class HomeDataReset extends HomeEvent {
  const HomeDataReset();
}

final class GraphsUpdateRequested extends HomeEvent {
  const GraphsUpdateRequested();
}
