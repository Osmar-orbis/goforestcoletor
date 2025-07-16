// lib/providers/license_provider.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Modelo para guardar os dados da licença
class LicenseData {
  final String status;
  final DateTime? trialEndDate;
  final Map<String, dynamic> features;
  final Map<String, dynamic> limites;

  LicenseData({
    required this.status,
    this.trialEndDate,
    required this.features,
    required this.limites,
  });

  // Verifica se o trial está expirando em breve (ex: nos últimos 3 dias)
  bool get isTrialExpiringSoon {
    if (status != 'trial' || trialEndDate == null) {
      return false;
    }
    final difference = trialEndDate!.difference(DateTime.now()).inDays;
    return difference >= 0 && difference <= 3;
  }
}

class LicenseProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  LicenseData? _licenseData;
  bool _isLoading = true; // Inicia como true
  String? _error;

  LicenseData? get licenseData => _licenseData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Construtor que ouve as mudanças de autenticação
  LicenseProvider() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        fetchLicenseData(user.uid);
      } else {
        clearLicenseData();
      }
    });
  }

  Future<void> fetchLicenseData(String uid) async {
    _isLoading = true;
    _error = null;
    // Notifica os ouvintes que o carregamento começou
    notifyListeners();

    try {
      final doc = await _firestore.collection('clientes').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        final trialData = data['trial'] as Map<String, dynamic>?;
        
        _licenseData = LicenseData(
          status: data['statusAssinatura'] ?? 'inativa',
          trialEndDate: (trialData?['dataFim'] as Timestamp?)?.toDate(),
          features: data['features'] ?? {},
          limites: data['limites'] ?? {},
        );
      } else {
        _error = "Documento de licença não encontrado.";
      }
    } catch (e) {
      _error = "Erro ao buscar dados da licença: $e";
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearLicenseData() {
    _licenseData = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}