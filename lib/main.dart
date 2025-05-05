import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:todo_spring_2025/router/router_screen.dart';
import 'package:todo_spring_2025/home/home_screen.dart'; // Add this import
import 'firebase_options.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  tz.initializeTimeZones();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ValueNotifier to manage the current theme index
  final ValueNotifier<int> _themeIndex = ValueNotifier<int>(0);

  // Define the themes
  final List<ThemeData> _themes = [
    ThemeData.light(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
    ),
    ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
    ),
    ThemeData.light(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue[100],
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.blue[100],
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
    ),
    ThemeData.light(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.purple,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.purple[100],
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.purple[100],
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
    ),
    ThemeData.light(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.orange[100],
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.orange[100],
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _themeIndex,
      builder: (context, themeIndex, child) {
        final isDark = themeIndex == 1;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark 
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                ),
          child: MaterialApp(
            title: 'TODO Spring 2025',
            theme: _themes[themeIndex],
            navigatorObservers: [routeObserver],
            home: RouterScreen(
              onThemeChanged: (index) {
                _themeIndex.value = index;
              },
            ),
          ),
        );
      },
    );
  }
}