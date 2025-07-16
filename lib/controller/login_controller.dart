// lib/controller/login_controller.dart (COPIE E COLE ESTE CÓDIGO COMPLETO)

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoforestcoletor/services/auth_service.dart'; // Importe seu AuthService

class LoginController with ChangeNotifier {
  final AuthService _authService = AuthService(); // Instância do seu AuthService

  // Propriedades para saber o estado do login
  bool _isLoggedIn = false;
  User? _user;
  bool _isInitialized = false; // Flag para saber se a verificação inicial já ocorreu

  // Getters para acessar as propriedades de fora
  bool get isLoggedIn => _isLoggedIn;
  User? get user => _user;
  bool get isInitialized => _isInitialized;

  LoginController() {
    // Inicia o "ouvinte" de estado de autenticação assim que o controller é criado.
    checkLoginStatus();
  }

  /// Ouve as mudanças no estado de autenticação do Firebase.
  /// Este é o método principal que mantém o estado de login sincronizado.
  void checkLoginStatus() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        // Se o usuário for nulo, significa que não há ninguém logado.
        _isLoggedIn = false;
        _user = null;
        print('LoginController: Nenhum usuário logado.');
      } else {
        // Se o objeto user não for nulo, temos um usuário logado!
        _isLoggedIn = true;
        _user = user;
        print('LoginController: Usuário ${user.email} está logado.');
      }
      
      // Marca que a verificação inicial foi concluída.
      _isInitialized = true;
      
      // Notifica todos os 'Consumer' widgets que estão ouvindo este controller
      // para que eles se reconstruam com o novo estado.
      notifyListeners();
    });
  }

  /// Método para realizar o logout usando o AuthService.
  Future<void> signOut() async {
    await _authService.signOut();
    // Não precisa de `notifyListeners()` aqui, pois o `authStateChanges` 
    // será acionado automaticamente e fará a notificação.
  }
}