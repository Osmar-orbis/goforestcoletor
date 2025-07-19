// lib/controller/login_controller.dart (VERSÃO CORRIGIDA E SEGURA)

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoforestcoletor/services/auth_service.dart';
// <<< 1. IMPORTE O DATABASE HELPER >>>
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';

class LoginController with ChangeNotifier {
  final AuthService _authService = AuthService();
  // <<< 2. CRIE UMA INSTÂNCIA DO HELPER >>>
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

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
    // <<< 3. LIMPE O BANCO DE DADOS ANTES DE DESLOGAR >>>
    // Este é o passo mais importante para garantir a segurança dos dados.
    await _dbHelper.deleteDatabaseFile();
    
    // Agora, prossiga com o logout do Firebase.
    await _authService.signOut();
    
    // O `authStateChanges` será acionado automaticamente e fará a notificação.
  }
}