part of 'bloc.dart';

@MappableClass()
final class HomeState with HomeStateMappable {
  const HomeState({
    this.liveData,
    this.previousLiveData,
    this.pressureChartData,
  });
  final Map<String, num>? liveData;
  final Map<String, num>? previousLiveData;
  final List<ChartData>? pressureChartData;
}
