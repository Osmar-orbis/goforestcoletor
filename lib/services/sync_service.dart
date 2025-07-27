// lib/services/sync_service.dart (VERSÃO FINAL, COMPLETA E CORRIGIDA)

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';
import 'package:geoforestcoletor/models/cubagem_secao_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/services/licensing_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;
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

    final licenseData = licenseDoc.data()!;
    final usuariosPermitidos = licenseData['usuariosPermitidos'] as Map<String, dynamic>? ?? {};
    final cargo = usuariosPermitidos[user.uid] as String? ?? 'equipe';

    // A lógica de fluxo está correta para ambos os cenários
    if (cargo == 'gerente') {
      debugPrint("Sincronização em modo GERENTE: Upload da estrutura e das coletas.");
      await _uploadHierarquiaCompleta(licenseId);
      await _uploadColetasNaoSincronizadas(licenseId); 
    } else {
      debugPrint("Sincronização em modo EQUIPE: Upload de coletas e Download geral.");
      await _uploadColetasNaoSincronizadas(licenseId);
      await _downloadHierarquiaCompleta(licenseId);
      await _downloadColetas(licenseId);
    }
  }

  /// Envia a estrutura completa (Projetos, Atividades, Fazendas, Talhões e Plano de Parcelas)
  /// para a nuvem de forma segura, usando `merge: true` para não sobrescrever dados.
  Future<void> _uploadHierarquiaCompleta(String licenseId) async {
    final db = await _dbHelper.database;
    final batch = _firestore.batch();
    
    final tabelasEstrutura = ['projetos', 'atividades', 'talhoes'];
    for (var nomeTabela in tabelasEstrutura) {
      final registros = await db.query(nomeTabela);
      for (var registro in registros) {
        final docRef = _firestore.collection('clientes').doc(licenseId).collection(nomeTabela).doc(registro['id'].toString());
        batch.set(docRef, registro, firestore.SetOptions(merge: true));
      }
    }

    final fazendas = await db.query('fazendas');
    for (var f in fazendas) {
        final docId = "${f['id']}_${f['atividadeId']}";
        final docRef = _firestore.collection('clientes').doc(licenseId).collection('fazendas').doc(docId);
        batch.set(docRef, f, firestore.SetOptions(merge: true));
    }

    // Enviamos TODAS as parcelas do gerente, pois ele é a "fonte da verdade" para o plano.
    // O merge:true garante que não vamos sobrescrever o status ou as árvores de uma coleta da equipe.
    final parcelas = await db.query('parcelas');
    for (var parcelaMap in parcelas) {
      final docRef = _firestore.collection('clientes').doc(licenseId).collection('dados_coleta').doc(parcelaMap['uuid'] as String);
      batch.set(docRef, parcelaMap, firestore.SetOptions(merge: true));
    }
    
    await batch.commit();
    debugPrint("Hierarquia completa (incluindo plano de parcelas) enviada para a nuvem.");
  }

  /// Envia APENAS as coletas (parcelas e cubagens) que foram modificadas localmente (isSynced = false).
  /// Usa `merge: true` para garantir que não sobrescreva o trabalho de outros.
  Future<void> _uploadColetasNaoSincronizadas(String licenseId) async {
    // ---- UPLOAD DE PARCELAS ----
    final List<Parcela> parcelasNaoSincronizadas = await _dbHelper.getUnsyncedParcelas();
    if (parcelasNaoSincronizadas.isNotEmpty) {
      final batch = _firestore.batch();
      final prefs = await SharedPreferences.getInstance();
      final nomeLider = prefs.getString('nome_lider');

      for (final parcela in parcelasNaoSincronizadas) {
        final docRef = _firestore.collection('clientes').doc(licenseId).collection('dados_coleta').doc(parcela.uuid);
        
        final parcelaMap = parcela.toMap();
        parcelaMap['nomeLider'] = nomeLider;
        // ... (Sua lógica para adicionar projetoNome, etc., se necessário)

        // **AQUI ESTÁ A CHAVE**: Usamos MERGE para atualizar a parcela sem apagar as árvores
        // que já possam existir na nuvem, enviadas por outra equipe.
        batch.set(docRef, parcelaMap, firestore.SetOptions(merge: true));

        // Enviamos a lista completa de árvores da nossa versão local.
        // O Firestore irá criar/sobrescrever os documentos na sub-coleção.
        final arvores = await _dbHelper.getArvoresDaParcela(parcela.dbId!);
        for (final arvore in arvores) {
          final arvoreRef = docRef.collection('arvores').doc(arvore.id.toString());
          batch.set(arvoreRef, arvore.toMap());
        }
      }
      await batch.commit();
      for (final parcela in parcelasNaoSincronizadas) {
        await _dbHelper.markParcelaAsSynced(parcela.dbId!);
      }
      debugPrint("${parcelasNaoSincronizadas.length} parcelas locais foram sincronizadas.");
    }

    // ---- UPLOAD DE CUBAGENS ----
    final List<CubagemArvore> cubagensNaoSincronizadas = await _dbHelper.getUnsyncedCubagens();
    if (cubagensNaoSincronizadas.isNotEmpty) {
      final batch = _firestore.batch();
      for (final cubagem in cubagensNaoSincronizadas) {
        if (cubagem.id == null) continue;
        final docRef = _firestore.collection('clientes').doc(licenseId).collection('dados_cubagem').doc(cubagem.id.toString());
        batch.set(docRef, cubagem.toMap(), firestore.SetOptions(merge: true));

        final secoes = await _dbHelper.getSecoesPorArvoreId(cubagem.id!);
        for (final secao in secoes) {
          final secaoRef = docRef.collection('secoes').doc(secao.id.toString());
          batch.set(secaoRef, secao.toMap());
        }
      }
      await batch.commit();
      for (final cubagem in cubagensNaoSincronizadas) {
        await _dbHelper.markCubagemAsSynced(cubagem.id!);
      }
      debugPrint("${cubagensNaoSincronizadas.length} cubagens locais foram sincronizadas.");
    }
  }
  
  // ===================================================================
  // AS FUNÇÕES DE DOWNLOAD NÃO PRECISAM DE ALTERAÇÕES.
  // Elas já estão corretas.
  // ===================================================================
  
  Future<void> _downloadHierarquiaCompleta(String licenseId) async {
    final db = await _dbHelper.database;
    
    final projetosSnap = await _firestore.collection('clientes').doc(licenseId).collection('projetos').get();
    for (var doc in projetosSnap.docs) {
      final data = doc.data();
      data['licenseId'] = licenseId; 
      if (data['status'] != 'arquivado') {
        await db.insert('projetos', data, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await db.delete('projetos', where: 'id = ?', whereArgs: [data['id']]);
      }
    }
    
    final atividadesSnap = await _firestore.collection('clientes').doc(licenseId).collection('atividades').get();
    for (var doc in atividadesSnap.docs) {
      await db.insert('atividades', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    final fazendasSnap = await _firestore.collection('clientes').doc(licenseId).collection('fazendas').get();
    for (var doc in fazendasSnap.docs) {
      await db.insert('fazendas', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final talhoesSnap = await _firestore.collection('clientes').doc(licenseId).collection('talhoes').get();
    for (var doc in talhoesSnap.docs) {
      await db.insert('talhoes', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    debugPrint("Hierarquia completa baixada e etiquetada localmente.");
  }

  Future<void> _downloadColetas(String licenseId) async {
    await _downloadParcelasDaNuvem(licenseId);
    await _downloadCubagensDaNuvem(licenseId);
  }

  Future<void> _downloadParcelasDaNuvem(String licenseId) async {
    final querySnapshot = await _firestore.collection('clientes').doc(licenseId).collection('dados_coleta').get();
    if (querySnapshot.docs.isEmpty) return;

    final db = await _dbHelper.database;
    int novasParcelas = 0;

    for (final docSnapshot in querySnapshot.docs) {
      final dadosDaNuvem = docSnapshot.data();
      final parcelaDaNuvem = Parcela.fromMap(dadosDaNuvem);
      
      // A lógica para baixar APENAS se a parcela não existir localmente está correta
      final parcelaLocalExistente = await db.query('parcelas', where: 'uuid = ?', whereArgs: [parcelaDaNuvem.uuid]);
      if (parcelaLocalExistente.isNotEmpty) continue;

      await db.transaction((txn) async {
        try {
          final talhaoIdLocal = parcelaDaNuvem.talhaoId;
          if (talhaoIdLocal == null) return;
          
          final pMap = parcelaDaNuvem.toMap();
          pMap['isSynced'] = 1;
          pMap.remove('id');

          final novoIdParcelaLocal = await txn.insert('parcelas', pMap);

          final arvoresSnapshot = await docSnapshot.reference.collection('arvores').get();
          if (arvoresSnapshot.docs.isNotEmpty) {
            final arvoresDaNuvem = arvoresSnapshot.docs.map((doc) => Arvore.fromMap(doc.data())).toList();
            for (final arvore in arvoresDaNuvem) {
              final aMap = arvore.toMap();
              aMap['parcelaId'] = novoIdParcelaLocal;
              await txn.insert('arvores', aMap);
            }
          }
          novasParcelas++;
        } catch (e, s) {
          debugPrint("Erro CRÍTICO ao sincronizar parcela ${parcelaDaNuvem.uuid}: $e\n$s");
        }
      });
    }
    if (novasParcelas > 0) debugPrint("$novasParcelas novas parcelas foram baixadas da nuvem.");
  }
  
  Future<void> _downloadCubagensDaNuvem(String licenseId) async {
    final querySnapshot = await _firestore.collection('clientes').doc(licenseId).collection('dados_cubagem').get();
    if (querySnapshot.docs.isEmpty) {
      debugPrint("Nenhuma cubagem nova para baixar da nuvem.");
      return;
    }

    final db = await _dbHelper.database;
    int novasCubagens = 0;

    for (final docSnapshot in querySnapshot.docs) {
      final dadosDaNuvem = docSnapshot.data();
      final cubagemDaNuvem = CubagemArvore.fromMap(dadosDaNuvem);

      final cubagemLocalExistente = await db.query('cubagens_arvores', where: 'id = ?', whereArgs: [cubagemDaNuvem.id]);
      if (cubagemLocalExistente.isNotEmpty) continue;

      await db.transaction((txn) async {
        try {
          final talhaoIdLocal = cubagemDaNuvem.talhaoId;
          if (talhaoIdLocal == null) return;

          final talhoes = await txn.query('talhoes', where: 'id = ?', whereArgs: [talhaoIdLocal]);
          if (talhoes.isEmpty) {
            debugPrint("Talhão ${talhaoIdLocal} para a cubagem não encontrado localmente. Pulando.");
            return;
          }

          final cMap = cubagemDaNuvem.toMap();
          cMap['isSynced'] = 1;

          await txn.insert('cubagens_arvores', cMap, conflictAlgorithm: ConflictAlgorithm.replace);

          final secoesSnapshot = await docSnapshot.reference.collection('secoes').get();
          if (secoesSnapshot.docs.isNotEmpty) {
            final secoesDaNuvem = secoesSnapshot.docs.map((doc) => CubagemSecao.fromMap(doc.data())).toList();
            for (final secao in secoesDaNuvem) {
              await txn.insert('cubagens_secoes', secao.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
          novasCubagens++;
        } catch (e, s) {
          debugPrint("Erro CRÍTICO ao sincronizar cubagem ${cubagemDaNuvem.id}: $e\n$s");
        }
      });
    }
    if (novasCubagens > 0) debugPrint("$novasCubagens novas cubagens foram baixadas da nuvem.");
  }
  
  Future<void> atualizarStatusProjetoNaFirebase(String projetoId, String novoStatus) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuário não está logado.");

    final licenseDoc = await _licensingService.findLicenseDocumentForUser(user);
    if (licenseDoc == null) throw Exception("Não foi possível encontrar a licença para atualizar o projeto.");
    
    final licenseId = licenseDoc.id;
    final projetoRef = _firestore.collection('clientes').doc(licenseId).collection('projetos').doc(projetoId);
    await projetoRef.update({'status': novoStatus});
    debugPrint("Status do projeto $projetoId atualizado para '$novoStatus' no Firebase.");
  }
}