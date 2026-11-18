import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/history.dart';
import 'screens/home.dart';
import 'screens/programs.dart';
import 'screens/settings.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();

  final settings = SettingsStore();
  final history = HistoryStore();
  final devices = DeviceManager();
  final workout = WorkoutController(devices, settings, history);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: history),
        ChangeNotifierProvider.value(value: devices),
        ChangeNotifierProvider.value(value: workout),
        ChangeNotifierProvider(create: (_) => ProgramStore()),
      ],
      child: const StrideFreeApp(),
    ),
  );
}

class StrideFreeApp extends StatelessWidget {
  const StrideFreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFB6F35C),
        brightness: b,
      ),
      cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 4)),
    );
    return MaterialApp(
      title: 'StrideFree',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: const RootNav(),
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});
  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int index = 0;
  static const pages = [
    HomeScreen(),
    ProgramsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: IndexedStack(index: index, children: pages),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_run),
            label: 'Koşu',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_timeline),
            label: 'Programlar',
          ),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Geçmiş'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
