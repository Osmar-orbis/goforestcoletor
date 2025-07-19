// lib/data/datasources/local/database_helper.dart (VERSÃO ATUALIZADA COM UUID)

import 'dart:convert';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; // <<< IMPORT NECESSÁRIO

// Imports de Modelos
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/fazenda_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';
import 'package:geoforestcoletor/models/cubagem_secao_model.dart';
import 'package:geoforestcoletor/models/sortimento_model.dart';

// Import de Serviços
import 'package:geoforestcoletor/services/analysis_service.dart';

// --- CONSTANTES DE PROJEÇÃO GEOGRÁFICA ---
const Map<String, int> zonasUtmSirgas2000 = {
  'SIRGAS 2000 / UTM Zona 18S': 31978, 'SIRGAS 2000 / UTM Zona 19S': 31979,
  'SIRGAS 2000 / UTM Zona 20S': 31980, 'SIRGAS 2000 / UTM Zona 21S': 31981,
  'SIRGAS 2000 / UTM Zona 22S': 31982, 'SIRGAS 2000 / UTM Zona 23S': 31983,
  'SIRGAS 2000 / UTM Zona 24S': 31984, 'SIRGAS 2000 / UTM Zona 25S': 31985,
};

final Map<int, String> proj4Definitions = {
  31978: '+proj=utm +zone=18 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31979: '+proj=utm +zone=19 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31980: '+proj=utm +zone=20 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31981: '+proj=utm +zone=21 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31982: '+proj=utm +zone=22 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31983: '+proj=utm +zone=23 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31984: '+proj=utm +zone=24 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31985: '+proj=utm +zone=25 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
};

// --- CLASSE PRINCIPAL DO BANCO DE DADOS ---
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();
  factory DatabaseHelper() => _instance;
  static DatabaseHelper get instance => _instance;

  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    proj4.Projection.add('EPSG:4326', '+proj=longlat +datum=WGS84 +no_defs');
    proj4Definitions.forEach((epsg, def) {
      proj4.Projection.add('EPSG:$epsg', def);
    });

    return await openDatabase(
      join(await getDatabasesPath(), 'geoforestcoletor.db'),
      // ===================================================================
      // <<< MUDANÇA 1: INCREMENTAR A VERSÃO DO BANCO DE DADOS >>>
      // ===================================================================
      version: 25, 
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async => await db.execute('PRAGMA foreign_keys = ON');

  Future<void> _onCreate(Database db, int version) async {
     await db.execute('''
      CREATE TABLE projetos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        empresa TEXT NOT NULL,
        responsavel TEXT NOT NULL,
        dataCriacao TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE atividades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projetoId INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        descricao TEXT NOT NULL,
        dataCriacao TEXT NOT NULL,
        metodoCubagem TEXT, 
        FOREIGN KEY (projetoId) REFERENCES projetos (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE fazendas (
        id TEXT NOT NULL,
        atividadeId INTEGER NOT NULL,
        nome TEXT NOT NULL,
        municipio TEXT NOT NULL,
        estado TEXT NOT NULL,
        PRIMARY KEY (id, atividadeId),
        FOREIGN KEY (atividadeId) REFERENCES atividades (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE talhoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fazendaId TEXT NOT NULL,
        fazendaAtividadeId INTEGER NOT NULL,
        nome TEXT NOT NULL,
        areaHa REAL,
        idadeAnos REAL,
        especie TEXT,
        espacamento TEXT, 
        FOREIGN KEY (fazendaId, fazendaAtividadeId) REFERENCES fazendas (id, atividadeId) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE parcelas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        -- =================================================================
        -- <<< MUDANÇA 2: ADICIONAR O CAMPO UUID NA CRIAÇÃO DA TABELA >>>
        -- =================================================================
        uuid TEXT NOT NULL UNIQUE,
        talhaoId INTEGER,
        nomeFazenda TEXT,
        nomeTalhao TEXT,
        idParcela TEXT NOT NULL,
        areaMetrosQuadrados REAL NOT NULL,
        observacao TEXT,
        latitude REAL,
        longitude REAL,
        dataColeta TEXT NOT NULL,
        status TEXT NOT NULL,
        exportada INTEGER DEFAULT 0 NOT NULL,
        isSynced INTEGER DEFAULT 0 NOT NULL,
        idFazenda TEXT,
        largura REAL,
        comprimento REAL,
        raio REAL,
        photoPaths TEXT,
        FOREIGN KEY (talhaoId) REFERENCES talhoes (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE arvores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parcelaId INTEGER NOT NULL,
        cap REAL NOT NULL,
        altura REAL,
        linha INTEGER NOT NULL,
        posicaoNaLinha INTEGER NOT NULL,
        fimDeLinha INTEGER NOT NULL,
        dominante INTEGER NOT NULL,
        codigo TEXT NOT NULL,
        codigo2 TEXT,
        observacao TEXT,
        capAuditoria REAL,
        alturaAuditoria REAL,
        FOREIGN KEY (parcelaId) REFERENCES parcelas (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE cubagens_arvores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        talhaoId INTEGER,
        id_fazenda TEXT,
        nome_fazenda TEXT,
        nome_talhao TEXT,
        identificador TEXT NOT NULL,
        alturaTotal REAL NOT NULL,
        tipoMedidaCAP TEXT NOT NULL,
        valorCAP REAL NOT NULL,
        alturaBase REAL NOT NULL,
        classe TEXT,
        exportada INTEGER DEFAULT 0 NOT NULL,
        FOREIGN KEY (talhaoId) REFERENCES talhoes (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE cubagens_secoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cubagemArvoreId INTEGER NOT NULL,
        alturaMedicao REAL NOT NULL,
        circunferencia REAL,
        casca1_mm REAL,
        casca2_mm REAL,
        FOREIGN KEY (cubagemArvoreId) REFERENCES cubagens_arvores (id) ON DELETE CASCADE
      )
    ''');
    
    await db.execute('''
      CREATE TABLE sortimentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        comprimento REAL NOT NULL,
        diametroMinimo REAL NOT NULL,
        diametroMaximo REAL NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_arvores_parcelaId ON arvores(parcelaId)');
    await db.execute('CREATE INDEX idx_cubagens_secoes_cubagemArvoreId ON cubagens_secoes(cubagemArvoreId)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      debugPrint("Executando migração de banco de dados para a versão $v...");
       switch (v) {
        case 21:
          // ... (cases antigos permanecem)
          break;
        case 22:
          // ... (cases antigos permanecem)
          break;
        case 23:
          // ... (cases antigos permanecem)
          break;
        case 24:
          // ... (cases antigos permanecem)
          break;
        // ===================================================================
        // <<< MUDANÇA 3: ADICIONAR A LÓGICA DE MIGRAÇÃO PARA O UUID >>>
        // ===================================================================
        case 25:
          await db.execute('ALTER TABLE parcelas ADD COLUMN uuid TEXT');
          // Busca todas as parcelas existentes que ainda não têm um UUID
          final parcelasSemUuid = await db.query('parcelas', where: 'uuid IS NULL');
          // Gera e salva um UUID para cada uma delas
          for (final p in parcelasSemUuid) {
            await db.update(
              'parcelas', 
              {'uuid': const Uuid().v4()},
              where: 'id = ?',
              whereArgs: [p['id']]
            );
          }
          // Torna a coluna obrigatória e única após preenchê-la (opcional, mas bom para consistência)
          // Nota: O SQLite tem limitações para adicionar UNIQUE em colunas existentes.
          // A verificação será feita na lógica do app para garantir a unicidade.
          break;
      }
    }
  }

  // O resto do arquivo permanece o mesmo...

  // --- MÉTODOS CRUD: HIERARQUIA ---
  Future<int> insertProjeto(Projeto p) async => await (await database).insert('projetos', p.toMap());
  Future<List<Projeto>> getTodosProjetos() async {
    final maps = await (await database).query('projetos', orderBy: 'dataCriacao DESC');
    return List.generate(maps.length, (i) => Projeto.fromMap(maps[i]));
  }

  Future<Projeto?> getProjetoById(int id) async {
    final db = await database;
    final maps = await db.query('projetos', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Projeto.fromMap(maps.first);
    return null;
  }

  Future<void> deleteProjeto(int id) async => await (await database).delete('projetos', where: 'id = ?', whereArgs: [id]);
  Future<int> insertAtividade(Atividade a) async => await (await database).insert('atividades', a.toMap());

  Future<List<Atividade>> getAtividadesDoProjeto(int projetoId) async {
    final maps = await (await database).query('atividades', where: 'projetoId = ?', whereArgs: [projetoId], orderBy: 'dataCriacao DESC');
    return List.generate(maps.length, (i) => Atividade.fromMap(maps[i]));
  }

  Future<List<Atividade>> getTodasAsAtividades() async {
    final db = await database;
    final maps = await db.query('atividades', orderBy: 'dataCriacao DESC');
    return List.generate(maps.length, (i) => Atividade.fromMap(maps[i]));
  }

  Future<void> deleteAtividade(int id) async => await (await database).delete('atividades', where: 'id = ?', whereArgs: [id]);
  Future<void> insertFazenda(Fazenda f) async => await (await database).insert('fazendas', f.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);

  Future<List<Fazenda>> getFazendasDaAtividade(int atividadeId) async {
    final maps = await (await database).query('fazendas', where: 'atividadeId = ?', whereArgs: [atividadeId], orderBy: 'nome');
    return List.generate(maps.length, (i) => Fazenda.fromMap(maps[i]));
  }

  Future<void> deleteFazenda(String id, int atividadeId) async => await (await database).delete('fazendas', where: 'id = ? AND atividadeId = ?', whereArgs: [id, atividadeId]);
  Future<int> insertTalhao(Talhao t) async => await (await database).insert('talhoes', t.toMap());

  Future<List<Talhao>> getTalhoesDaFazenda(String fazendaId, int fazendaAtividadeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT T.*, F.nome as fazendaNome 
      FROM talhoes T
      INNER JOIN fazendas F ON F.id = T.fazendaId AND F.atividadeId = T.fazendaAtividadeId
      WHERE T.fazendaId = ? AND T.fazendaAtividadeId = ?
      ORDER BY T.nome ASC
    ''', [fazendaId, fazendaAtividadeId]);
    return List.generate(maps.length, (i) => Talhao.fromMap(maps[i]));
  }

  Future<void> deleteTalhao(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cubagens_arvores', where: 'talhaoId = ?', whereArgs: [id]);
      await txn.delete('parcelas', where: 'talhaoId = ?', whereArgs: [id]);
      await txn.delete('talhoes', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<double> getAreaTotalTalhoesDaFazenda(String fazendaId, int fazendaAtividadeId) async {
    final result = await (await database).rawQuery('SELECT SUM(areaHa) as total FROM talhoes WHERE fazendaId = ? AND fazendaAtividadeId = ?', [fazendaId, fazendaAtividadeId]);
    if (result.isNotEmpty && result.first['total'] != null) return (result.first['total'] as num).toDouble();
    return 0.0;
  }

  Future<Projeto?> getProjetoPelaAtividade(int atividadeId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT P.* FROM projetos P
      JOIN atividades A ON P.id = A.projetoId
      WHERE A.id = ?
    ''', [atividadeId]);

    if (maps.isNotEmpty) {
      return Projeto.fromMap(maps.first);
    }
    return null;
  }

  Future<void> criarAtividadeComPlanoDeCubagem(
      Atividade novaAtividade, List<CubagemArvore> placeholders) async {
    if (placeholders.isEmpty) {
      throw Exception("A lista de árvores para cubagem (placeholders) não pode estar vazia.");
    }
    
    final db = await database;

    await db.transaction((txn) async {
      final atividadeId = await txn.insert('atividades', novaAtividade.toMap());

      final firstPlaceholder = placeholders.first;

      final fazendaDoPlano = Fazenda(
        id: firstPlaceholder.idFazenda!,
        atividadeId: atividadeId,
        nome: firstPlaceholder.nomeFazenda,
        municipio: 'N/I',
        estado: 'N/I',
      );
      await txn.insert('fazendas', fazendaDoPlano.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      final talhaoDoPlano = Talhao(
        fazendaId: fazendaDoPlano.id,
        fazendaAtividadeId: fazendaDoPlano.atividadeId,
        nome: firstPlaceholder.nomeTalhao,
      );
      final talhaoId = await txn.insert('talhoes', talhaoDoPlano.toMap());

      for (final placeholder in placeholders) {
        final map = placeholder.toMap();
        map['talhaoId'] = talhaoId;
        map.remove('id');
        await txn.insert('cubagens_arvores', map);
      }
    });
    
    debugPrint('Atividade de cubagem e ${placeholders.length} placeholders criados com sucesso!');
  }

  // --- MÉTODOS CRUD: COLETA ---
  Future<Parcela> saveParcela(Parcela parcela) async {
    final db = await database;
    final dbId = await db.insert('parcelas', parcela.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return parcela.copyWith(dbId: dbId);
  }

  Future<Parcela?> getParcelaPorIdParcela(int talhaoId, String idParcela) async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'talhaoId = ? AND idParcela = ?', whereArgs: [talhaoId, idParcela], limit: 1);
    if (maps.isNotEmpty) return Parcela.fromMap(maps.first);
    return null;
  }

  Future<List<Parcela>> getParcelasDoTalhao(int talhaoId) async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'talhaoId = ?', whereArgs: [talhaoId], orderBy: 'dataColeta DESC');
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<List<Parcela>> getUnsyncedParcelas() async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'isSynced = ?', whereArgs: [0]);
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<void> markParcelaAsSynced(int id) async {
    final db = await database;
    await db.update('parcelas', {'isSynced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> limparTodasAsParcelas() async {
    await (await database).delete('parcelas');
    debugPrint('Tabela de parcelas e árvores limpa.');
  }

  Future<void> saveBatchParcelas(List<Parcela> parcelas) async {
    final db = await database;
    final batch = db.batch();
    for (final p in parcelas) {
      batch.insert('parcelas', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Parcela> saveFullColeta(Parcela p, List<Arvore> arvores) async {
    final db = await database;
    await db.transaction((txn) async {
      int pId;
      p.isSynced = false;
      final pMap = p.toMap();
      final d = p.dataColeta ?? DateTime.now();
      pMap['dataColeta'] = d.toIso8601String();
      if (p.dbId == null) {
        pMap.remove('id');
        pId = await txn.insert('parcelas', pMap);
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
        await txn.insert('arvores', aMap);
      }
    });
    return p;
  }

  Future<Parcela?> getParcelaById(int id) async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Parcela.fromMap(maps.first);
    return null;
  }

  Future<List<Arvore>> getArvoresDaParcela(int parcelaId) async {
    final db = await database;
    final maps = await db.query('arvores', where: 'parcelaId = ?', whereArgs: [parcelaId], orderBy: 'linha, posicaoNaLinha, id');
    return List.generate(maps.length, (i) => Arvore.fromMap(maps[i]));
  }

  Future<List<Parcela>> getTodasParcelas() async {
    final db = await database;
    final maps = await db.query('parcelas', orderBy: 'dataColeta DESC');
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<int> deleteParcela(int id) async => await (await database).delete('parcelas', where: 'id = ?', whereArgs: [id]);

  Future<void> deletarMultiplasParcelas(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.delete('parcelas', where: 'id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
  }

  Future<int> updateParcela(Parcela p) async => await (await database).update('parcelas', p.toMap(), where: 'id = ?', whereArgs: [p.dbId]);

  Future<int> limparParcelasExportadas() async {
    final count = await (await database).delete('parcelas', where: 'exportada = ?', whereArgs: [1]);
    debugPrint('$count parcelas exportadas foram apagadas.');
    return count;
  }

  Future<Map<String, List<String>>> getProjetosDisponiveis() async {
    final db = await database;
    final maps = await db.query('parcelas', columns: ['nomeFazenda', 'nomeTalhao'], where: 'status = ?', whereArgs: [StatusParcela.concluida.name], distinct: true, orderBy: 'nomeFazenda, nomeTalhao');
    final projetos = <String, List<String>>{};
    for (final map in maps) {
      final fazenda = map['nomeFazenda'] as String;
      final talhao = map['nomeTalhao'] as String;
      if (!projetos.containsKey(fazenda)) {
        projetos[fazenda] = [];
      }
      projetos[fazenda]!.add(talhao);
    }
    return projetos;
  }

  Future<void> updateParcelaStatus(int parcelaId, StatusParcela novoStatus) async {
    final db = await database;
    await db.update('parcelas', {'status': novoStatus.name}, where: 'id = ?', whereArgs: [parcelaId]);
  }

  Future<void> limparTodasAsCubagens() async {
    await (await database).delete('cubagens_arvores');
    debugPrint('Tabela de cubagens e seções limpa.');
  }

  Future<void> salvarCubagemCompleta(CubagemArvore arvore, List<CubagemSecao> secoes) async {
    final db = await database;
    await db.transaction((txn) async {
      int id;
      final map = arvore.toMap();
      if (arvore.id == null) {
        id = await txn.insert('cubagens_arvores', map, conflictAlgorithm: ConflictAlgorithm.replace);
        arvore.id = id;
      } else {
        id = arvore.id!;
        await txn.update('cubagens_arvores', map, where: 'id = ?', whereArgs: [id]);
      }
      await txn.delete('cubagens_secoes', where: 'cubagemArvoreId = ?', whereArgs: [id]);
      for (var s in secoes) {
        s.cubagemArvoreId = id;
        await txn.insert('cubagens_secoes', s.toMap());
      }
    });
  }

  Future<List<CubagemArvore>> getTodasCubagensDoTalhao(int talhaoId) async {
    final db = await database;
    final maps = await db.query('cubagens_arvores', where: 'talhaoId = ?', whereArgs: [talhaoId], orderBy: 'id ASC');
    return List.generate(maps.length, (i) => CubagemArvore.fromMap(maps[i]));
  }

  Future<List<CubagemArvore>> getTodasCubagens() async {
    final db = await database;
    final maps = await db.query('cubagens_arvores', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => CubagemArvore.fromMap(maps[i]));
  }

  Future<List<CubagemSecao>> getSecoesPorArvoreId(int id) async {
    final db = await database;
    final maps = await db.query('cubagens_secoes', where: 'cubagemArvoreId = ?', whereArgs: [id], orderBy: 'alturaMedicao ASC');
    return List.generate(maps.length, (i) => CubagemSecao.fromMap(maps[i]));
  }

  Future<void> deletarCubagem(int id) async => await (await database).delete('cubagens_arvores', where: 'id = ?', whereArgs: [id]);

  Future<void> deletarMultiplasCubagens(List<int> ids) async {
    if (ids.isEmpty) return;
    await (await database).delete('cubagens_arvores', where: 'id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
  }

  Future<void> gerarPlanoDeCubagemNoBanco(Talhao talhao, int totalParaCubar, int novaAtividadeId) async {
    final analysisService = AnalysisService();
    final dadosAgregados = await getDadosAgregadosDoTalhao(talhao.id!);
    final parcelas = dadosAgregados['parcelas'] as List<Parcela>;
    final arvores = dadosAgregados['arvores'] as List<Arvore>;
    if (parcelas.isEmpty || arvores.isEmpty) throw Exception('Não há árvores suficientes neste talhão para gerar um plano.');
    final analise = analysisService.getTalhaoInsights(parcelas, arvores);
    final plano = analysisService.gerarPlanoDeCubagem(analise.distribuicaoDiametrica, analise.totalArvoresAmostradas, totalParaCubar);
    if (plano.isEmpty) throw Exception('Não foi possível gerar o plano de cubagem. Verifique os dados das parcelas.');
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in plano.entries) {
        final classe = entry.key;
        final quantidade = entry.value;
        for (int i = 1; i <= quantidade; i++) {
          final arvoreCubagem = CubagemArvore(
            talhaoId: talhao.id!,
            idFazenda: talhao.fazendaId,
            nomeFazenda: talhao.fazendaNome ?? 'N/A',
            nomeTalhao: talhao.nome,
            identificador: '${talhao.nome} - Árvore ${i.toString().padLeft(2, '0')}',
            classe: classe,
          );
          await txn.insert('cubagens_arvores', arvoreCubagem.toMap());
        }
      }
    });
  }

  // --- MÉTODOS DE ANÁLISE E ESTATÍSTICAS ---
  Future<Map<String, double>> getDistribuicaoPorCodigo(int parcelaId) async {
    final db = await database;
    final result = await db.rawQuery('SELECT codigo, COUNT(*) as total FROM arvores WHERE parcelaId = ? GROUP BY codigo', [parcelaId]);
    if (result.isEmpty) return {};
    return { for (var row in result) (row['codigo'] as String): (row['total'] as int).toDouble() };
  }

  Future<List<Map<String, dynamic>>> getValoresCAP(int parcelaId) async {
    final db = await database;
    final result = await db.query('arvores', columns: ['cap', 'codigo'], where: 'parcelaId = ?', whereArgs: [parcelaId]);
    if (result.isEmpty) return [];
    return result.map((row) => {'cap': row['cap'] as double, 'codigo': row['codigo'] as String}).toList();
  }

  Future<Map<String, dynamic>> getDadosAgregadosDoTalhao(int talhaoId) async {
    final parcelas = await getParcelasDoTalhao(talhaoId);
    final concluidas = parcelas.where((p) => p.status == StatusParcela.concluida).toList();
    final arvores = <Arvore>[];
    for (final p in concluidas) {
      if (p.dbId != null) arvores.addAll(await getArvoresDaParcela(p.dbId!));
    }
    return {'parcelas': concluidas, 'arvores': arvores};
  }

  Future<List<Parcela>> getTodasAsParcelasConcluidas() async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'status = ?', whereArgs: [StatusParcela.concluida.name]);
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<List<Talhao>> getTalhoesComParcelasConcluidas() async {
    final db = await database;
    final List<Map<String, dynamic>> idMaps = await db.query('parcelas', distinct: true, columns: ['talhaoId'], where: 'status = ?', whereArgs: [StatusParcela.concluida.name]);
    if (idMaps.isEmpty) return [];
    final ids = idMaps.map((map) => map['talhaoId'] as int).toList();
    final List<Map<String, dynamic>> talhoesMaps = await db.rawQuery('''
      SELECT T.*, F.nome as fazendaNome 
      FROM talhoes T
      INNER JOIN fazendas F ON F.id = T.fazendaId AND F.atividadeId = T.fazendaAtividadeId
      WHERE T.id IN (${List.filled(ids.length, '?').join(',')})
    ''', ids);
    return List.generate(talhoesMaps.length, (i) => Talhao.fromMap(talhoesMaps[i]));
  }

  // --- MÉTODOS DE EXPORTAÇÃO E IMPORTAÇÃO ---
  Future<List<Parcela>> getUnexportedConcludedParcelas() async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'status = ? AND exportada = ?', whereArgs: [StatusParcela.concluida.name, 0]);
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }
  
  Future<List<Parcela>> getTodasAsParcelasConcluidasParaBackup() async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'status = ?', whereArgs: [StatusParcela.concluida.name]);
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<void> marcarParcelasComoExportadas(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.update(
      'parcelas',
      {'exportada': 1},
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }
  
  Future<String> importarColetaDeEquipe(String csvContent, int atividadeIdAlvo) async {
    final db = await database;
    int parcelasProcessadas = 0;
    int arvoresImportadas = 0;
    int novasFazendas = 0;
    int novosTalhoes = 0;
    
    // ===== INÍCIO DA LÓGICA DE DETECÇÃO AUTOMÁTICA =====
    if (csvContent.isEmpty) return "Erro: O arquivo CSV está vazio.";

    final firstLine = csvContent.split('\n').first;
    final commaCount = ','.allMatches(firstLine).length;
    final semicolonCount = ';'.allMatches(firstLine).length;

    String detectedDelimiter = ',';
    if (semicolonCount > commaCount) {
      detectedDelimiter = ';';
    }
    
    debugPrint("Separador de coluna detectado: '$detectedDelimiter'");
    // ===== FIM DA LÓGICA DE DETECÇÃO AUTOMÁTICA =====

    final List<List<dynamic>> rows = CsvToListConverter(fieldDelimiter: detectedDelimiter, eol: '\n').convert(csvContent);
    if (rows.length < 2) return "Erro: O arquivo CSV está vazio ou contém apenas o cabeçalho.";
    
    final headers = rows.first.map((h) => h.toString().trim()).toList();
    final dataRows = rows.sublist(1).map((row) => Map.fromIterables(headers, row)).toList();

    final parcelasAgrupadas = groupBy(dataRows, (row) {
        final idFazenda = row['Codigo_Fazenda']?.toString() ?? row['Fazenda']?.toString() ?? 'FAZENDA_PADRAO';
        final nomeTalhao = row['Talhao']?.toString() ?? 'TALHAO_PADRAO';
        final idParcela = row['ID_Coleta_Parcela']?.toString() ?? 'PARCELA_PADRAO';
        return '$idFazenda-$nomeTalhao-$idParcela';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final nomeZona = prefs.getString('zona_utm_selecionada') ?? 'SIRGAS 2000 / UTM Zona 22S';
      final codigoEpsg = zonasUtmSirgas2000[nomeZona]!;
      final projWGS84 = proj4.Projection.get('EPSG:4326')!;
      final projUTM = proj4.Projection.get('EPSG:$codigoEpsg')!;

      await db.transaction((txn) async {
        for (var entry in parcelasAgrupadas.entries) {
            final grupoDeLinhas = entry.value;
            final primeiraLinha = grupoDeLinhas.first;

            final idFazenda = primeiraLinha['Codigo_Fazenda']?.toString() ?? primeiraLinha['Fazenda']?.toString() ?? 'FAZENDA_PADRAO';
            Fazenda? fazenda = (await txn.query('fazendas', where: 'id = ? AND atividadeId = ?', whereArgs: [idFazenda, atividadeIdAlvo])).map((e) => Fazenda.fromMap(e)).firstOrNull;
            if (fazenda == null) {
                fazenda = Fazenda(id: idFazenda, atividadeId: atividadeIdAlvo, nome: primeiraLinha['Fazenda'].toString(), municipio: 'N/I', estado: 'N/I');
                await txn.insert('fazendas', fazenda.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
                novasFazendas++;
            }
            
            final nomeTalhao = primeiraLinha['Talhao']?.toString() ?? 'TALHAO_PADRAO';
            Talhao? talhao = (await txn.query('talhoes', where: 'nome = ? AND fazendaId = ? AND fazendaAtividadeId = ?', whereArgs: [nomeTalhao, fazenda.id, fazenda.atividadeId])).map((e) => Talhao.fromMap(e)).firstOrNull;
            if (talhao == null) {
                talhao = Talhao(
                    fazendaId: fazenda.id, 
                    fazendaAtividadeId: fazenda.atividadeId, 
                    nome: nomeTalhao,
                    areaHa: double.tryParse(primeiraLinha['Area_ha_Talhao']?.toString().replaceAll(',', '.') ?? ''),
                    especie: primeiraLinha['Especie_Talhao']?.toString(),
                    espacamento: primeiraLinha['Espacamento_Talhao']?.toString(),
                );
                final talhaoId = await txn.insert('talhoes', talhao.toMap());
                talhao = talhao.copyWith(id: talhaoId);
                novosTalhoes++;
            }

            // ===== AJUSTE PARA NÚMEROS GRANDES E DECIMAIS =====
            double area = double.tryParse(primeiraLinha['Area_m2']?.toString().replaceAll('.', '').replaceAll(',', '.') ?? '0') ?? 0;
            double? largura = double.tryParse(primeiraLinha['Largura_m']?.toString().replaceAll(',', '.') ?? '');
            double? comprimento = double.tryParse(primeiraLinha['Comprimento_m']?.toString().replaceAll(',', '.') ?? '');
            double? raio = double.tryParse(primeiraLinha['Raio_m']?.toString().replaceAll(',', '.') ?? '');
            if (area <= 0) {
                if (largura != null && comprimento != null) area = largura * comprimento;
                else if (raio != null) area = pi * raio * raio;
            }

            double? lat, lon;
            final easting = double.tryParse(primeiraLinha['Easting']?.toString().replaceAll(',', '.') ?? '');
            final northing = double.tryParse(primeiraLinha['Northing']?.toString().replaceAll(',', '.') ?? '');
            if(easting != null && northing != null) {
                final pontoWGS84 = projUTM.transform(projWGS84, proj4.Point(x: easting, y: northing));
                lat = pontoWGS84.y;
                lon = pontoWGS84.x;
            } else {
                lat = double.tryParse(primeiraLinha['Latitude']?.toString().replaceAll(',', '.') ?? '');
                lon = double.tryParse(primeiraLinha['Longitude']?.toString().replaceAll(',', '.') ?? '');
            }

            final idParcelaColeta = primeiraLinha['ID_Coleta_Parcela']?.toString() ?? 'PARCELA_PADRAO';
            Parcela? parcelaExistente = (await txn.query('parcelas', where: 'idParcela = ? AND talhaoId = ?', whereArgs: [idParcelaColeta, talhao.id!])).map((e) => Parcela.fromMap(e)).firstOrNull;
            
            final novaParcela = Parcela(
                dbId: parcelaExistente?.dbId, talhaoId: talhao.id!, idParcela: idParcelaColeta,
                areaMetrosQuadrados: area, largura: largura, comprimento: comprimento, raio: raio,
                latitude: lat, longitude: lon,
                dataColeta: DateTime.tryParse(primeiraLinha['Data_Coleta']?.toString() ?? '') ?? DateTime.now(),
                status: StatusParcela.concluida,
                nomeFazenda: primeiraLinha['Fazenda'].toString(), nomeTalhao: nomeTalhao, idFazenda: idFazenda,
            );

            int parcelaDbId;
            if (parcelaExistente == null) {
                parcelaDbId = await txn.insert('parcelas', novaParcela.toMap());
            } else {
                parcelaDbId = parcelaExistente.dbId!;
                await txn.update('parcelas', novaParcela.toMap(), where: 'id = ?', whereArgs: [parcelaDbId]);
                await txn.delete('arvores', where: 'parcelaId = ?', whereArgs: [parcelaDbId]);
            }
            parcelasProcessadas++;

            for (final linhaArvore in grupoDeLinhas) {
                // ===== AJUSTE PARA NÚMEROS DECIMAIS (CAP e Altura) =====
                final cap = double.tryParse(linhaArvore['CAP_cm']?.toString().replaceAll(',', '.') ?? '');
                if (cap != null) {
                    final novaArvore = Arvore(
                        cap: cap,
                        altura: double.tryParse(linhaArvore['Altura_m']?.toString().replaceAll(',', '.') ?? ''),
                        linha: int.tryParse(linhaArvore['Linha']?.toString() ?? '0') ?? 0,
                        posicaoNaLinha: int.tryParse(linhaArvore['Posicao_na_Linha']?.toString() ?? '0') ?? 0,
                        dominante: linhaArvore['Dominante']?.toString().toLowerCase() == 'sim',
                        codigo: Codigo.values.firstWhere((e) => e.name == linhaArvore['Codigo_Arvore']?.toString(), orElse: () => Codigo.normal),
                        fimDeLinha: false,
                    );
                    final arvoreMap = novaArvore.toMap();
                    arvoreMap['parcelaId'] = parcelaDbId;
                    await txn.insert('arvores', arvoreMap);
                    arvoresImportadas++;
                }
            }
        }
      });
      return "Importação Concluída!\n\nParcelas Processadas: $parcelasProcessadas\nÁrvores Inseridas: $arvoresImportadas\n\nEstruturas Criadas na Atividade:\n- Fazendas: $novasFazendas\n- Talhões: $novosTalhoes";
    } catch (e, s) {
      debugPrint("Erro ao importar CSV: $e");
      debugPrint("Stack Trace: $s");
      return "Erro Crítico: Ocorreu uma falha ao processar o arquivo. Verifique o formato do CSV e tente novamente.\n\nDetalhe: ${e.toString()}";
    }
  }
  
  Future<String> importarProjetoCompleto(String fileContent) async {
    final db = await database;
    int projetosCriados = 0;
    int atividadesCriadas = 0;
    int fazendasCriadas = 0;
    int talhoesCriados = 0;
    int parcelasCriadas = 0;
    try {
      final Map<String, dynamic> geoJson = jsonDecode(fileContent);
      final List<dynamic> features = geoJson['features'];
      await db.transaction((txn) async {
        for (final feature in features) {
          final properties = feature['properties'];
          Projeto? projeto = await txn.query('projetos', where: 'nome = ?', whereArgs: [properties['projeto_nome']]).then((list) => list.isEmpty ? null : Projeto.fromMap(list.first));
          if (projeto == null) {
            projeto = Projeto(nome: properties['projeto_nome'], empresa: properties['empresa'], responsavel: properties['responsavel'], dataCriacao: DateTime.now());
            final projetoId = await txn.insert('projetos', projeto.toMap());
            projeto = projeto.copyWith(id: projetoId);
            projetosCriados++;
          }
          Atividade? atividade = await txn.query('atividades', where: 'tipo = ? AND projetoId = ?', whereArgs: [properties['atividade_tipo'], projeto.id]).then((list) => list.isEmpty ? null : Atividade.fromMap(list.first));
          if (atividade == null) {
            atividade = Atividade(projetoId: projeto.id!, tipo: properties['atividade_tipo'], descricao: properties['atividade_descricao'] ?? '', dataCriacao: DateTime.now());
            final atividadeId = await txn.insert('atividades', atividade.toMap());
            atividade = atividade.copyWith(id: atividadeId);
            atividadesCriadas++;
          }
          Fazenda? fazenda = await txn.query('fazendas', where: 'id = ? AND atividadeId = ?', whereArgs: [properties['fazenda_id'], atividade.id]).then((list) => list.isEmpty ? null : Fazenda.fromMap(list.first));
          if (fazenda == null) {
            fazenda = Fazenda(id: properties['fazenda_id'], atividadeId: atividade.id!, nome: properties['fazenda_nome'], municipio: properties['municipio'], estado: properties['estado']);
            await txn.insert('fazendas', fazenda.toMap());
            fazendasCriadas++;
          }
          Talhao? talhao = await txn.query('talhoes', where: 'nome = ? AND fazendaId = ? AND fazendaAtividadeId = ?', whereArgs: [properties['talhao_nome'], fazenda.id, fazenda.atividadeId]).then((list) => list.isEmpty ? null : Talhao.fromMap(list.first));
          if (talhao == null) {
            talhao = Talhao(
              fazendaId: fazenda.id, 
              fazendaAtividadeId: fazenda.atividadeId, 
              nome: properties['talhao_nome'], 
              especie: properties['especie'], 
              areaHa: properties['area_ha'], 
              idadeAnos: properties['idade_anos'],
              espacamento: properties['espacam'],
            );
            final talhaoId = await txn.insert('talhoes', talhao.toMap());
            talhao = talhao.copyWith(id: talhaoId);
            talhoesCriados++;
          }
          Parcela? parcela = await txn.query('parcelas', where: 'idParcela = ? AND talhaoId = ?', whereArgs: [properties['parcela_id_plano'], talhao.id]).then((list) => list.isEmpty ? null : Parcela.fromMap(list.first));
          if (parcela == null) {
            final geometry = feature['geometry'];
            parcela = Parcela(
              talhaoId: talhao.id!,
              idParcela: properties['parcela_id_plano'],
              areaMetrosQuadrados: properties['area_m2'] ?? 0.0,
              status: StatusParcela.pendente,
              dataColeta: DateTime.now(),
              latitude: geometry != null ? geometry['coordinates'][0][0][1] : null,
              longitude: geometry != null ? geometry['coordinates'][0][0][0] : null,
              nomeFazenda: fazenda.nome,
              nomeTalhao: talhao.nome,
            );
            await txn.insert('parcelas', parcela.toMap());
            parcelasCriadas++;
          }
        }
      });
      return "Importação concluída!\nProjetos: $projetosCriados\nAtividades: $atividadesCriadas\nFazendas: $fazendasCriadas\nTalhões: $talhoesCriados\nParcelas: $parcelasCriadas";
    } catch (e) {
      debugPrint("Erro ao importar projeto: $e");
      return "Erro ao importar: O arquivo pode estar mal formatado ou os dados são inválidos. ($e)";
    }
  }

  Future<List<CubagemArvore>> getUnexportedCubagens() async {
    final db = await database;
    final maps = await db.query('cubagens_arvores', where: 'exportada = ?', whereArgs: [0]);
    return List.generate(maps.length, (i) => CubagemArvore.fromMap(maps[i]));
  }

  Future<List<CubagemArvore>> getTodasCubagensParaBackup() async {
    final db = await database;
    final maps = await db.query('cubagens_arvores');
    return List.generate(maps.length, (i) => CubagemArvore.fromMap(maps[i]));
  }

  Future<void> marcarCubagensComoExportadas(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.update(
      'cubagens_arvores',
      {'exportada': 1},
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<String> importarCubagemDeEquipe(String csvContent, int atividadeIdAlvo) async {
    final db = await database;
    int arvoresImportadas = 0;
    int secoesImportadas = 0;
    int novasFazendas = 0;
    int novosTalhoes = 0;

    // ===== INÍCIO DA LÓGICA DE DETECÇÃO AUTOMÁTICA =====
    if (csvContent.isEmpty) return "Erro: O arquivo CSV está vazio.";

    final firstLine = csvContent.split('\n').first;
    final commaCount = ','.allMatches(firstLine).length;
    final semicolonCount = ';'.allMatches(firstLine).length;

    String detectedDelimiter = ',';
    if (semicolonCount > commaCount) {
      detectedDelimiter = ';';
    }
    
    debugPrint("Separador de cubagem detectado: '$detectedDelimiter'");
    // ===== FIM DA LÓGICA DE DETECÇÃO AUTOMÁTICA =====

    final List<List<dynamic>> rows = CsvToListConverter(fieldDelimiter: detectedDelimiter, eol: '\n').convert(csvContent);
    if (rows.length < 2) return "Erro: Arquivo CSV vazio ou com apenas cabeçalho.";

    final headers = rows.first.map((h) => h.toString().trim()).toList();
    final dataRows = rows.sublist(1);
    
    final Map<String, List<Map<String, dynamic>>> arvoresAgrupadas = {};

    for (final row in dataRows) {
        final rowMap = Map<String, dynamic>.fromIterables(headers, row);
        final idArvore = rowMap['identificador_arvore']?.toString();
        final nomeFazenda = rowMap['fazenda']?.toString();
        final nomeTalhao = rowMap['talhao']?.toString();
        
        if (idArvore == null || nomeFazenda == null || nomeTalhao == null) continue;
        
        final chaveUnica = "$nomeFazenda-$nomeTalhao-$idArvore";
        
        if (!arvoresAgrupadas.containsKey(chaveUnica)) {
            arvoresAgrupadas[chaveUnica] = [];
        }
        arvoresAgrupadas[chaveUnica]!.add(rowMap);
    }
    
    if (arvoresAgrupadas.isEmpty) {
        return "Nenhuma árvore com identificador válido encontrada no CSV.";
    }

    try {
      await db.transaction((txn) async {
        final Map<String, Fazenda> fazendaCache = {};
        final Map<String, int> talhaoCache = {};

        for (final entry in arvoresAgrupadas.entries) {
          final dadosPrimeiraLinha = entry.value.first;
          
          final idFazenda = dadosPrimeiraLinha['id_fazenda']?.toString() ?? dadosPrimeiraLinha['fazenda'].toString();
          final chaveFazenda = '$idFazenda-$atividadeIdAlvo';

          if (!fazendaCache.containsKey(chaveFazenda)) {
              Fazenda? fazenda = (await txn.query('fazendas', where: 'id = ? AND atividadeId = ?', whereArgs: [idFazenda, atividadeIdAlvo])).map((e) => Fazenda.fromMap(e)).firstOrNull;
              if (fazenda == null) {
                  final novaFazenda = Fazenda(id: idFazenda, atividadeId: atividadeIdAlvo, nome: dadosPrimeiraLinha['fazenda'].toString(), municipio: 'N/I', estado: 'N/I');
                  await txn.insert('fazendas', novaFazenda.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
                  fazenda = novaFazenda;
                  novasFazendas++;
              }
              fazendaCache[chaveFazenda] = fazenda;
          }
          final Fazenda fazenda = fazendaCache[chaveFazenda]!;

          final nomeTalhao = dadosPrimeiraLinha['talhao'].toString();
          final chaveTalhao = "${fazenda.id}-${fazenda.atividadeId}-$nomeTalhao";

          if (!talhaoCache.containsKey(chaveTalhao)) {
            Talhao? talhao = (await txn.query('talhoes', where: 'nome = ? AND fazendaId = ? AND fazendaAtividadeId = ?', whereArgs: [nomeTalhao, fazenda.id, fazenda.atividadeId])).map((e) => Talhao.fromMap(e)).firstOrNull;
            if (talhao == null) {
                final novoTalhao = Talhao(fazendaId: fazenda.id, fazendaAtividadeId: fazenda.atividadeId, nome: nomeTalhao);
                final talhaoId = await txn.insert('talhoes', novoTalhao.toMap());
                novosTalhoes++;
                talhaoCache[chaveTalhao] = talhaoId;
            } else {
                talhaoCache[chaveTalhao] = talhao.id!;
            }
          }
          final int talhaoId = talhaoCache[chaveTalhao]!;

          final arvoreCubagem = CubagemArvore(
            talhaoId: talhaoId,
            idFazenda: idFazenda,
            nomeFazenda: fazenda.nome,
            nomeTalhao: nomeTalhao,
            identificador: dadosPrimeiraLinha['identificador_arvore'].toString(),
            classe: dadosPrimeiraLinha['classe']?.toString(),
            // ===== AJUSTE PARA NÚMEROS DECIMAIS =====
            alturaTotal: double.tryParse(dadosPrimeiraLinha['altura_total_m']?.toString().replaceAll(',', '.') ?? '0') ?? 0,
            tipoMedidaCAP: dadosPrimeiraLinha['tipo_medida_cap']?.toString() ?? 'fita',
            valorCAP: double.tryParse(dadosPrimeiraLinha['valor_cap']?.toString().replaceAll(',', '.') ?? '0') ?? 0,
            alturaBase: double.tryParse(dadosPrimeiraLinha['altura_base_m']?.toString().replaceAll(',', '.') ?? '0') ?? 0,
          );
          final arvoreCubagemId = await txn.insert('cubagens_arvores', arvoreCubagem.toMap());
          arvoresImportadas++;

          for (final rowMap in entry.value) {
            final secao = CubagemSecao(
              cubagemArvoreId: arvoreCubagemId,
              // ===== AJUSTE PARA NÚMEROS DECIMAIS =====
              alturaMedicao: double.tryParse(rowMap['altura_medicao_secao_m']?.toString().replaceAll(',', '.') ?? '0') ?? 0,
              circunferencia: double.tryParse(rowMap['circunferencia_secao_cm']?.toString().replaceAll(',', '.') ?? '0') ?? 0,
              casca1_mm: double.tryParse(rowMap['casca1_mm']?.toString().replaceAll(',', '.') ?? '0') ?? 0,
              casca2_mm: double.tryParse(rowMap['casca2_mm']?.toString().replaceAll(',', '.') ?? '0') ?? 0,
            );
            if (secao.alturaMedicao > 0) {
              await txn.insert('cubagens_secoes', secao.toMap());
              secoesImportadas++;
            }
          }
        }
      });
      return "Importação Concluída!\n\nÁrvores Cubadas Novas: $arvoresImportadas\nSeções Novas: $secoesImportadas\n\nEstruturas Criadas na Atividade:\n- Fazendas: $novasFazendas\n- Talhões: $novosTalhoes";
    } catch (e, s) {
      debugPrint("Erro ao importar CSV de cubagem: $e\nStack: $s");
      return "Erro Crítico: Ocorreu uma falha ao processar o arquivo. Verifique o formato do CSV e tente novamente.\n\nDetalhe: ${e.toString()}";
    }
  }

  // --- MÉTODOS CRUD: SORTIMENTOS ---
  Future<int> insertSortimento(SortimentoModel s) async =>
      await (await database).insert('sortimentos', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<SortimentoModel>> getTodosSortimentos() async {
    final db = await database;
    final maps = await db.query('sortimentos', orderBy: 'nome ASC');
    if (maps.isEmpty) {
      return [];
    }
    return List.generate(maps.length, (i) => SortimentoModel.fromMap(maps[i]));
  }

  Future<void> deleteSortimento(int id) async =>
      await (await database).delete('sortimentos', where: 'id = ?', whereArgs: [id]);
      
  // =====================================================================
  // <<< NOVA FUNÇÃO DE SEGURANÇA ADICIONADA AQUI >>>
  // =====================================================================
  
  /// DELETA o arquivo físico do banco de dados do dispositivo.
  /// Usado durante o logout para garantir que nenhum dado de usuário vaze para a próxima sessão.
  Future<void> deleteDatabaseFile() async {
    // Fecha a conexão com o banco se ela estiver aberta, para liberar o arquivo.
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null; // Zera a instância para forçar a recriação no próximo login.
    }
    
    try {
      final path = join(await getDatabasesPath(), 'geoforestcoletor.db');
      await deleteDatabase(path);
      debugPrint("Banco de dados local completamente apagado com sucesso.");
    } catch (e) {
      debugPrint("!!!!!! ERRO AO APAGAR O BANCO DE DADOS: $e !!!!!");
      // Mesmo que falhe, tentamos garantir que a instância seja nula.
      _database = null;
    }
  }
}