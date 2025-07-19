import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> sincronizarDados() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuário não está logado.");

    // Passo 1: Fazer upload das alterações locais
    await _uploadAlteracoesLocais(user.uid);

    // Passo 2: Fazer download das alterações da nuvem
    await _downloadAlteracoesDaNuvem(user.uid);
  }

  // --- LÓGICA DE UPLOAD ---
  Future<void> _uploadAlteracoesLocais(String uid) async {
    // Busca no SQLite apenas as parcelas que não foram sincronizadas
    final List<Parcela> parcelasNaoSincronizadas = await _dbHelper.getUnsyncedParcelas();

    if (parcelasNaoSincronizadas.isEmpty) return; // Nada para enviar

    final WriteBatch batch = _firestore.batch();
    
    for (final parcela in parcelasNaoSincronizadas) {
      final List<Arvore> arvores = await _dbHelper.getArvoresDaParcela(parcela.dbId!);
      
      // Referência para o documento da parcela na nuvem
      final docRef = _firestore.collection('clientes').doc(uid).collection('parcelas').doc(parcela.dbId.toString());
      
      // Adiciona a operação de escrita da parcela no batch
      batch.set(docRef, parcela.toMap());

      // Adiciona a escrita das árvores como uma subcoleção
      for(final arvore in arvores) {
        final arvoreRef = docRef.collection('arvores').doc(arvore.id.toString());
        batch.set(arvoreRef, arvore.toMap());
      }
    }
    
    // Envia todas as operações de uma vez
    await batch.commit();

    // Marca as parcelas como sincronizadas no banco local
    final ids = parcelasNaoSincronizadas.map((p) => p.dbId!).toList();
    for (final id in ids) {
        await _dbHelper.markParcelaAsSynced(id);
    }
  }

  // --- LÓGICA DE DOWNLOAD ---
  Future<void> _downloadAlteracoesDaNuvem(String uid) async {
    final querySnapshot = await _firestore.collection('clientes').doc(uid).collection('parcelas').get();

    for (final docSnapshot in querySnapshot.docs) {
      final parcelaDaNuvem = Parcela.fromMap(docSnapshot.data());
      
      // Baixa as árvores da subcoleção
      final arvoresSnapshot = await docSnapshot.reference.collection('arvores').get();
      final arvoresDaNuvem = arvoresSnapshot.docs.map((doc) => Arvore.fromMap(doc.data())).toList();

      // O método saveFullColeta já lida com a lógica de inserir ou atualizar.
      // Ele vai sobrescrever os dados locais com a versão mais recente da nuvem.
      await _dbHelper.saveFullColeta(parcelaDaNuvem, arvoresDaNuvem);
    }
  }
}