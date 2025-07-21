// lib/services/sync_service.dart (VERSÃO CORRIGIDA PARA AMBIGUIDADE DE IMPORT)

import 'package:cloud_firestore/cloud_firestore.dart' as firestore; // <<< MUDANÇA 1: Adicionar prefixo
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
  // <<< MUDANÇA 2: Usar o prefixo >>>
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

    await _uploadAlteracoesLocais(licenseId);
    await _downloadAlteracoesDaNuvem(licenseId);
  }

  Future<void> _uploadAlteracoesLocais(String licenseId) async {
    final List<Parcela> parcelasNaoSincronizadas = await _dbHelper.getUnsyncedParcelas();
    if (parcelasNaoSincronizadas.isEmpty) return;

    // <<< MUDANÇA 3: Usar o prefixo >>>
    final firestore.WriteBatch batch = _firestore.batch();
    
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

    final ids = parcelasNaoSincronizadas.map((p) => p.dbId!).toList();
    for (final id in ids) {
      await _dbHelper.markParcelaAsSynced(id);
    }
  }

  Future<void> _downloadAlteracoesDaNuvem(String licenseId) async {
    final querySnapshot = await _firestore
        .collection('clientes')
        .doc(licenseId)
        .collection('dados_coleta')
        .get();

    final db = await _dbHelper.database;

    for (final docSnapshot in querySnapshot.docs) {
      final dadosDaNuvem = docSnapshot.data();
      final parcelaDaNuvem = Parcela.fromMap(dadosDaNuvem);
      
      await db.transaction((txn) async {
        try {
          int? talhaoIdLocal;

          final projetoId = dadosDaNuvem['projetoId'];
          if (projetoId != null) {
            final projetos = await txn.query('projetos', where: 'id = ?', whereArgs: [projetoId]);
            if (projetos.isEmpty) {
              await txn.insert('projetos', {
                'id': projetoId,
                'nome': dadosDaNuvem['projetoNome'] ?? 'Projeto Sincronizado',
                'empresa': 'N/I',
                'responsavel': 'N/I',
                'dataCriacao': DateTime.now().toIso8601String(),
              });
            }
          }

          final atividadeTipo = dadosDaNuvem['atividadeTipo'];
          if (projetoId != null && atividadeTipo != null) {
             final atividades = await txn.query('atividades', where: 'projetoId = ? AND tipo = ?', whereArgs: [projetoId, atividadeTipo]);
             int atividadeId;
             if(atividades.isEmpty) {
                atividadeId = await txn.insert('atividades', {
                  'projetoId': projetoId,
                  'tipo': atividadeTipo,
                  'descricao': 'Sincronizado da nuvem',
                  'dataCriacao': DateTime.now().toIso8601String(),
                });
             } else {
                atividadeId = atividades.first['id'] as int;
             }

             final fazendaId = parcelaDaNuvem.idFazenda ?? parcelaDaNuvem.nomeFazenda;
             if (fazendaId != null) {
                final fazendas = await txn.query('fazendas', where: 'id = ? AND atividadeId = ?', whereArgs: [fazendaId, atividadeId]);
                 if(fazendas.isEmpty) {
                   await txn.insert('fazendas', {
                     'id': fazendaId,
                     'atividadeId': atividadeId,
                     'nome': parcelaDaNuvem.nomeFazenda ?? 'Fazenda Sincronizada',
                     'municipio': 'N/I',
                     'estado': 'N/I',
                   });
                 }

                if (parcelaDaNuvem.nomeTalhao != null) {
                  final talhoes = await txn.query('talhoes', where: 'nome = ? AND fazendaId = ? AND fazendaAtividadeId = ?', whereArgs: [parcelaDaNuvem.nomeTalhao, fazendaId, atividadeId]);
                  if (talhoes.isEmpty) {
                    talhaoIdLocal = await txn.insert('talhoes', {
                      'fazendaId': fazendaId,
                      'fazendaAtividadeId': atividadeId,
                      'nome': parcelaDaNuvem.nomeTalhao,
                    });
                  } else {
                    talhaoIdLocal = talhoes.first['id'] as int;
                  }
                }
             }
          }

          final parcelaLocalResult = await txn.query('parcelas', where: 'uuid = ?', whereArgs: [parcelaDaNuvem.uuid]);
          
          if (parcelaLocalResult.isNotEmpty) {
            parcelaDaNuvem.dbId = parcelaLocalResult.first['id'] as int;
          } else {
            parcelaDaNuvem.dbId = null;
          }
          
          final parcelaProntaParaSalvar = parcelaDaNuvem.copyWith(talhaoId: talhaoIdLocal);
          
          final arvoresSnapshot = await docSnapshot.reference.collection('arvores').get();
          final arvoresDaNuvem = arvoresSnapshot.docs.map((doc) => Arvore.fromMap(doc.data())).toList();
          
          await _saveFullColetaInTransaction(txn, parcelaProntaParaSalvar, arvoresDaNuvem);

        } catch (e) {
          debugPrint("Erro ao sincronizar parcela ${parcelaDaNuvem.uuid}: $e. Pulando para a próxima.");
        }
      });
    }
  }

  // <<< MUDANÇA 4: A assinatura da função usa 'Transaction' que agora se refere
  // inequivocamente ao do pacote sqflite >>>
  Future<Parcela> _saveFullColetaInTransaction(Transaction txn, Parcela p, List<Arvore> arvores) async {
      int pId;
      p.isSynced = true;
      final pMap = p.toMap();
      final d = p.dataColeta ?? DateTime.now();
      pMap['dataColeta'] = d.toIso8601String();

      if (p.dbId == null) {
        pMap.remove('id');
        pId = await txn.insert('parcelas', pMap, conflictAlgorithm: ConflictAlgorithm.replace);
        p.dbId = pId;
        p.dataColeta = d;
      } else {
        pId = p.dbId!;
        await txn.update('parcelas', pMap, where: 'id = ?', whereArgs: [pId]);
      }
      
      await txn.delete('arvores', where: 'parcelaId = ?', whereArgs: [pId]);
      for (final a in arvores) {
        final aMap = a.toMap();
        aMap['parcelaId'] = pId;
        await txn.insert('arvores', aMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    return p;
  }
}