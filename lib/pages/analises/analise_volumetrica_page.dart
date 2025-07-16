// lib/pages/analises/analise_volumetrica_page.dart (VERSÃO FINAL COM EXPORTAÇÃO)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/services/analysis_service.dart';
import 'package:geoforestcoletor/services/pdf_service.dart'; // <<< IMPORTADO

class AnaliseVolumetricaPage extends StatefulWidget {
  const AnaliseVolumetricaPage({super.key});

  @override
  State<AnaliseVolumetricaPage> createState() => _AnaliseVolumetricaPageState();
}

class _AnaliseVolumetricaPageState extends State<AnaliseVolumetricaPage> {
  final dbHelper = DatabaseHelper.instance;
  final analysisService = AnalysisService();
  final pdfService = PdfService(); // <<< INSTANCIADO

  // Estados para seleção
  List<Talhao> _talhoesCubadosDisponiveis = [];
  List<Talhao> _talhoesInventarioDisponiveis = [];
  final Set<int> _talhoesCubadosSelecionados = {};
  final Set<int> _talhoesInventarioSelecionados = {};

  // Estados para resultados
  Map<String, dynamic>? _resultadoRegressao;
  Map<String, dynamic>? _tabelaProducaoInventario;
  Map<String, dynamic>? _tabelaProducaoSortimento;
  
  bool _isLoading = true;
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final todasCubagens = await dbHelper.getTodasCubagens();
      final cubadasCompletas = todasCubagens.where((a) => a.alturaTotal > 0 && a.valorCAP > 0).toList();
      final idsTalhoesCubados = cubadasCompletas.map((a) => a.talhaoId).where((id) => id != null).toSet();

      final todosTalhoes = await dbHelper.getTodosProjetos().then((projetos) async {
        final List<Talhao> lista = [];
        for (var proj in projetos) {
          final atividades = await dbHelper.getAtividadesDoProjeto(proj.id!);
          for (var atv in atividades) {
            final fazendas = await dbHelper.getFazendasDaAtividade(atv.id!);
            for (var faz in fazendas) {
              lista.addAll(await dbHelper.getTalhoesDaFazenda(faz.id, faz.atividadeId));
            }
          }
        }
        return lista;
      });

      _talhoesCubadosDisponiveis = todosTalhoes.where((t) => idsTalhoesCubados.contains(t.id)).toList();
      _talhoesInventarioDisponiveis = await dbHelper.getTalhoesComParcelasConcluidas();

    } catch (e) {
      _errorMessage = "Erro ao carregar dados: $e";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _gerarAnaliseCompleta() async {
    if (_talhoesCubadosSelecionados.isEmpty || _talhoesInventarioSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione ao menos um talhão de CUBAGEM e um de INVENTÁRIO.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final cubagensParaRegressao = <CubagemArvore>[];
      for (var talhaoId in _talhoesCubadosSelecionados) {
        cubagensParaRegressao.addAll(await dbHelper.getTodasCubagensDoTalhao(talhaoId));
      }
      
      final resultadoRegressao = await analysisService.gerarEquacaoSchumacherHall(cubagensParaRegressao);
      setState(() => _resultadoRegressao = resultadoRegressao);
      if (resultadoRegressao['error'] != null) {
        setState(() => _isAnalyzing = false);
        return;
      }
      
      List<Parcela> parcelasInventario = [];
      List<Arvore> arvoresInventario = [];
      List<Talhao> talhoesInventario = [];
      for (var talhaoId in _talhoesInventarioSelecionados) {
        final dados = await dbHelper.getDadosAgregadosDoTalhao(talhaoId);
        parcelasInventario.addAll(dados['parcelas']);
        arvoresInventario.addAll(dados['arvores']);
        
        final talhaoInfo = _talhoesInventarioDisponiveis.firstWhere((t) => t.id == talhaoId);
        talhoesInventario.add(talhaoInfo);
      }

      if (parcelasInventario.isNotEmpty && arvoresInventario.isNotEmpty) {
        final arvoresComVolume = analysisService.aplicarEquacaoDeVolume(
          arvoresDoInventario: arvoresInventario,
          b0: resultadoRegressao['b0'], b1: resultadoRegressao['b1'], b2: resultadoRegressao['b2'],
        );
        final analise = analysisService.getTalhaoInsights(parcelasInventario, arvoresComVolume);

        double volumeTotalDoLote = 0;
        double areaTotalDoLote = 0;
        for (var talhao in talhoesInventario) {
            if(talhao.areaHa != null && talhao.areaHa! > 0) {
              volumeTotalDoLote += analise.volumePorHectare * talhao.areaHa!;
              areaTotalDoLote += talhao.areaHa!;
            }
        }
        
        setState(() {
          _tabelaProducaoInventario = {
            'talhoes': talhoesInventario.map((t) => t.nome).join(', '),
            'volume_ha': analise.volumePorHectare,
            'arvores_ha': analise.arvoresPorHectare,
            'area_basal_ha': analise.areaBasalPorHectare,
            'volume_total_lote': volumeTotalDoLote,
            'area_total_lote': areaTotalDoLote,
          };
        });
      }

      Map<String, double> volumesSortimento = {};
      double volumeTotalClassificado = 0;
      for (final arvoreCubada in cubagensParaRegressao) {
        final secoes = await dbHelper.getSecoesPorArvoreId(arvoreCubada.id!);
        final resClassificacao = analysisService.classificarSortimentos(secoes);
        resClassificacao.forEach((nome, vol) {
          volumesSortimento.update(nome, (v) => v + vol, ifAbsent: () => vol);
          volumeTotalClassificado += vol;
        });
      }
      
      Map<String, double> pctSortimento = {};
      if (volumeTotalClassificado > 0) {
        volumesSortimento.forEach((nome, vol) {
          pctSortimento[nome] = (vol / volumeTotalClassificado) * 100;
        });
      }
      setState(() => _tabelaProducaoSortimento = {'porcentagens': pctSortimento});

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro na análise: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isAnalyzing = false);
    }
  }

  // <<< NOVA FUNÇÃO DE EXPORTAÇÃO >>>
  Future<void> _exportarAnaliseVolumetricaPdf() async {
    if (_resultadoRegressao == null || _tabelaProducaoInventario == null || _tabelaProducaoSortimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gere a análise completa primeiro antes de exportar.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    await pdfService.gerarRelatorioVolumetricoPdf(
      context: context,
      resultadoRegressao: _resultadoRegressao!,
      producaoInventario: _tabelaProducaoInventario!,
      producaoSortimento: _tabelaProducaoSortimento!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise Volumétrica'),
        // <<< BOTÃO DE EXPORTAÇÃO ADICIONADO >>>
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: (_resultadoRegressao == null || _isAnalyzing) ? null : _exportarAnaliseVolumetricaPdf,
            tooltip: 'Exportar Relatório (PDF)',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAnalyzing ? null : _gerarAnaliseCompleta,
        icon: _isAnalyzing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.functions),
        label: Text(_isAnalyzing ? 'Analisando...' : 'Gerar Análise Completa'),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
      children: [
        _buildSelectionCard(
            '1. Selecione os Talhões CUBADOS',
            'Serão usados para gerar a equação de volume.',
            _talhoesCubadosDisponiveis,
            _talhoesCubadosSelecionados,
            (id, selected) => setState(() {
              _talhoesCubadosSelecionados.clear();
              if(selected) _talhoesCubadosSelecionados.add(id);
            }) 
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
            '2. Selecione os Talhões de INVENTÁRIO',
            'A equação será aplicada nestes talhões.',
            _talhoesInventarioDisponiveis,
            _talhoesInventarioSelecionados,
            (id, selected) => setState(() => selected ? _talhoesInventarioSelecionados.add(id) : _talhoesInventarioSelecionados.remove(id))) ,
        
        if (_resultadoRegressao != null) _buildResultCard(),
        if (_tabelaProducaoSortimento != null) _buildSortmentTable(),
        if (_tabelaProducaoInventario != null) _buildProductionTable(),
      ],
    );
  }
  
  Widget _buildSelectionCard(String title, String subtitle, List<Talhao> talhoes, Set<int> selectionSet, Function(int, bool) onSelect) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
            const Divider(),
            if (talhoes.isEmpty) const Text('Nenhum talhão disponível.'),
            ...talhoes.map((talhao) {
              return CheckboxListTile(
                title: Text(talhao.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(talhao.fazendaNome ?? 'Fazenda desc.'),
                value: selectionSet.contains(talhao.id!),
                onChanged: (val) => onSelect(talhao.id!, val ?? false),
              );
            }),
          ],
        ),
      ),
    );
  }
  
    Widget _buildResultCard() {
     if (_resultadoRegressao!['error'] != null) {
      return Card( margin: const EdgeInsets.only(top: 16), color: Colors.red.shade100, child: Padding( padding: const EdgeInsets.all(16.0), child: Text('Erro: ${_resultadoRegressao!['error']}', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),),);
    }
    final double r2 = _resultadoRegressao!['R2'] ?? 0.0;
    final String equacao = _resultadoRegressao!['equacao'] ?? 'N/A';
    final int nAmostras = _resultadoRegressao!['n_amostras'] ?? 0;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('3. Equação de Volume Gerada', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            Text('Equação:', style: TextStyle(color: Colors.grey.shade700)),
            Text(equacao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace')),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Coeficiente (R²):', style: TextStyle(color: Colors.grey.shade700)),Text(r2.toStringAsFixed(4), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),],),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Nº de Amostras Usadas:', style: TextStyle(color: Colors.grey.shade700)),Text(nAmostras.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),],),
          ],
        ),
      ),
    );
  }

  Widget _buildSortmentTable() {
    final Map<String, double> porcentagens = _tabelaProducaoSortimento?['porcentagens'] ?? {};
    if (porcentagens.isEmpty) {
      return Card( margin: const EdgeInsets.only(top: 16), color: Colors.amber.shade100, child: Padding( padding: const EdgeInsets.all(16.0), child: Text('Aviso: Nenhuma tora foi classificada nos sortimentos. Verifique os diâmetros das árvores cubadas.', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold)),),);
    }

    final double volumeTotalHa = _tabelaProducaoInventario?['volume_ha'] ?? 0.0;
    
    final sortedKeys = porcentagens.keys.toList()..sort((a,b) {
      final numA = double.tryParse(a.split('-').first.replaceAll('>', '')) ?? 99;
      final numB = double.tryParse(b.split('-').first.replaceAll('>', '')) ?? 99;
      return numB.compareTo(numA); 
    });
    
    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('4. Produção por Sortimento', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            ...sortedKeys.map((key) {
              final pct = porcentagens[key]!;
              final volumeHaSortimento = volumeTotalHa * (pct / 100);
              return _buildStatRow(
                '$key:',
                '${volumeHaSortimento.toStringAsFixed(2)} m³/ha (${pct.toStringAsFixed(1)}%)'
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionTable() {
    if (_tabelaProducaoInventario == null || (_tabelaProducaoInventario!['volume_ha'] as double) <= 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Card(
          color: Colors.amber.shade100,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Aviso: Não foi encontrado um inventário correspondente para os talhões selecionados ou os dados são insuficientes.', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    final double volumeTotalLote = _tabelaProducaoInventario!['volume_total_lote'];
    final double areaTotalLote = _tabelaProducaoInventario!['area_total_lote'];

    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('5. Totais do Inventário', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            Text('Aplicado aos talhões: ${_tabelaProducaoInventario!['talhoes']}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            const SizedBox(height: 16),
            _buildStatRow('Volume por Hectare:', '${(_tabelaProducaoInventario!['volume_ha'] as double).toStringAsFixed(2)} m³/ha'),
            _buildStatRow('Árvores por Hectare:', '${_tabelaProducaoInventario!['arvores_ha']}'),
            _buildStatRow('Área Basal por Hectare:', '${(_tabelaProducaoInventario!['area_basal_ha'] as double).toStringAsFixed(2)} m²/ha'),
            
            if(volumeTotalLote > 0) ...[
              const Divider(height: 20, thickness: 0.5),
              _buildStatRow('Volume Total para ${areaTotalLote.toStringAsFixed(2)} ha:', 
                            '${volumeTotalLote.toStringAsFixed(2)} m³', isTotal: true),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {bool isTotal = false}) {
    final valueStyle = TextStyle(
      fontSize: 16, 
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: isTotal ? Theme.of(context).colorScheme.primary : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}