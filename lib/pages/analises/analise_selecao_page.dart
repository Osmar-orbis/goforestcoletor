// lib/pages/analises/analise_selecao_page.dart (VERSÃO SEM CHAMADAS MORTAS)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/pages/dashboard/relatorio_comparativo_page.dart';
import 'package:geoforestcoletor/pages/analises/analise_volumetrica_page.dart';
// O import da 'definicao_sortimento_page.dart' foi removido daqui.

class AnaliseSelecaoPage extends StatefulWidget {
  const AnaliseSelecaoPage({super.key});

  @override
  State<AnaliseSelecaoPage> createState() => _AnaliseSelecaoPageState();
}

class _AnaliseSelecaoPageState extends State<AnaliseSelecaoPage> {
  final dbHelper = DatabaseHelper.instance;

  Atividade? _atividadeSelecionada;
  List<Atividade> _atividadesDisponiveis = [];
  
  List<Talhao> _talhoesDaAtividade = [];
  
  final Set<String> _fazendasSelecionadas = {};
  final Set<int> _talhoesSelecionados = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _carregarAtividades();
  }

   Future<void> _carregarAtividades() async {
    final talhoesCompletos = await dbHelper.getTalhoesComParcelasConcluidas();
    if (talhoesCompletos.isEmpty) {
      if(mounted) setState(() => _atividadesDisponiveis = []);
      return;
    }
    final atividadeIds = talhoesCompletos.map((t) => t.fazendaAtividadeId).toSet();
    final todasAtividades = await dbHelper.getTodasAsAtividades();
    if(mounted) {
      setState(() {
        _atividadesDisponiveis = todasAtividades.where((a) => atividadeIds.contains(a.id)).toList();
      });
    }
  }

  Future<void> _onAtividadeChanged(Atividade? novaAtividade) async {
    if (novaAtividade == null) return;
    
    setState(() {
      _isLoading = true;
      _atividadeSelecionada = novaAtividade;
      _talhoesDaAtividade.clear();
      _fazendasSelecionadas.clear();
      _talhoesSelecionados.clear();
    });
    
    final todosTalhoesCompletos = await dbHelper.getTalhoesComParcelasConcluidas();
    final talhoesFiltrados = todosTalhoesCompletos.where((t) => t.fazendaAtividadeId == novaAtividade.id).toList();

    if(mounted) {
      setState(() {
        _talhoesDaAtividade = talhoesFiltrados;
        _isLoading = false;
      });
    }
  }

  void _toggleFazenda(String fazendaId, bool? isSelected) {
    if (isSelected == null) return; 
    setState(() {
      if (isSelected) {
        _fazendasSelecionadas.add(fazendaId);
        for (var talhao in _talhoesDaAtividade) {
          if (talhao.fazendaId == fazendaId) {
            _talhoesSelecionados.add(talhao.id!);
          }
        }
      } else {
        _fazendasSelecionadas.remove(fazendaId);
        _talhoesSelecionados.removeWhere((talhaoId) {
          final talhao = _talhoesDaAtividade.firstWhere((t) => t.id == talhaoId, orElse: () => Talhao(fazendaId: '', fazendaAtividadeId: 0, nome: ''));
          return talhao.fazendaId == fazendaId;
        });
      }
    });
  }
  
  void _toggleTalhao(int talhaoId, bool? isSelected) {
    if (isSelected == null) return;
    setState(() {
      if (isSelected) {
        _talhoesSelecionados.add(talhaoId);
      } else {
        _talhoesSelecionados.remove(talhaoId);
      }
    });
  }
  
  void _gerarRelatorio() {
    if (_talhoesSelecionados.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione pelo menos um talhão para gerar a análise.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final talhoesParaAnalisar = _talhoesDaAtividade.where((t) => _talhoesSelecionados.contains(t.id)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RelatorioComparativoPage(
          talhoesSelecionados: talhoesParaAnalisar
        ),
      ),
    );
  }
  
  void _navegarParaAnaliseVolumetrica() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnaliseVolumetricaPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Talhao>> talhoesPorFazenda = {};
    for (var talhao in _talhoesDaAtividade) {
      final fazendaNome = talhao.fazendaNome ?? 'Fazenda Desconhecida';
      if (!talhoesPorFazenda.containsKey(fazendaNome)) {
        talhoesPorFazenda[fazendaNome] = [];
      }
      talhoesPorFazenda[fazendaNome]!.add(talhao);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('GeoForest Analista')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<Atividade>(
              value: _atividadeSelecionada,
              hint: const Text('1. Selecione uma Atividade de Inventário'),
              isExpanded: true,
              items: _atividadesDisponiveis.map((atividade) {
                return DropdownMenuItem(
                  value: atividade,
                  child: Text(atividade.tipo),
                );
              }).toList(),
              onChanged: _onAtividadeChanged,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('2. Selecione Fazendas e Talhões para Análise Comparativa', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _atividadeSelecionada == null
                  ? const Center(child: Text('Aguardando seleção de atividade.'))
                  : talhoesPorFazenda.isEmpty
                    ? const Center(child: Text('Nenhum talhão com parcelas concluídas para esta atividade.'))
                    : ListView(
                      children: talhoesPorFazenda.entries.map((entry) {
                        final fazendaNome = entry.key;
                        final talhoes = entry.value;
                        final fazendaId = talhoes.first.fazendaId;
                        
                        return ExpansionTile(
                          title: Row(
                            children: [
                              Checkbox(
                                value: _fazendasSelecionadas.contains(fazendaId),
                                onChanged: (value) => _toggleFazenda(fazendaId, value),
                              ),
                              Expanded(child: Text(fazendaNome, style: const TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                          initiallyExpanded: true,
                          children: talhoes.map((talhao) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 32.0),
                              child: CheckboxListTile(
                                title: Text(talhao.nome),
                                value: _talhoesSelecionados.contains(talhao.id!),
                                onChanged: (value) => _toggleTalhao(talhao.id!, value),
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      // <<< FLOATING ACTION BUTTON CORRIGIDO (REMOVIDO O BOTÃO DE SORTIMENTO) >>>
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _navegarParaAnaliseVolumetrica,
            heroTag: 'analiseVolumetricaFab',
            label: const Text('Equação de Volume'),
            icon: const Icon(Icons.calculate_outlined),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            onPressed: _gerarRelatorio,
            heroTag: 'analiseComparativaFab',
            label: const Text('Análise Comparativa'),
            icon: const Icon(Icons.analytics_outlined),
          ),
        ],
      ),
    );
  }
}