// lib/providers/map_provider.dart (VERSÃO COMPLETA E CORRIGIDA)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/fazenda_model.dart';
import 'package:geoforestcoletor/models/imported_feature_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/sample_point.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/services/activity_optimizer_service.dart';
import 'package:geoforestcoletor/services/export_service.dart';
import 'package:geoforestcoletor/services/geojson_service.dart';
import 'package:geoforestcoletor/services/sampling_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum MapLayerType { ruas, satelite, sateliteMapbox }

class MapProvider with ChangeNotifier {
  final _geoJsonService = GeoJsonService();
  final _dbHelper = DatabaseHelper.instance;
  final _samplingService = SamplingService();
  late final ActivityOptimizerService _optimizerService;
  final _exportService = ExportService();
  
  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  List<ImportedPolygonFeature> _importedPolygons = [];
  List<SamplePoint> _samplePoints = [];
  bool _isLoading = false;
  Atividade? _currentAtividade;
  MapLayerType _currentLayer = MapLayerType.satelite;
  Position? _currentUserPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isFollowingUser = false;
  bool _isDrawing = false;
  final List<LatLng> _drawnPoints = [];

  MapProvider() {
    _optimizerService = ActivityOptimizerService(dbHelper: _dbHelper);
  }

  // Getters
  bool get isDrawing => _isDrawing;
  List<LatLng> get drawnPoints => _drawnPoints;
  List<Polygon> get polygons => _importedPolygons.map((f) => f.polygon).toList();
  List<SamplePoint> get samplePoints => _samplePoints;
  bool get isLoading => _isLoading;
  Atividade? get currentAtividade => _currentAtividade;
  MapLayerType get currentLayer => _currentLayer;
  Position? get currentUserPosition => _currentUserPosition;
  bool get isFollowingUser => _isFollowingUser;

  final Map<MapLayerType, String> _tileUrls = {
    MapLayerType.ruas: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapLayerType.satelite: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    MapLayerType.sateliteMapbox: 'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
  };
  final String _mapboxAccessToken = 'pk.eyJ1IjoiZ2VvZm9yZXN0YXBwIiwiYSI6ImNtY2FyczBwdDAxZmYybHB1OWZlbG1pdW0ifQ.5HeYC0moMJ8dzZzVXKTPrg';

  String get currentTileUrl {
    String url = _tileUrls[_currentLayer]!;
    if (url.contains('{accessToken}')) {
      if (_mapboxAccessToken.isEmpty) return _tileUrls[MapLayerType.satelite]!;
      return url.replaceAll('{accessToken}', _mapboxAccessToken);
    }
    return url;
  }
  
  void switchMapLayer() {
    _currentLayer = MapLayerType.values[(_currentLayer.index + 1) % MapLayerType.values.length];
    notifyListeners();
  }

  void startDrawing() {
    if (!_isDrawing) {
      _isDrawing = true;
      _drawnPoints.clear();
      notifyListeners();
    }
  }

  void cancelDrawing() {
    if (_isDrawing) {
      _isDrawing = false;
      _drawnPoints.clear();
      notifyListeners();
    }
  }

  void addDrawnPoint(LatLng point) {
    if (_isDrawing) {
      _drawnPoints.add(point);
      notifyListeners();
    }
  }

  void undoLastDrawnPoint() {
    if (_isDrawing && _drawnPoints.isNotEmpty) {
      _drawnPoints.removeLast();
      notifyListeners();
    }
  }
  
  void saveDrawnPolygon() {
    if (_drawnPoints.length < 3) {
      cancelDrawing();
      return;
    }
    _importedPolygons.add(ImportedPolygonFeature(
      polygon: Polygon(points: List.from(_drawnPoints), color: const Color(0xFF617359).withAlpha(128), borderColor: const Color(0xFF1D4433), borderStrokeWidth: 2, isFilled: true),
      properties: {},
    ));
    _isDrawing = false;
    _drawnPoints.clear();
    notifyListeners();
  }

  void clearAllMapData() {
    _importedPolygons = [];
    _samplePoints = [];
    _currentAtividade = null;
    if (_isFollowingUser) toggleFollowingUser();
    if (_isDrawing) cancelDrawing();
    notifyListeners();
  }

  void setCurrentAtividade(Atividade atividade) {
    _currentAtividade = atividade;
  }
  
  Future<String> processarImportacaoDeArquivo({required bool isPlanoDeAmostragem}) async {
    if (_currentAtividade == null) {
      return "Erro: Nenhuma atividade selecionada para o planejamento.";
    }
    _setLoading(true);

    try {
      if (isPlanoDeAmostragem) {
        final pontosImportados = await _geoJsonService.importPoints();
        if (pontosImportados.isNotEmpty) {
          return await _processarPlanoDeAmostragemImportado(pontosImportados);
        }
      } else {
        final poligonosImportados = await _geoJsonService.importPolygons();
        if (poligonosImportados.isNotEmpty) {
          return await _processarCargaDeTalhoesImportada(poligonosImportados);
        }
      }
      
      return "Nenhum dado válido foi encontrado no arquivo selecionado.";
    
    } on GeoJsonParseException catch (e) {
      return e.toString();
    } catch (e) {
      return 'Ocorreu um erro inesperado: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }
  
  Future<String> _processarCargaDeTalhoesImportada(List<ImportedPolygonFeature> features) async {
    _importedPolygons = []; 
    _samplePoints = []; 
    notifyListeners();

    int fazendasCriadas = 0;
    int talhoesCriados = 0;
    
    await _dbHelper.database.then((db) async => await db.transaction((txn) async {
      for (final feature in features) {
        final props = feature.properties;
        final fazendaId = (props['fazenda_id'] ?? props['fazenda_nome'] ?? props['fazenda'])?.toString();
        final nomeTalhao = (props['talhao_nome'] ?? props['talhao_id'] ?? props['talhao'])?.toString();
        
        if (fazendaId == null || nomeTalhao == null) continue;

        Fazenda? fazenda = (await txn.query('fazendas', where: 'id = ? AND atividadeId = ?', whereArgs: [fazendaId, _currentAtividade!.id!])).map((e) => Fazenda.fromMap(e)).firstOrNull;
        if (fazenda == null) {
          fazenda = Fazenda(id: fazendaId, atividadeId: _currentAtividade!.id!, nome: props['fazenda_nome']?.toString() ?? fazendaId, municipio: 'N/I', estado: 'N/I');
          await txn.insert('fazendas', fazenda.toMap());
          fazendasCriadas++;
        }
        
        Talhao? talhao = (await txn.query('talhoes', where: 'nome = ? AND fazendaId = ? AND fazendaAtividadeId = ?', whereArgs: [nomeTalhao, fazenda.id, fazenda.atividadeId])).map((e) => Talhao.fromMap(e)).firstOrNull;
        if (talhao == null) {
          talhao = Talhao(
            fazendaId: fazenda.id, fazendaAtividadeId: fazenda.atividadeId, nome: nomeTalhao,
            especie: props['especie']?.toString(), areaHa: (props['area_ha'] as num?)?.toDouble(),
          );
          final talhaoId = await txn.insert('talhoes', talhao.toMap());
          talhao = talhao.copyWith(id: talhaoId);
          talhoesCriados++;
        }
        
        feature.properties['db_talhao_id'] = talhao.id;
        feature.properties['db_fazenda_nome'] = fazenda.nome;
      }
    }));
    
    _importedPolygons = features;
    notifyListeners();
    return "Carga concluída: ${features.length} polígonos, $fazendasCriadas novas fazendas e $talhoesCriados novos talhões criados.";
  }

  Future<String> _processarPlanoDeAmostragemImportado(List<ImportedPointFeature> pontosImportados) async {
    _importedPolygons = []; 
    _samplePoints = []; 
    notifyListeners();

    final db = await _dbHelper.database;
    final List<Parcela> parcelasParaSalvar = [];
    int novasFazendas = 0;
    int novosTalhoes = 0;
    
    await db.transaction((txn) async {
      for (final ponto in pontosImportados) {
        final props = ponto.properties;
        final fazendaId = (props['fazenda_id'] ?? props['fazenda'])?.toString();
        final nomeTalhao = (props['talhao'] ?? props['talhao_nome'])?.toString();
        
        if (fazendaId == null || nomeTalhao == null) continue;

        Fazenda? fazenda = (await txn.query('fazendas', where: 'id = ? AND atividadeId = ?', whereArgs: [fazendaId, _currentAtividade!.id!])).map((e) => Fazenda.fromMap(e)).firstOrNull;
        if (fazenda == null) {
          fazenda = Fazenda(id: fazendaId, atividadeId: _currentAtividade!.id!, nome: props['fazenda']?.toString() ?? fazendaId, municipio: 'N/I', estado: 'N/I');
          await txn.insert('fazendas', fazenda.toMap());
          novasFazendas++;
        }

        Talhao? talhao = (await txn.query('talhoes', where: 'nome = ? AND fazendaId = ? AND fazendaAtividadeId = ?', whereArgs: [nomeTalhao, fazenda.id, fazenda.atividadeId])).map((e) => Talhao.fromMap(e)).firstOrNull;
        if (talhao == null) {
          talhao = Talhao(
            fazendaId: fazenda.id, fazendaAtividadeId: fazenda.atividadeId, nome: nomeTalhao,
            especie: props['especie']?.toString(), areaHa: (props['area_ha'] as num?)?.toDouble(),
            espacamento: props['espacam']?.toString(),
          );
          final talhaoId = await txn.insert('talhoes', talhao.toMap());
          talhao = talhao.copyWith(id: talhaoId);
          novosTalhoes++;
        }
        
        parcelasParaSalvar.add(Parcela(
          talhaoId: talhao.id,
          idParcela: props['parcela_id_plano']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          areaMetrosQuadrados: (props['area_m2'] as num?)?.toDouble() ?? 0.0,
          latitude: ponto.position.latitude, longitude: ponto.position.longitude,
          status: StatusParcela.pendente,
          dataColeta: DateTime.now(),
          nomeFazenda: fazenda.nome, idFazenda: fazenda.id, nomeTalhao: talhao.nome,
        ));
      }
    });
    
    if (parcelasParaSalvar.isNotEmpty) {
      await _dbHelper.saveBatchParcelas(parcelasParaSalvar);
      await loadSamplesParaAtividade();
    }

    return "Plano importado: ${parcelasParaSalvar.length} amostras salvas. Novas Fazendas: $novasFazendas, Novos Talhões: $novosTalhoes.";
  }

  Future<String> gerarAmostrasParaAtividade({required double hectaresPerSample}) async {
    if (_importedPolygons.isEmpty) return "Nenhum polígono de talhão carregado.";
    if (_currentAtividade == null) return "Erro: Atividade atual não definida.";

    _setLoading(true);

    final pontosGerados = _samplingService.generateMultiTalhaoSamplePoints(
      importedFeatures: _importedPolygons,
      hectaresPerSample: hectaresPerSample,
    );

    if (pontosGerados.isEmpty) {
      _setLoading(false);
      return "Nenhum ponto de amostra pôde ser gerado.";
    }

    final List<Parcela> parcelasParaSalvar = [];
    int pointIdCounter = 1;

    for (final ponto in pontosGerados) {
      final props = ponto.properties;
      final talhaoIdSalvo = props['db_talhao_id'] as int?;
      if (talhaoIdSalvo != null) {
         parcelasParaSalvar.add(Parcela(
          talhaoId: talhaoIdSalvo,
          idParcela: pointIdCounter.toString(), areaMetrosQuadrados: 0,
          latitude: ponto.position.latitude, longitude: ponto.position.longitude,
          status: StatusParcela.pendente, dataColeta: DateTime.now(),
          nomeFazenda: props['db_fazenda_nome']?.toString(),
          idFazenda: props['fazenda_id']?.toString(),
          nomeTalhao: props['talhao_nome']?.toString(),
        ));
        pointIdCounter++;
      }
    }

    if (parcelasParaSalvar.isNotEmpty) {
      await _dbHelper.saveBatchParcelas(parcelasParaSalvar);
      await loadSamplesParaAtividade();
    }
    
    final int talhoesRemovidos = await _optimizerService.otimizarAtividade(_currentAtividade!.id!);
    
    _setLoading(false);
    
    String mensagemFinal = "${parcelasParaSalvar.length} amostras foram geradas e salvas.";
    if (talhoesRemovidos > 0) {
      mensagemFinal += " $talhoesRemovidos talhões vazios foram otimizados.";
    }
    return mensagemFinal;
  }
  
  Future<void> loadSamplesParaAtividade() async {
    if (_currentAtividade == null) return;
    
    _setLoading(true);
    _samplePoints.clear();
    final fazendas = await _dbHelper.getFazendasDaAtividade(_currentAtividade!.id!);
    for (final fazenda in fazendas) {
      final talhoes = await _dbHelper.getTalhoesDaFazenda(fazenda.id, _currentAtividade!.id!);
      for (final talhao in talhoes) {
        final parcelas = await _dbHelper.getParcelasDoTalhao(talhao.id!);
        for (final p in parcelas) {
           _samplePoints.add(SamplePoint(
              id: int.tryParse(p.idParcela) ?? 0,
              position: LatLng(p.latitude ?? 0, p.longitude ?? 0),
              status: _getSampleStatus(p),
              data: {'dbId': p.dbId}
          ));
        }
      }
    }
    _setLoading(false);
  }

  void toggleFollowingUser() {
    if (_isFollowingUser) {
      _positionStreamSubscription?.cancel();
      _isFollowingUser = false;
    } else {
      const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1);
      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
        _currentUserPosition = position;
        notifyListeners();
      });
      _isFollowingUser = true;
    }
    notifyListeners();
  }

  void updateUserPosition(Position position) {
    _currentUserPosition = position;
    notifyListeners();
  }
  
  @override
  void dispose() { 
    _positionStreamSubscription?.cancel(); 
    super.dispose(); 
  }
  
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ===== ARQUIVO CORRIGIDO AQUI =====
  SampleStatus _getSampleStatus(Parcela parcela) {
    // A propriedade 'exportada' tem prioridade máxima.
    if (parcela.exportada) {
      return SampleStatus.exported;
    }
    // Se não foi exportada, verificamos os outros status.
    switch (parcela.status) {
      case StatusParcela.concluida:
        return SampleStatus.completed;
      case StatusParcela.emAndamento:
        return SampleStatus.open;
      case StatusParcela.pendente:
        return SampleStatus.untouched;
      // Adicionamos o caso 'exportada' aqui para o switch ser "exaustivo" e
      // evitar o erro de análise. A lógica principal já foi tratada pelo 'if' acima.
      case StatusParcela.exportada:
        return SampleStatus.exported;
    }
  }

  Future<void> exportarPlanoDeAmostragem(BuildContext context) async {
    final List<int> parcelaIds = samplePoints.map((p) => p.data['dbId'] as int).toList();

    if (parcelaIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhum plano de amostragem para exportar.'),
          backgroundColor: Colors.orange,
        ));
        return;
    }

    await _exportService.exportarPlanoDeAmostragem(
      context: context,
      parcelaIds: parcelaIds,
    );
  }
}