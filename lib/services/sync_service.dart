// lib/services/sync_service.dart (VERSÃO ATUALIZADA PARA O NOVO MODELO COLABORATIVO)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
// <<< 1. IMPORTAR O LICENSING SERVICE QUE JÁ AJUSTAMOS >>>
import 'package:geoforestcoletor/services/licensing_service.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  // <<< 1. INSTANCIAR O LICENSING SERVICE >>>
  final LicensingService _licensingService = LicensingService();

  Future<void> sincronizarDados() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuário não está logado.");

    // <<< 2. ENCONTRAR O DOCUMENTO DA LICENÇA DA EMPRESA >>>
    // Em vez de usar o UID do usuário, buscamos a licença à qual ele pertence.
    final licenseDoc = await _licensingService.findLicenseDocumentForUser(user);
    if (licenseDoc == null) {
      throw Exception("Não foi possível encontrar uma licença válida para sincronizar os dados.");
    }
    // O ID que usaremos agora é o da licença, não do usuário.
    final licenseId = licenseDoc.id;

    // Passo 1: Fazer upload das alterações locais para o local compartilhado.
    await _uploadAlteracoesLocais(licenseId);

    // Passo 2: Fazer download das alterações do local compartilhado para o dispositivo.
    await _downloadAlteracoesDaNuvem(licenseId);
  }

  // =======================================================================
  // <<< 3. LÓGICA DE UPLOAD ATUALIZADA >>>
  // =======================================================================
  /// Salva os dados locais (não sincronizados) no repositório compartilhado da licença.
  Future<void> _uploadAlteracoesLocais(String licenseId) async {
    final List<Parcela> parcelasNaoSincronizadas = await _dbHelper.getUnsyncedParcelas();
    if (parcelasNaoSincronizadas.isEmpty) return;

    final WriteBatch batch = _firestore.batch();
    
    for (final parcela in parcelasNaoSincronizadas) {
      final List<Arvore> arvores = await _dbHelper.getArvoresDaParcela(parcela.dbId!);
      
      // <<< MUDANÇA CRUCIAL: O CAMINHO AGORA APONTA PARA A LICENÇA >>>
      // A nova estrutura será: clientes/{id_da_licenca}/dados_coleta/{id_da_parcela}
      final docRef = _firestore
          .collection('clientes')
          .doc(licenseId)
          .collection('dados_coleta') // Subcoleção para os dados de campo
          .doc(parcela.dbId.toString());
      
      batch.set(docRef, parcela.toMap());

      for (final arvore in arvores) {
        final arvoreRef = docRef.collection('arvores').doc(arvore.id.toString());
        batch.set(arvoreRef, arvore.toMap());
      }
    }
    
    await batch.commit();

    // Após o sucesso do upload, marca as parcelas como sincronizadas localmente.
    final ids = parcelasNaoSincronizadas.map((p) => p.dbId!).toList();
    for (final id in ids) {
      await _dbHelper.markParcelaAsSynced(id);
    }
  }

  // =======================================================================
  // <<< 4. LÓGICA DE DOWNLOAD ATUALIZADA >>>
  // =======================================================================
  /// Baixa os dados do repositório compartilhado da licença e atualiza o banco local.
  Future<void> _downloadAlteracoesDaNuvem(String licenseId) async {
    // <<< MUDANÇA CRUCIAL: BUSCA OS DADOS DO CAMINHO COMPARTILHADO >>>
    final querySnapshot = await _firestore
        .collection('clientes')
        .doc(licenseId)
        .collection('dados_coleta')
        .get();

    for (final docSnapshot in querySnapshot.docs) {
      final parcelaDaNuvem = Parcela.fromMap(docSnapshot.data());
      
      final arvoresSnapshot = await docSnapshot.reference.collection('arvores').get();
      final arvoresDaNuvem = arvoresSnapshot.docs.map((doc) => Arvore.fromMap(doc.data())).toList();

      // O método saveFullColeta já lida com a lógica de inserir ou atualizar localmente.
      // Ele vai sobrescrever os dados locais com a versão mais recente da nuvem, garantindo
      // que todos os membros da equipe tenham os mesmos dados.
      await _dbHelper.saveFullColeta(parcelaDaNuvem, arvoresDaNuvem);
    }
  }
}