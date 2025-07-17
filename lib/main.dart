// lib/main.dart (VERSÃO FINAL COM LÓGICA DE NAVEGAÇÃO CORRIGIDA)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Importações do Projeto
import 'package:geoforestcoletor/pages/menu/home_page.dart';
import 'package:geoforestcoletor/pages/menu/login_page.dart';
import 'package:geoforestcoletor/pages/menu/equipe_page.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/providers/team_provider.dart';
import 'package:geoforestcoletor/controller/login_controller.dart';
import 'package:geoforestcoletor/pages/projetos/lista_projetos_page.dart';
import 'package:geoforestcoletor/pages/menu/splash_page.dart';
import 'package:geoforestcoletor/providers/license_provider.dart';
import 'package:geoforestcoletor/pages/menu/paywall_page.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Adiciona um delay artificial para garantir que a splash screen seja visível
    // por um tempo mínimo, melhorando a experiência do usuário.
    await Future.delayed(const Duration(seconds: 2));

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );

   
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  void _retryInitialization() {
    setState(() {
      _initializationFuture = _initializeApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: ErrorScreen(
              message: "Failed to initialize app services:\n${snapshot.error.toString()}",
              onRetry: _retryInitialization,
            ),
          );
        }

        // A MUDANÇA ESTÁ AQUI:
        // Se a inicialização ainda não terminou, ele mostra a SplashPage.
        // Quando o Future termina, o FutureBuilder reconstrói e entra no if abaixo.
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: SplashPage(),
          );
        }

        // Se a inicialização estiver concluída com sucesso, mostra o app principal.
        return const MyApp();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginController()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => TeamProvider()),
        ChangeNotifierProvider(create: (_) => LicenseProvider()),
      ],
      child: MaterialApp(
        title: 'Geo Forest Analytics',
        debugShowCheckedModeBanner: false,
        theme: _buildThemeData(Brightness.light),
        darkTheme: _buildThemeData(Brightness.dark),
        // O MyApp agora é o único responsável por suas rotas.
        initialRoute: '/auth_check',
        routes: {
          '/auth_check': (context) => const AuthCheck(),
          '/equipe': (context) => const EquipePage(),
          '/home': (context) => const HomePage(title: 'Geo Forest Analytics'),
          '/lista_projetos': (context) => const ListaProjetosPage(title: 'Meus Projetos'),
          '/login': (context) => const LoginPage(),
          '/paywall': (context) => const PaywallPage(),
        },
        navigatorObservers: [MapProvider.routeObserver],
        builder: (context, child) {
          ErrorWidget.builder = (FlutterErrorDetails details) {
            debugPrint('Caught a Flutter error: ${details.exception}');
            return ErrorScreen(
              message: 'An unexpected error occurred.\nPlease restart the app.',
              onRetry: null,
            );
          };
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: child!,
          );
        },
      ),
    );
  }

  ThemeData _buildThemeData(Brightness brightness) {
    final baseColor = const Color(0xFF617359);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: baseColor, brightness: brightness),
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.light ? baseColor : Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: baseColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: Color(0xFF1D4433), fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: Color(0xFF1D4433)),
        bodyMedium: TextStyle(color: Color(0xFF1D4433)),
      ),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final loginController = context.watch<LoginController>();
    final licenseProvider = context.watch<LicenseProvider>();

    if (!loginController.isInitialized || licenseProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (loginController.isLoggedIn) {
      final license = licenseProvider.licenseData;
      final bool isLicenseOk = license != null && (license.status == 'ativa' || license.status == 'trial');
      return isLicenseOk ? const EquipePage() : const PaywallPage();
    } else {
      return const LoginPage();
    }
  }
}

class ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorScreen({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F4),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 60),
              const SizedBox(height: 20),
              Text('Application Error', style: TextStyle(color: Colors.red[700], fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 30),
              if (onRetry != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF617359), foregroundColor: Colors.white),
                  onPressed: onRetry,
                  child: const Text('Try Again'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
