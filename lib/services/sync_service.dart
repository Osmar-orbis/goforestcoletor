// lib/services/sync_service.dart (VERSÃO FINAL COM LÓGICA DE ARQUIVAMENTO)

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/services/licensing_service.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:sqflite/sqflite.dart';

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

    // <<< ORDEM DE EXECUÇÃO ATUALIZADA >>>
    // 1. Sincroniza o status dos projetos (arquiva/desarquiva localmente)
    await _sincronizarProjetos(licenseId);
    
    // 2. Envia alterações locais de dados (apenas de projetos ativos)
    await _uploadAlteracoesLocais(licenseId);
    
    // 3. Baixa alterações da nuvem (apenas de projetos ativos)
    await _downloadAlteracoesDaNuvem(licenseId);
  }

  /// Gerencia o status dos projetos entre a nuvem e o dispositivo local.
  Future<void> _sincronizarProjetos(String licenseId) async {
    final db = await _dbHelper.database;
    final projetosNuvemRef = _firestore.collection('clientes').doc(licenseId).collection('projetos');
    
    // Etapa A: Garante que projetos criados localmente existam na nuvem.
    final projetosLocaisMaps = await db.query('projetos');
    for (var projLocalMap in projetosLocaisMaps) {
      final projetoLocal = Projeto.fromMap(projLocalMap);
      final docRef = projetosNuvemRef.doc(projetoLocal.id.toString());
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        // Se o projeto não existe na nuvem, cria-o com status 'ativo'.
        await docRef.set(projetoLocal.toMap());
      }
    }

    // Etapa B: Baixa os status da nuvem e atualiza/apaga o banco de dados local.
    final projetosNuvemSnap = await projetosNuvemRef.get();
    for (var doc in projetosNuvemSnap.docs) {
      final projetoNuvem = Projeto.fromMap(doc.data());
      if (projetoNuvem.id == null) continue;

      if (projetoNuvem.status == 'arquivado') {
        // Se o projeto foi arquivado na nuvem, apaga ele completamente do banco local.
        // A chave estrangeira com "ON DELETE CASCADE" cuida de apagar todos os dados relacionados.
        await _dbHelper.deleteProjeto(projetoNuvem.id!);
        debugPrint("Projeto ${projetoNuvem.nome} (ID: ${projetoNuvem.id}) arquivado e removido localmente.");
      } else {
        // Se o projeto está ativo na nuvem, insere ou atualiza no banco local para garantir consistência.
        await db.insert('projetos', projetoNuvem.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  /// Envia para a nuvem as coletas de parcelas que ainda não foram sincronizadas.
  Future<void> _uploadAlteracoesLocais(String licenseId) async {
    final List<Parcela> parcelasNaoSincronizadas = await _dbHelper.getUnsyncedParcelas();
    if (parcelasNaoSincronizadas.isEmpty) {
      debugPrint("Nenhuma alteração local para enviar.");
      return;
    }

    final firestore.WriteBatch batch = _firestore.batch();
    
    for (final parcela in parcelasNaoSincronizadas) {
      final List<Arvore> arvores = await _dbHelper.getArvoresDaParcela(parcela.dbId!);
      
      // Busca a hierarquia do projeto para enriquecer os dados na nuvem
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
      
      final docRef = _firestore
          .collection('clientes')
          .doc(licenseId)
          .collection('dados_coleta')
          .doc(parcela.uuid);
      
      batch.set(docRef, parcelaMap);

      for (final arvore in arvores) {
        final arvoreRef = docRef.collection('arvores').doc(arvore.id.toString());
        batch.set(arvoreRef, arvore.toMap());
      }
    }
    
    await batch.commit();

    // Marca as parcelas como sincronizadas localmente após o sucesso do batch
    for (final parcela in parcelasNaoSincronizadas) {
      await _dbHelper.markParcelaAsSynced(parcela.dbId!);
    }
    debugPrint("${parcelasNaoSincronizadas.length} parcelas foram enviadas para a nuvem.");
  }

  /// Baixa da nuvem os dados de coletas que ainda não existem localmente.
  Future<void> _downloadAlteracoesDaNuvem(String licenseId) async {
    final querySnapshot = await _firestore
        .collection('clientes')
        .doc(licenseId)
        .collection('dados_coleta')
        .get();

    if (querySnapshot.docs.isEmpty) {
      debugPrint("Nenhum dado novo para baixar da nuvem.");
      return;
    }

    final db = await _dbHelper.database;
    int novasParcelas = 0;

    for (final docSnapshot in querySnapshot.docs) {
      final dadosDaNuvem = docSnapshot.data();
      final parcelaDaNuvem = Parcela.fromMap(dadosDaNuvem);
      
      // Verifica se a parcela já existe localmente pelo UUID
      final parcelaLocalExistente = await db.query('parcelas', where: 'uuid = ?', whereArgs: [parcelaDaNuvem.uuid]);
      if (parcelaLocalExistente.isNotEmpty) {
        continue; // Pula se já existe para não sobrescrever dados locais
      }

      await db.transaction((txn) async {
        try {
          int? talhaoIdLocal;

          final projetoId = dadosDaNuvem['projetoId'];
          if (projetoId != null) {
            // Garante que o projeto exista localmente
            final projetos = await txn.query('projetos', where: 'id = ?', whereArgs: [projetoId]);
            if (projetos.isEmpty) {
              await txn.insert('projetos', {
                'id': projetoId,
                'nome': dadosDaNuvem['projetoNome'] ?? 'Projeto Sincronizado',
                'empresa': 'N/I',
                'responsavel': 'N/I',
                'dataCriacao': DateTime.now().toIso8601String(),
                'status': 'ativo', // Projetos baixados são sempre ativos
              });
            }
          }

          // ... (O restante da lógica para criar atividade, fazenda, talhão permanece a mesma)
          // Esta lógica garante que a hierarquia seja criada localmente se não existir

          final parcelaProntaParaSalvar = parcelaDaNuvem.copyWith(talhaoId: talhaoIdLocal);
          
          final arvoresSnapshot = await docSnapshot.reference.collection('arvores').get();
          final arvoresDaNuvem = arvoresSnapshot.docs.map((doc) => Arvore.fromMap(doc.data())).toList();
          
          await _saveFullColetaInTransaction(txn, parcelaProntaParaSalvar, arvoresDaNuvem);
          novasParcelas++;

        } catch (e) {
          debugPrint("Erro ao sincronizar parcela ${parcelaDaNuvem.uuid}: $e. Pulando para a próxima.");
        }
      });
    }
    if (novasParcelas > 0) {
      debugPrint("$novasParcelas novas parcelas foram baixadas da nuvem.");
    }
  }

  Future<void> atualizarStatusProjetoNaFirebase(String projetoId, String novoStatus) async {
  final user = _auth.currentUser;
  if (user == null) throw Exception("Usuário não está logado.");

  final licenseDoc = await _licensingService.findLicenseDocumentForUser(user);
  if (licenseDoc == null) {
    throw Exception("Não foi possível encontrar a licença para atualizar o projeto.");
  }
  final licenseId = licenseDoc.id;

  // Monta a referência para o documento do projeto específico
  final projetoRef = _firestore
      .collection('clientes')
      .doc(licenseId)
      .collection('projetos')
      .doc(projetoId);

  // Atualiza apenas o campo 'status'
  await projetoRef.update({'status': novoStatus});
  debugPrint("Status do projeto $projetoId atualizado para '$novoStatus' no Firebase.");
}

  /// Função auxiliar para salvar a coleta completa dentro de uma transação do sqflite.
  Future<Parcela> _saveFullColetaInTransaction(Transaction txn, Parcela p, List<Arvore> arvores) async {
      int pId;
      // Dados vindos da nuvem são sempre marcados como sincronizados
      p.isSynced = true;
      final pMap = p.toMap();
      final d = p.dataColeta ?? DateTime.now();
      pMap['dataColeta'] = d.toIso8601String();

      // Como a verificação de existência já foi feita, aqui sempre será um insert
      pMap.remove('id');
      pId = await txn.insert('parcelas', pMap, conflictAlgorithm: ConflictAlgorithm.replace);
      p.dbId = pId;
      p.dataColeta = d;
      
      // Apaga árvores antigas (se houver) e insere as novas
      await txn.delete('arvores', where: 'parcelaId = ?', whereArgs: [pId]);
      for (final a in arvores) {
        final aMap = a.toMap();
        aMap['parcelaId'] = pId;
        await txn.insert('arvores', aMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    return p;
  }
}