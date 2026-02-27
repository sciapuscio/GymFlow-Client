import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/notification_service.dart';
import 'features/auth/auth_provider.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: const GymFlowApp(),
    ),
  );
}

class GymFlowApp extends StatefulWidget {
  const GymFlowApp({super.key});

  @override
  State<GymFlowApp> createState() => _GymFlowAppState();
}

class _GymFlowAppState extends State<GymFlowApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Build router ONCE — GoRouter uses refreshListenable to handle
    // redirects automatically without recreating the router object.
    final auth = context.read<AuthProvider>();
    _router = buildRouter(auth);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GymFlow',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00F5D4),
          secondary: const Color(0xFFFF6B35),
          surface: const Color(0xFF14141E),
          onPrimary: const Color(0xFF080810),
          onSecondary: Colors.white,
          onSurface: const Color(0xFFF0F0F0),
        ),
        scaffoldBackgroundColor: const Color(0xFF080810),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF0F0F0)),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF0F0F0)),
          bodyLarge: TextStyle(color: Color(0xFFF0F0F0)),
          bodyMedium: TextStyle(color: Color(0xFFBBBBBB)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF14141E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x1EFFFFFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x1EFFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF00F5D4), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          hintStyle: const TextStyle(color: Color(0xFF666666)),
          labelStyle: const TextStyle(color: Color(0xFF888888)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00F5D4),
            foregroundColor: const Color(0xFF080810),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5),
            elevation: 0,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF14141E),
          indicatorColor: const Color(0xFF00F5D4).withAlpha(38),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF14141E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0x1EFFFFFF)),
          ),
          margin: EdgeInsets.zero,
        ),
      ),
    );
  }
}
