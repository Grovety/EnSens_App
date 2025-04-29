import 'package:easy_localization/easy_localization.dart';
import 'package:ensens_utils/device_api.dart';
import 'package:ensens_utils/ensens_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../home/bloc.dart';
import '../home/page.dart';
import '../settings/bloc.dart';
import '../settings/page.dart';
import 'bloc.dart';
import 'widgets.dart';

final class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Duration snackBarDuration = Duration(seconds: 1);

    void appStateListener(BuildContext context, AppState state) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: snackBarDuration, content: Text(state.lastMessage)));
    }

    void settingsStateListener(BuildContext context, SettingsState state) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: snackBarDuration, content: Text(state.lastMessage)));
    }

    final EnsensStorage storage = context.read<EnsensStorage>();
    final HomeBloc homeBloc = HomeBloc(storage: storage);
    final SettingsBloc settingsBloc =
        SettingsBloc(storage: storage, homeBloc: homeBloc);

    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<SettingsBloc>.value(value: settingsBloc),
        BlocProvider<HomeBloc>.value(value: homeBloc),
        BlocProvider<AppBloc>.value(
            value: AppBloc(
                settingsBloc: settingsBloc,
                homeBloc: homeBloc,
                deviceAPI: context.read<DeviceAPI>(),
                storage: storage)),
      ],
      child: MultiBlocListener(
        listeners: <SingleChildWidget>[
          BlocListener<AppBloc, AppState>(
              listenWhen: (AppState previous, AppState current) =>
                  current.lastMessage.isNotEmpty &&
                  previous.lastMessage != current.lastMessage,
              listener: appStateListener),
          BlocListener<SettingsBloc, SettingsState>(
              listenWhen: (SettingsState previous, SettingsState current) =>
                  current.lastMessage.isNotEmpty &&
                  previous.lastMessage != current.lastMessage,
              listener: settingsStateListener),
        ],
        child: const Scaffold(
          appBar: _AppBar(),
          body: _Body(),
          bottomNavigationBar:
              _NavBar(maxHeight: 60, iconSize: 28, selectedFontSize: 12),
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(_) =>
      BlocBuilder<AppBloc, AppState>(buildWhen: _buildWhen, builder: _builder);

  Widget _builder(BuildContext context, AppState state) {
    final int? level = state.deviceInfo?.batteryLevel;
    return AppBar(actions: <Widget>[
      Icon(Icons.bluetooth, color: _getStatusColor(state.wirelessEnabled)),
      Icon(Icons.thermostat, color: _getStatusColor(state.deviceConnected)),
      BatteryIndicator(
          active: state.deviceConnected,
          level: state.deviceConnected ? level : null),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 12)),
    ]);
  }

  Color _getStatusColor(bool enabled) {
    final Color enabledColor = Colors.lightGreen.shade500;
    final Color disabledColor = Colors.red.shade400;
    return enabled ? enabledColor : disabledColor;
  }

  bool _buildWhen(AppState previous, AppState current) =>
      (previous.deviceConnected != current.deviceConnected) ||
      (previous.wirelessEnabled != current.wirelessEnabled) ||
      (previous.deviceInfo?.batteryLevel != current.deviceInfo?.batteryLevel);
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final AppTab tab = context.select((AppBloc bloc) => bloc.state.tab);
    final Settings? settings =
        context.select((SettingsBloc bloc) => bloc.state.settings);

    final List<Widget> pages = <Widget>[
      if (settings != null) const HomePage() else const SizedBox(),
      const SettingsPage()
    ];
    return EnsensGradientBackground(
        child: IndexedStack(
      index: tab.index,
      children: pages
          .map((Widget page) =>
              Padding(padding: const EdgeInsets.all(4), child: page))
          .toList(),
    ));
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.maxHeight,
    required this.iconSize,
    required this.selectedFontSize,
  });

  final double maxHeight;
  final double iconSize;
  final double selectedFontSize;

  @override
  Widget build(BuildContext context) {
    final AppTab tab = context.select((AppBloc bloc) => bloc.state.tab);
    void onTap(int index) =>
        context.read<AppBloc>().add(TabChanged(tab: AppTab.values[index]));

    final ColorScheme theme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: BottomNavigationBar(
          onTap: onTap,
          currentIndex: tab.index,
          selectedItemColor: theme.primary,
          unselectedItemColor: theme.outline,
          iconSize: iconSize,
          selectedFontSize: selectedFontSize,
          unselectedFontSize: selectedFontSize,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: const Icon(Icons.home), label: 'home'.tr()),
            BottomNavigationBarItem(
                icon: const Icon(Icons.settings), label: 'settings'.tr()),
          ]),
    );
  }
}
