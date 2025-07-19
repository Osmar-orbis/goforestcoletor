// lib/providers/gerente_provider.dart (VERSÃO COM IMPORTS CORRIGIDOS)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/services/gerente_service.dart';

class GerenteProvider with ChangeNotifier {
  final GerenteService _gerenteService = GerenteService();
  StreamSubscription? _dadosColetaSubscription;

  bool _isLoading = true;
  String? _error;
  List<Parcela> _parcelasSincronizadas = [];
  List<Projeto> _projetos = [];
  int? _selectedProjetoId;

  // Getters Públicos
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Projeto> get projetosDisponiveis => _projetos;
  int? get selectedProjetoId => _selectedProjetoId;

  // GETTERS INTELIGENTES PARA O DASHBOARD

  /// Retorna a lista de parcelas, já filtrada pelo projeto selecionado.
  List<Parcela> get parcelasFiltradas {
    if (_selectedProjetoId == null) {
      return _parcelasSincronizadas;
    }
    return _parcelasSincronizadas.where((p) => (p.toMap()['projetoId'] ?? -1) == _selectedProjetoId).toList();
  }

  /// Agrupa o progresso das parcelas filtradas pelo nome da fazenda.
  Map<String, Map<String, int>> get progressoPorFazenda {
    final parcelas = parcelasFiltradas;
    if (parcelas.isEmpty) return {};
    final grupoPorFazenda = groupBy(parcelas, (Parcela p) => p.nomeFazenda ?? 'Fazenda Desconhecida');
    return grupoPorFazenda.map((nomeFazenda, listaParcelas) {
      final total = listaParcelas.length;
      final concluidas = listaParcelas.where((p) => p.status == StatusParcela.concluida).length;
      return MapEntry(nomeFazenda, {'total': total, 'concluidas': concluidas});
    });
  }

  /// Agrupa as parcelas filtradas por status para o gráfico de pizza.
  Map<StatusParcela, int> get progressoPorStatus {
    final parcelas = parcelasFiltradas;
    if (parcelas.isEmpty) return {};
    final grupoPorStatus = groupBy(parcelas, (Parcela p) => p.status);
    return grupoPorStatus.map((status, listaParcelas) {
      return MapEntry(status, listaParcelas.length);
    });
  }

  /// Agrupa as parcelas CONCLUÍDAS por data para o gráfico de linha.
  Map<DateTime, int> get coletasPorDia {
    final parcelas = parcelasFiltradas.where((p) => p.status == StatusParcela.concluida && p.dataColeta != null).toList();
    if (parcelas.isEmpty) return {};
    
    final grupoPorDia = groupBy(parcelas, (Parcela p) {
      final data = p.dataColeta!;
      return DateTime(data.year, data.month, data.day);
    });

    final mapaOrdenado = Map.fromEntries(
      grupoPorDia.entries.map((e) => MapEntry(e.key, e.value.length)).toList()
        ..sort((a, b) => a.key.compareTo(b.key))
    );
    return mapaOrdenado;
  }

  // MÉTODOS PÚBLICOS
  GerenteProvider() {
    iniciarMonitoramento();
  }

  void selectProjeto(int? projetoId) {
    _selectedProjetoId = projetoId;
    notifyListeners();
  }

  void iniciarMonitoramento() {
    _dadosColetaSubscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _dadosColetaSubscription = _gerenteService.getDadosColetaStream().listen(
      (listaDeParcelas) {
        _parcelasSincronizadas = listaDeParcelas;
        
        final projetosUnicos = <int, Projeto>{};
        for (var p in listaDeParcelas) {
          final pMap = p.toMap();
          final id = pMap['projetoId'];
          final nome = pMap['projetoNome'];
          if (id != null && nome != null) {
            projetosUnicos[id] = Projeto(id: id, nome: nome, empresa: '', responsavel: '', dataCriacao: DateTime.now());
          }
        }
        _projetos = projetosUnicos.values.toList();
        _projetos.sort((a, b) => a.nome.compareTo(b.nome));

        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = "Erro ao buscar dados: $e";
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _dadosColetaSubscription?.cancel();
    super.dispose();
  }
}