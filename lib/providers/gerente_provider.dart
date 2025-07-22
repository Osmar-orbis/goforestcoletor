// lib/providers/gerente_provider.dart (VERSÃO COM LÓGICA DE ATUALIZAÇÃO CORRIGIDA)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/services/gerente_service.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

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

  // Getters Inteligentes (sem alterações)
  List<Parcela> get parcelasFiltradas {
    if (_selectedProjetoId == null) {
      return _parcelasSincronizadas;
    }
    return _parcelasSincronizadas
        .where((p) => p.toMap()['projetoId'] == _selectedProjetoId)
        .toList();
  }

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

  Map<StatusParcela, int> get progressoPorStatus {
    final parcelas = parcelasFiltradas;
    if (parcelas.isEmpty) return {};
    final grupoPorStatus = groupBy(parcelas, (Parcela p) => p.status);
    return grupoPorStatus.map((status, listaParcelas) {
      return MapEntry(status, listaParcelas.length);
    });
  }

  Map<String, int> get coletasPorMes {
    final parcelas = parcelasFiltradas
        .where((p) => p.status == StatusParcela.concluida && p.dataColeta != null)
        .toList();
    if (parcelas.isEmpty) return {};

    final grupoPorMes = groupBy(parcelas, (Parcela p) {
      final data = p.dataColeta!;
      return DateFormat('MMM/yy', 'pt_BR').format(data);
    });

    final mapaContagem = grupoPorMes.map((mes, lista) => MapEntry(mes, lista.length));

    final chavesOrdenadas = mapaContagem.keys.toList()
      ..sort((a, b) {
        try {
          final dataA = DateFormat('MMM/yy', 'pt_BR').parse(a);
          final dataB = DateFormat('MMM/yy', 'pt_BR').parse(b);
          return dataA.compareTo(dataB);
        } catch (e) {
          return 0;
        }
      });

    return {for (var key in chavesOrdenadas) key: mapaContagem[key]!};
  }

  // Métodos Públicos
  GerenteProvider() {
    initializeDateFormatting('pt_BR', null).then((_) {
      iniciarMonitoramento();
    });
  }

  void selectProjeto(int? projetoId) {
    _selectedProjetoId = projetoId;
    notifyListeners();
  }

  /// Carrega os dados em dois estágios para uma melhor experiência de usuário.
  Future<void> iniciarMonitoramento() async {
    _dadosColetaSubscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners(); // Notifica a UI que o carregamento começou

    try {
      // ETAPA 1: Busca a lista de projetos.
      _projetos = await _gerenteService.getTodosOsProjetosStream();
      _projetos.sort((a, b) => a.nome.compareTo(b.nome));

      // <<< CORREÇÃO CRÍTICA: Notifica a UI IMEDIATAMENTE após carregar os projetos >>>
      // Isso fará o filtro de projetos aparecer na tela.
      notifyListeners();

      // ETAPA 2: Inicia o monitoramento em tempo real dos dados de coleta.
      _dadosColetaSubscription = _gerenteService.getDadosColetaStream().listen(
        (listaDeParcelas) {
          _parcelasSincronizadas = listaDeParcelas;
          _isLoading = false; // O carregamento só termina quando os dados das parcelas chegam
          _error = null;
          notifyListeners(); // Notifica a UI para atualizar os gráficos
        },
        onError: (e) {
          _error = "Erro ao buscar dados de coleta: $e";
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = "Erro ao buscar lista de projetos: $e";
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _dadosColetaSubscription?.cancel();
    super.dispose();
  }
}