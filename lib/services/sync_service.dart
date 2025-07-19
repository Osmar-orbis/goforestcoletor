// lib/services/sync_service.dart (VERSÃO FINAL COM SINCRONIZAÇÃO POR UUID)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/services/licensing_service.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LicensingService _licensingService = LicensingService();

  Future<void> sincronizarDados() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuário não está logado.");

    final licenseDoc = await _licensingService.findLicenseDocumentForUser(user);
    if (licenseDoc == null) {
      throw Exception("Não foi possível encontrar uma licença válida para sincronizar os dados.");
    }
    final licenseId = licenseDoc.id;

    await _uploadAlteracoesLocais(licenseId);
    await _downloadAlteracoesDaNuvem(licenseId);
  }

  /// Salva os dados locais (não sincronizados) no repositório compartilhado da licença.
  Future<void> _uploadAlteracoesLocais(String licenseId) async {
    final List<Parcela> parcelasNaoSincronizadas = await _dbHelper.getUnsyncedParcelas();
    if (parcelasNaoSincronizadas.isEmpty) return;

    final WriteBatch batch = _firestore.batch();
    
    for (final parcela in parcelasNaoSincronizadas) {
      final List<Arvore> arvores = await _dbHelper.getArvoresDaParcela(parcela.dbId!);
      
      Talhao? talhao;
      Atividade? atividade;
      Projeto? projeto;
      if (parcela.talhaoId != null) {
        final db = await _dbHelper.database;
        final talhaoMaps = await db.query('talhoes', where: 'id = ?', whereArgs: [parcela.talhaoId]);
        if (talhaoMaps.isNotEmpty) {
          talhao = Talhao.fromMap(talhaoMaps.first);
          final atividadeMaps = await db.query('atividades', where: 'id = ?', whereArgs: [talhao.fazendaAtividadeId]);
          if (atividadeMaps.isNotEmpty) {
            atividade = Atividade.fromMap(atividadeMaps.first);
            projeto = await _dbHelper.getProjetoById(atividade.projetoId);
          }
        }
      }

      final parcelaMap = parcela.toMap();
      parcelaMap['projetoId'] = projeto?.id;
      parcelaMap['projetoNome'] = projeto?.nome;
      parcelaMap['atividadeTipo'] = atividade?.tipo;
      
      // ===================================================================
      // <<< MUDANÇA 1: USA O UUID COMO ID DO DOCUMENTO NO FIRESTORE >>>
      // ===================================================================
      final docRef = _firestore
          .collection('clientes')
          .doc(licenseId)
          .collection('dados_coleta')
          .doc(parcela.uuid); // <-- MUDANÇA APLICADA
      
      batch.set(docRef, parcelaMap);

      for (final arvore in arvores) {
        final arvoreRef = docRef.collection('arvores').doc(arvore.id.toString());
        batch.set(arvoreRef, arvore.toMap());
      }
    }
    
    await batch.commit();

    final ids = parcelasNaoSincronizadas.map((p) => p.dbId!).toList();
    for (final id in ids) {
      await _dbHelper.markParcelaAsSynced(id);
    }
  }

  /// Baixa os dados do repositório compartilhado da licença e atualiza o banco local.
  Future<void> _downloadAlteracoesDaNuvem(String licenseId) async {
    final querySnapshot = await _firestore
        .collection('clientes')
        .doc(licenseId)
        .collection('dados_coleta')
        .get();

    for (final docSnapshot in querySnapshot.docs) {
      final parcelaDaNuvem = Parcela.fromMap(docSnapshot.data());
      
      // ===================================================================
      // <<< MUDANÇA 2: LÓGICA DE MESCLAGEM INTELIGENTE >>>
      // ===================================================================
      final db = await _dbHelper.database;
      // Procura a parcela no banco local pelo UUID universal
      final parcelaLocalResult = await db.query('parcelas', where: 'uuid = ?', whereArgs: [parcelaDaNuvem.uuid]);
      
      // Se a parcela já existe localmente, nós pegamos o ID do SQLite dela para
      // garantir que estamos ATUALIZANDO o registro certo, em vez de criar um duplicado.
      if (parcelaLocalResult.isNotEmpty) {
        parcelaDaNuvem.dbId = parcelaLocalResult.first['id'] as int;
      } else {
        // Se não existe, o dbId permanece nulo, e o saveFullColeta irá INSERIR uma nova.
        parcelaDaNuvem.dbId = null;
      }
      // ===================================================================
      // <<< FIM DA MUDANÇA >>>
      // ===================================================================

      final arvoresSnapshot = await docSnapshot.reference.collection('arvores').get();
      final arvoresDaNuvem = arvoresSnapshot.docs.map((doc) => Arvore.fromMap(doc.data())).toList();
      
      // saveFullColeta agora vai inserir ou atualizar corretamente.
      await _dbHelper.saveFullColeta(parcelaDaNuvem, arvoresDaNuvem);
    }
  }
}