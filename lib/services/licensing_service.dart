// lib/services/licensing_service.dart (VERSÃO FINAL UNIFICADA)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);
  @override
  String toString() => message;
}

class LicensingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // MÉTODO PRINCIPAL CORRIGIDO: Busca o cliente diretamente pelo ID do usuário (UID)
  Future<void> checkAndRegisterDevice(User user) async {
    // Busca o documento do cliente usando o ID do usuário como chave primária.
    // É mais rápido e direto.
    final clienteDocRef = _firestore.collection('clientes').doc(user.uid);
    final clienteDoc = await clienteDocRef.get();

    if (!clienteDoc.exists) {
      // Este erro acontece se a função de criar o cliente no registro falhar.
      throw LicenseException('Sua conta não foi encontrada ou a licença não foi criada. Tente criar a conta novamente ou contate o suporte.');
    }

    final clienteData = clienteDoc.data()!;
    final statusAssinatura = clienteData['statusAssinatura'];
    final limites = clienteData['limites'] as Map<String, dynamic>?; // Limites da licença

    // Lógica para verificar o status da assinatura (ativa ou trial válido)
    bool acessoPermitido = false;
    if (statusAssinatura == 'ativa') {
      acessoPermitido = true;
    } else if (statusAssinatura == 'trial') {
      final trialData = clienteData['trial'] as Map<String, dynamic>?;
      if (trialData != null && trialData['ativo'] == true) {
        final dataFim = (trialData['dataFim'] as Timestamp).toDate();
        if (DateTime.now().isBefore(dataFim)) {
          acessoPermitido = true;
        } else {
          throw LicenseException('Seu período de teste expirou. Contrate um plano.');
        }
      }
    }

    if (!acessoPermitido) {
      throw LicenseException('A assinatura da sua empresa está inativa ou expirou.');
    }

    if (limites == null) {
      throw LicenseException('Os limites do seu plano não estão configurados corretamente.');
    }

    // O resto da lógica para registrar o dispositivo está PERFEITA e não precisa de alterações.
    final tipoDispositivo = kIsWeb ? 'desktop' : 'smartphone';
    final deviceId = await _getDeviceId();

    if (deviceId == null) {
      throw LicenseException('Não foi possível identificar seu dispositivo.');
    }

    final dispositivosAtivosRef = clienteDoc.reference.collection('dispositivosAtivos');
    final dispositivoExistente = await dispositivosAtivosRef.doc(deviceId).get();

    if (dispositivoExistente.exists) {
      return; // Dispositivo já conhecido, acesso permitido.
    }

    final contagemAtualSnapshot = await dispositivosAtivosRef.where('tipo', isEqualTo: tipoDispositivo).count().get();
    final contagemAtual = contagemAtualSnapshot.count ?? 0;
    final limiteAtual = limites[tipoDispositivo] as int? ?? 0;

    // Se limite for -1 (ilimitado), a condição nunca será verdadeira.
    if (limiteAtual >= 0 && contagemAtual >= limiteAtual) {
      throw LicenseException('O limite de dispositivos do tipo "$tipoDispositivo" foi atingido para sua empresa.');
    }

    await dispositivosAtivosRef.doc(deviceId).set({
      'uidUsuario': user.uid,
      'emailUsuario': user.email,
      'tipo': tipoDispositivo,
      'registradoEm': FieldValue.serverTimestamp(),
      'nomeDispositivo': await _getDeviceName(),
    });
  }

  // MÉTODO AUXILIAR CORRIGIDO: Também busca pelo UID para ser consistente.
  Future<Map<String, int>> getDeviceUsage(String userEmail) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'smartphone': 0, 'desktop': 0};

    final clienteDoc = await _firestore.collection('clientes').doc(user.uid).get();
    if (!clienteDoc.exists) {
      return {'smartphone': 0, 'desktop': 0};
    }

    return _getDeviceCountFromDoc(clienteDoc.reference);
  }
  
  // Função interna para contar dispositivos de um cliente específico.
  Future<Map<String, int>> _getDeviceCountFromDoc(DocumentReference docRef) async {
    final dispositivosAtivosRef = docRef.collection('dispositivosAtivos');
    final smartphoneCount = (await dispositivosAtivosRef.where('tipo', isEqualTo: 'smartphone').count().get()).count ?? 0;
    final desktopCount = (await dispositivosAtivosRef.where('tipo', isEqualTo: 'desktop').count().get()).count ?? 0;
    return {'smartphone': smartphoneCount, 'desktop': desktopCount};
  }

  // As funções para obter ID e nome do dispositivo estão corretas.
  Future<String?> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      return 'web_${webInfo.vendor}_${webInfo.userAgent}';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor;
    }
    return null;
  }

  Future<String> _getDeviceName() async {
     final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) return 'Navegador Web';
      if (Platform.isAndroid) return '${(await deviceInfo.androidInfo).manufacturer} ${(await deviceInfo.androidInfo).model}';
      if (Platform.isIOS) return (await deviceInfo.iosInfo).name;
      return 'Dispositivo Desconhecido';
  }
}