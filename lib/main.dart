import 'dart:developer';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_yaml/easy_localization_yaml.dart';
import 'package:ensens_utils/device_api.dart';

import 'package:ensens_utils/ensens_utils.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import 'app/page.dart';
import 'home/bloc.dart'; // root page here

Future<void> main(List<String> args) async {
  // prepare
  await _ensurePlugins();
  _runObservers();

  // run localized app
  const Locale enLocale = Locale('en');
  final EnsensStorage storage = EnsensStorage();
  final DeviceAPI deviceAPI =
      Platform.isAndroid ? EnsensDeviceAPI() : FakeDeviceAPI();

  await storage.init();
  runApp(
    EasyLocalization(
      supportedLocales: const <Locale>[enLocale],
      assetLoader: const YamlAssetLoader(directory: 'assets/translations'),
      path: 'unused',
      fallbackLocale: enLocale,
      child: _App(storage: storage, deviceAPI: deviceAPI),
    ),
  );
}

final class _App extends StatelessWidget {
  const _App({required this.storage, required this.deviceAPI});
  final EnsensStorage storage;
  final DeviceAPI deviceAPI;
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <SingleChildWidget>[
        RepositoryProvider<EnsensStorage>.value(value: storage),
        RepositoryProvider<DeviceAPI>.value(value: deviceAPI),
      ],
      child: MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: const RootPage(), // from app/page.dart
        theme: EnsensTheme().light,
      ),
    );
  }
}

Future<void> _ensurePlugins() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
}

void _runObservers() {
  Bloc.observer = const _BlocObserver();
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      log(details.exceptionAsString(), stackTrace: details.stack);
    }
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) {
      log(error.toString(), stackTrace: stack);
    }
    return true;
  };
}

class _BlocObserver extends BlocObserver {
  const _BlocObserver();

  @override
  void onTransition(
      Bloc<dynamic, dynamic> bloc, Transition<dynamic, dynamic> transition) {
    super.onTransition(bloc, transition);
    if (kDebugMode) {
      if (transition.currentState is HomeState) {
        final HomeState homeState = transition.currentState as HomeState;
        // todo: simplify exclude chartData
        if (_needsSimpleHomeState(homeState)) {
          _simpleHomeStateLog(bloc, homeState);
          return;
        }
      }
      if (transition.nextState is HomeState) {
        final HomeState homeState = transition.nextState as HomeState;
        // todo: simplify exclude chartData
        if (_needsSimpleHomeState(homeState)) {
          _simpleHomeStateLog(bloc, homeState);
          return;
        }
      }
      log('onTransition(${bloc.runtimeType}, $transition)');
    }
  }

  bool _needsSimpleHomeState(HomeState homeState) {
    return homeState.pressureChartData != null &&
        homeState.pressureChartData!.isNotEmpty;
  }

  void _simpleHomeStateLog(Bloc<dynamic, dynamic> bloc, HomeState homeState) {
    log('onTransition(${bloc.runtimeType}, ${homeState.liveData},'
        ' ${homeState.previousLiveData}, homeState.pressureChartData = [...])');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      log('onError(${bloc.runtimeType}, $error, $stackTrace)');
    }
    super.onError(bloc, error, stackTrace);
  }
}
