// lib/main.dart (VERSÃO ATUALIZADA COM ROTEAMENTO POR CARGO)

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
// <<< 1. IMPORTAR A NOVA TELA DO GERENTE >>>
import 'package:geoforestcoletor/pages/gerente/gerente_home_page.dart';


// PONTO DE ENTRADA PRINCIPAL DO APP (Sem alterações)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const AppServicesLoader());
}

// AppServicesLoader (Sem alterações)
class AppServicesLoader extends StatefulWidget {
  const AppServicesLoader({super.key});

  @override
  State<AppServicesLoader> createState() => _AppServicesLoaderState();
}

class _AppServicesLoaderState extends State<AppServicesLoader> {
  late Future<void> _servicesInitializationFuture;

  @override
  void initState() {
    super.initState();
    _servicesInitializationFuture = _initializeRemainingServices();
  }

  Future<void> _initializeRemainingServices() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      const androidProvider = kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity;
      await FirebaseAppCheck.instance.activate(androidProvider: androidProvider);
      print("Firebase App Check ativado com sucesso.");
      await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
      );
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    } catch (e) {
      print("!!!!!! ERRO NA INICIALIZAÇÃO DOS SERVIÇOS: $e !!!!!");
      rethrow;
    }
  }

  void _retryInitialization() {
    setState(() {
      _servicesInitializationFuture = _initializeRemainingServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _servicesInitializationFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: ErrorScreen(
              message: "Falha ao inicializar os serviços do aplicativo:\n${snapshot.error.toString()}",
              onRetry: _retryInitialization,
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: SplashPage(),
          );
        }
        return const MyApp();
      },
    );
  }
}

// MyApp (Com uma pequena adição)
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
        initialRoute: '/auth_check',
        // <<< 2. ADICIONAR A ROTA PARA A NOVA TELA >>>
        routes: {
          '/auth_check': (context) => const AuthCheck(),
          '/equipe': (context) => const EquipePage(),
          '/home': (context) => const HomePage(title: 'Geo Forest Analytics'),
          '/lista_projetos': (context) => const ListaProjetosPage(title: 'Meus Projetos'),
          '/login': (context) => const LoginPage(),
          '/paywall': (context) => const PaywallPage(),
          '/gerente_home': (context) => const GerenteHomePage(), // ROTA ADICIONADA
        },
        navigatorObservers: [MapProvider.routeObserver],
        builder: (context, child) {
          ErrorWidget.builder = (FlutterErrorDetails details) {
            debugPrint('Caught a Flutter error: ${details.exception}');
            return ErrorScreen(
              message: 'Ocorreu um erro inesperado.\nPor favor, reinicie o aplicativo.',
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
    // ... (código do tema sem alterações)
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

// =======================================================================
// <<< 3. WIDGET AUTHCHECK TOTALMENTE MODIFICADO >>>
// =======================================================================
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final loginController = context.watch<LoginController>();
    final licenseProvider = context.watch<LicenseProvider>();

    // Se a autenticação ou a licença ainda não foram verificadas, mostra um loading.
    if (!loginController.isInitialized || licenseProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Se o usuário não está logado, vai para a página de Login.
    if (!loginController.isLoggedIn) {
      return const LoginPage();
    }

    // Se o usuário está logado, verifica a licença.
    final license = licenseProvider.licenseData;
    final bool isLicenseOk = license != null && (license.status == 'ativa' || license.status == 'trial');

    if (isLicenseOk) {
      // SE A LICENÇA ESTÁ OK, VERIFICA O CARGO!
      if (license.cargo == 'gerente') {
        // Se for 'gerente', vai para a nova tela de gerente.
        return const GerenteHomePage();
      } else {
        // Se for 'equipe' (ou qualquer outro valor), vai para a tela de equipe.
        return const EquipePage();
      }
    } else {
      // Se a licença não estiver OK, vai para a tela de pagamento.
      return const PaywallPage();
    }
  }
}

// ErrorScreen (Sem alterações)
class ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorScreen({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    // ... (código da tela de erro sem alterações)
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
              Text('Erro na Aplicação', style: TextStyle(color: Colors.red[700], fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 30),
              if (onRetry != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF617359), foregroundColor: Colors.white),
                  onPressed: onRetry,
                  child: const Text('Tentar Novamente'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}