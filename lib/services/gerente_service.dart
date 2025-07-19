// lib/services/gerente_service.dart (VERSÃO NATIVA E GARANTIDA)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/services/licensing_service.dart';

class GerenteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LicensingService _licensingService = LicensingService();

  /// Retorna um "fluxo" (Stream) de dados em tempo real da coleção de coletas.
  Stream<List<Parcela>> getDadosColetaStream() async* {
    final user = _auth.currentUser;
    if (user == null) {
      // Se não há usuário, retorna um fluxo vazio e encerra.
      yield [];
      return;
    }

    try {
      // 1. Primeiro, resolvemos o ID da licença de forma assíncrona.
      final licenseDoc = await _licensingService.findLicenseDocumentForUser(user);
      if (licenseDoc == null) {
        throw Exception("Licença não encontrada para o gerente.");
      }
      final licenseId = licenseDoc.id;

      // 2. Agora, criamos o Stream a partir do caminho correto no Firestore.
      final stream = _firestore
          .collection('clientes')
          .doc(licenseId)
          .collection('dados_coleta')
          .snapshots();

      // 3. Usamos 'await for' para "ouvir" o stream e processar os dados.
      await for (final querySnapshot in stream) {
        // Para cada "pacote" de dados que o Firestore enviar,
        // nós o convertemos em uma lista de Parcelas.
        final parcelas = querySnapshot.docs
            .map((doc) => Parcela.fromMap(doc.data()))
            .toList();
        
        // 'yield' emite a lista de parcelas para quem estiver ouvindo (o Provider).
        yield parcelas;
      }
    } catch (e) {
      // Se ocorrer qualquer erro, emitimos um erro no fluxo.
      yield* Stream.error(e);
    }
  }
}