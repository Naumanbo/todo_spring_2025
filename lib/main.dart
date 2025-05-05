import 'package:flutter/material.dart';
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
      textTheme: GoogleFonts.sairaCondensedTextTheme(ThemeData.light().textTheme),
    ),
    ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.sairaCondensedTextTheme(ThemeData.dark().textTheme),
    ),
    ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.blue[100],
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.sairaCondensedTextTheme(ThemeData.light().textTheme),
    ),
    ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.orange[100],
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.sairaCondensedTextTheme(ThemeData.light().textTheme),
    ),
    ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.green[100],
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.sairaCondensedTextTheme(ThemeData.light().textTheme),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _themeIndex,
      builder: (context, themeIndex, child) {
        return MaterialApp(
          title: 'TODO Spring 2025',
          theme: _themes[themeIndex],
          navigatorObservers: [routeObserver],
          home: RouterScreen(
            onThemeChanged: (index) {
              _themeIndex.value = index;
            },
          ),
        );
      },
    );
  }
}