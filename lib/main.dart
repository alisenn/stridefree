import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'models.dart';
import 'screens/history.dart';
import 'screens/home.dart';
import 'screens/programs.dart';
import 'screens/settings.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();

  final settings = SettingsStore()..applyLanguage();
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
    // Dil değişince tüm ağaç yeniden kurulsun (metinler tx() ile anlık okunur).
    final lang = context.select<SettingsStore, String>((s) => s.language);
    ThemeData theme(Brightness b) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFB6F35C),
        brightness: b,
      ),
      cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 4)),
    );
    return MaterialApp(
      key: ValueKey(lang),
      title: 'StrideFree',
      locale: Locale(appLang.name),
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
  // Dil değişince ağaç yeniden kurulur; seçili sekme korunsun diye static.
  static int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecovery());
  }

  /// Uygulama antrenman sırasında kapandıysa yarım kalan antrenmanı kurtar.
  Future<void> _checkRecovery() async {
    final wc = context.read<WorkoutController>();
    final s = wc.recoverable;
    if (s == null || !mounted) return;
    final save = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.restore),
        title: Text(tx('Yarım kalan antrenman', 'Unfinished workout')),
        content: Text(
          '${tx('Uygulama antrenman sırasında kapanmış. Son kaydedilen hâli:', 'The app closed during a workout. Last saved state:')}\n\n'
          '${s.title}\n${fmtDuration(s.durationSec)} · '
          '${s.distanceKm.toStringAsFixed(2)} km · ${s.kcal.round()} kcal',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tx('Sil', 'Delete')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tx('Geçmişe kaydet', 'Save to history')),
          ),
        ],
      ),
    );
    wc.resolveRecovery(save: save ?? false);
  }

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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.directions_run),
            label: tx('Koşu', 'Run'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.view_timeline),
            label: tx('Programlar', 'Programs'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights),
            label: tx('Geçmiş', 'History'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person),
            label: tx('Profil', 'Profile'),
          ),
        ],
      ),
    );
  }
}
