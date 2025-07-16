// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoforestcoletor/pages/menu/login_page.dart';
import 'package:provider/provider.dart';
import 'package:geoforestcoletor/controller/login_controller.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/providers/team_provider.dart';

// Um Mock do LoginController para evitar dependências de Firebase nos testes de widget.
class MockLoginController extends LoginController {
  bool _isLoggedIn = false;
  bool _isInitialized = true;

  @override
  bool get isLoggedIn => _isLoggedIn;

  @override
  bool get isInitialized => _isInitialized;
  
  void setLoginStatus(bool loggedIn) {
    _isLoggedIn = loggedIn;
    notifyListeners();
  }
}

void main() {
  // Teste de widget para a tela de Login
  testWidgets('LoginPage renders correctly', (WidgetTester tester) async {
    // Envolve o LoginPage com os providers necessários para o teste.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LoginController>(create: (_) => MockLoginController()),
          ChangeNotifierProvider(create: (_) => MapProvider()),
          ChangeNotifierProvider(create: (_) => TeamProvider()),
        ],
        child: const MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    // Verifica se os campos de texto para email e senha estão presentes.
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);

    // Verifica se o botão "Entrar" está presente.
    expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);

    // Verifica se o botão "Criar nova conta" está presente.
    expect(find.widgetWithText(OutlinedButton, 'Criar nova conta'), findsOneWidget);
    
    // Verifica se o texto de boas-vindas é exibido.
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });
}