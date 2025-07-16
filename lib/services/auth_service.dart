// lib/services/auth_service.dart (VERSÃO CORRIGIDA)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoforestcoletor/services/licensing_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final LicensingService _licensingService = LicensingService();

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (email == 'teste@geoforest.com') {
      print('Usuário super-dev detectado. Pulando verificação de licença.');
      return _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw FirebaseAuthException(code: 'user-not-found', message: 'Usuário não encontrado após o login.');
      }

      await _licensingService.checkAndRegisterDevice(userCredential.user!);
      
      return userCredential;

    } on LicenseException catch (e) {
      print('Erro de licença: ${e.message}. Deslogando usuário.');
      await signOut(); 
      rethrow;

    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    return credential;
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  User? get currentUser => _firebaseAuth.currentUser;
}