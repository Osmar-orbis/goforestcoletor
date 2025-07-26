// lib/services/sync_service.dart (VERSÃO FINAL COM UPLOAD E DOWNLOAD COMPLETOS)

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';
import 'package:geoforestcoletor/models/cubagem_secao_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/services/licensing_service.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
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

    if (cargo == 'gerente') {
      debugPrint("Sincronização em modo GERENTE: Apenas upload.");
      // O gerente envia a estrutura completa e as coletas para a nuvem
      await _uploadHierarquiaCompleta(licenseId);
      await _uploadColetas(licenseId);
    } else {
      debugPrint("Sincronização em modo EQUIPE: Upload e Download.");
      // A equipe envia suas coletas e depois baixa a estrutura completa e as coletas de outros.
      await _uploadColetas(licenseId);
      await _downloadHierarquiaCompleta(licenseId);
      await _downloadColetas(licenseId);
    }
  }

  /// Envia a estrutura completa (Projetos, Atividades, Fazendas, Talhões) para a nuvem.
  Future<void> _uploadHierarquiaCompleta(String licenseId) async {
    final db = await _dbHelper.database;
    final batch = _firestore.batch();
    
    // 1. Projetos
    final projetos = await db.query('projetos');
    for (var p in projetos) {
      final docRef = _firestore.collection('clientes').doc(licenseId).collection('projetos').doc(p['id'].toString());
      batch.set(docRef, p, firestore.SetOptions(merge: true));
    }

    // 2. Atividades
    final atividades = await db.query('atividades');
    for (var a in atividades) {
      final docRef = _firestore.collection('clientes').doc(licenseId).collection('atividades').doc(a['id'].toString());
      batch.set(docRef, a, firestore.SetOptions(merge: true));
    }

    // 3. Fazendas
    final fazendas = await db.query('fazendas');
    for (var f in fazendas) {
      final docId = "${f['id']}_${f['atividadeId']}";
      final docRef = _firestore.collection('clientes').doc(licenseId).collection('fazendas').doc(docId);
      batch.set(docRef, f, firestore.SetOptions(merge: true));
    }
    
    // 4. Talhões
    final talhoes = await db.query('talhoes');
    for (var t in talhoes) {
      final docRef = _firestore.collection('clientes').doc(licenseId).collection('talhoes').doc(t['id'].toString());
      batch.set(docRef, t, firestore.SetOptions(merge: true));
    }
    
    await batch.commit();
    debugPrint("Hierarquia completa (Projetos, Atividades, Fazendas, Talhões) enviada para a nuvem.");
  }

  /// Envia as coletas (parcelas e cubagens) que não foram sincronizadas.
  Future<void> _uploadColetas(String licenseId) async {
    await _uploadParcelasLocais(licenseId);
    await _uploadCubagensLocais(licenseId);
  }
  
  /// Baixa a estrutura completa (Projetos, Atividades, Fazendas, Talhões) da nuvem.
  Future<void> _downloadHierarquiaCompleta(String licenseId) async {
    final db = await _dbHelper.database;
    
    // 1. Baixar e salvar Projetos
    final projetosSnap = await _firestore.collection('clientes').doc(licenseId).collection('projetos').get();
    for (var doc in projetosSnap.docs) {
      
      // <<< INÍCIO DA MUDANÇA >>>
      final data = doc.data();
      // Adicionamos a "etiqueta" licenseId aos dados antes de salvar
      data['licenseId'] = licenseId; 
      // <<< FIM DA MUDANÇA >>>

      if (data['status'] != 'arquivado') {
        // Agora salvamos os dados já com a etiqueta
        await db.insert('projetos', data, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await db.delete('projetos', where: 'id = ?', whereArgs: [data['id']]);
      }
    }
    
    // O download das outras tabelas (atividades, fazendas, talhões) não precisa mudar,
    // pois elas estão ligadas a um projeto, que agora terá o licenseId.
    
    // 2. Baixar e salvar Atividades
    final atividadesSnap = await _firestore.collection('clientes').doc(licenseId).collection('atividades').get();
    for (var doc in atividadesSnap.docs) {
      await db.insert('atividades', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    // 3. Baixar e salvar Fazendas
    final fazendasSnap = await _firestore.collection('clientes').doc(licenseId).collection('fazendas').get();
    for (var doc in fazendasSnap.docs) {
      await db.insert('fazendas', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // 4. Baixar e salvar Talhões
    final talhoesSnap = await _firestore.collection('clientes').doc(licenseId).collection('talhoes').get();
    for (var doc in talhoesSnap.docs) {
      await db.insert('talhoes', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    debugPrint("Hierarquia completa baixada e ETIQUETADA localmente.");
  }

  /// Baixa as coletas (parcelas e cubagens) que não existem localmente.
  Future<void> _downloadColetas(String licenseId) async {
    await _downloadParcelasDaNuvem(licenseId);
    await _downloadCubagensDaNuvem(licenseId);
  }

  // MÉTODOS AUXILIARES DETALHADOS

  Future<void> _uploadParcelasLocais(String licenseId) async {
    final List<Parcela> parcelasNaoSincronizadas = await _dbHelper.getUnsyncedParcelas();
    if (parcelasNaoSincronizadas.isEmpty) {
      debugPrint("Nenhuma parcela local para enviar.");
      return;
    }

    final firestore.WriteBatch batch = _firestore.batch();
    
    final prefs = await SharedPreferences.getInstance();
    final nomeLider = prefs.getString('nome_lider');

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
      parcelaMap['nomeLider'] = nomeLider;
      
      final docRef = _firestore.collection('clientes').doc(licenseId).collection('dados_coleta').doc(parcela.uuid);
      batch.set(docRef, parcelaMap);

      for (final arvore in arvores) {
        final arvoreRef = docRef.collection('arvores').doc(arvore.id.toString());
        batch.set(arvoreRef, arvore.toMap());
      }
    }
    
    await batch.commit();

    for (final parcela in parcelasNaoSincronizadas) {
      await _dbHelper.markParcelaAsSynced(parcela.dbId!);
    }
    debugPrint("${parcelasNaoSincronizadas.length} parcelas foram enviadas para a nuvem.");
  }

  Future<void> _uploadCubagensLocais(String licenseId) async {
    final List<CubagemArvore> cubagensNaoSincronizadas = await _dbHelper.getUnsyncedCubagens();
    if (cubagensNaoSincronizadas.isEmpty) {
      debugPrint("Nenhuma cubagem local para enviar.");
      return;
    }

    final firestore.WriteBatch batch = _firestore.batch();

    for (final cubagem in cubagensNaoSincronizadas) {
      if (cubagem.id == null) continue;
      final List<CubagemSecao> secoes = await _dbHelper.getSecoesPorArvoreId(cubagem.id!);

      final docRef = _firestore.collection('clientes').doc(licenseId).collection('dados_cubagem').doc(cubagem.id.toString());
      batch.set(docRef, cubagem.toMap());

      for (final secao in secoes) {
        final secaoRef = docRef.collection('secoes').doc(secao.id.toString());
        batch.set(secaoRef, secao.toMap());
      }
    }

    await batch.commit();

    for (final cubagem in cubagensNaoSincronizadas) {
      await _dbHelper.markCubagemAsSynced(cubagem.id!);
    }
    debugPrint("${cubagensNaoSincronizadas.length} cubagens foram enviadas para a nuvem.");
  }

  Future<void> _downloadParcelasDaNuvem(String licenseId) async {
    final querySnapshot = await _firestore.collection('clientes').doc(licenseId).collection('dados_coleta').get();
    if (querySnapshot.docs.isEmpty) {
      debugPrint("Nenhuma parcela nova para baixar da nuvem.");
      return;
    }

    final db = await _dbHelper.database;
    int novasParcelas = 0;

    for (final docSnapshot in querySnapshot.docs) {
      final dadosDaNuvem = docSnapshot.data();
      final parcelaDaNuvem = Parcela.fromMap(dadosDaNuvem);
      
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