// lib/pages/dashboard/talhao_dashboard_page.dart (ARQUIVO COMPLETO E CORRIGIDO)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/services/analysis_service.dart';
import 'package:geoforestcoletor/services/export_service.dart';
import 'package:geoforestcoletor/widgets/grafico_distribuicao_widget.dart';
import 'package:geoforestcoletor/pages/analises/simulacao_desbaste_page.dart';
import 'package:geoforestcoletor/pages/analises/rendimento_dap_page.dart';
import 'package:geoforestcoletor/models/analise_result_model.dart';

class TalhaoDashboardPage extends StatelessWidget {
  final Talhao talhao;
  final GlobalKey<_TalhaoDashboardContentState> _contentKey = GlobalKey();

  TalhaoDashboardPage({super.key, required this.talhao});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Análise: ${talhao.nome}'),
        actions: [
          Builder(builder: (context) {
            return IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Exportar Análise',
              onPressed: () {
                final currentState = _contentKey.currentState;
                
                if (currentState?._analysisResult != null) {
                  currentState!.mostrarDialogoExportacao(context);
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Aguarde a análise carregar para exportar.'),
                  ));
                }
              },
            );
          })
        ],
      ),
      body: TalhaoDashboardContent(key: _contentKey, talhao: talhao),
    );
  }
}

class TalhaoDashboardContent extends StatefulWidget {
  final Talhao talhao;
  const TalhaoDashboardContent({super.key, required this.talhao});

  @override
  State<TalhaoDashboardContent> createState() => _TalhaoDashboardContentState();
}

class _TalhaoDashboardContentState extends State<TalhaoDashboardContent> {
  final _dbHelper = DatabaseHelper.instance;
  final _analysisService = AnalysisService();
  final _exportService = ExportService();

  List<Parcela> _parcelasDoTalhao = [];
  List<Arvore> _arvoresDoTalhao = [];
  late Future<void> _dataLoadingFuture;
  TalhaoAnalysisResult? _analysisResult;

  @override
  void initState() {
    super.initState();
    _dataLoadingFuture = _carregarEAnalisarTalhao();
  }

  void mostrarDialogoExportacao(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.description_outlined, color: Colors.blue),
              title: const Text('Exportar Relatório (PDF)'),
              subtitle: const Text('Gera um relatório visual formatado.'),
              onTap: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Exportação para PDF a ser implementada.'),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_rows_outlined, color: Colors.green),
              title: const Text('Exportar Dados (CSV)'),
              subtitle: const Text('Gera uma planilha com os dados da análise.'),
              onTap: () {
                Navigator.of(ctx).pop();
                if (_analysisResult != null) {
                  _exportService.exportarAnaliseTalhaoCsv(
                    context: context,
                    talhao: widget.talhao,
                    analise: _analysisResult!,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _carregarEAnalisarTalhao() async {
    final dadosAgregados = await _dbHelper.getDadosAgregadosDoTalhao(widget.talhao.id!);
    _parcelasDoTalhao = dadosAgregados['parcelas'] as List<Parcela>;
    _arvoresDoTalhao = dadosAgregados['arvores'] as List<Arvore>;
    if (!mounted || _parcelasDoTalhao.isEmpty || _arvoresDoTalhao.isEmpty) return;
    final resultado = _analysisService.getTalhaoInsights(_parcelasDoTalhao, _arvoresDoTalhao);
    if (mounted) {
      setState(() => _analysisResult = resultado);
    }
  }
  
  void _navegarParaSimulacao() {
    if (_analysisResult == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimulacaoDesbastePage(
          parcelas: _parcelasDoTalhao,
          arvores: _arvoresDoTalhao,
          analiseInicial: _analysisResult!,
        ),
      ),
    );
  }

  void _analisarRendimento() {
    if (_analysisResult == null) return;
    final resultadoRendimento = _analysisService.analisarRendimentoPorDAP(_parcelasDoTalhao, _arvoresDoTalhao);
    if (resultadoRendimento.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há dados suficientes para a análise de rendimento.'), backgroundColor: Colors.orange),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RendimentoDapPage(
          nomeFazenda: widget.talhao.fazendaNome ?? 'Fazenda não informada',
          nomeTalhao: widget.talhao.nome,
          dadosRendimento: resultadoRendimento,
          analiseGeral: _analysisResult!,
        ),
      ),
    );
  }

  // <<< MÉTODO _gerarPlanoDeCubagemPdf REMOVIDO >>>
  // void _gerarPlanoDeCubagemPdf() async { ... }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _dataLoadingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro ao analisar talhão: ${snapshot.error}'));
        }
        if (_analysisResult == null || _analysisResult!.totalArvoresAmostradas == 0) {
          return const Center(child: Text('Não há dados de parcelas concluídas para a análise.'));
        }

        final result = _analysisResult!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildResumoCard(result),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Distribuição Diamétrica (CAP)', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 24),
                      GraficoDistribuicaoWidget(dadosDistribuicao: result.distribuicaoDiametrica),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildInsightsCard("⚠️ Alertas", result.warnings, Colors.red.shade100),
              const SizedBox(height: 12),
              _buildInsightsCard("💡 Insights", result.insights, Colors.blue.shade100),
              const SizedBox(height: 12),
              _buildInsightsCard("🛠️ Recomendações", result.recommendations, Colors.orange.shade100),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navegarParaSimulacao,
                icon: const Icon(Icons.content_cut_outlined),
                label: const Text('Simular Desbaste'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _analisarRendimento,
                icon: const Icon(Icons.bar_chart_outlined),
                label: const Text('Analisar Rendimento Comercial'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              // <<< BOTÃO VERMELHO E O SIZEDBOX ACIMA DELE FORAM REMOVIDOS >>>
            ],
          ),
        );
      },
    );
  }

  Widget _buildResumoCard(TalhaoAnalysisResult result) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo do Talhão', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            _buildStatRow('Árvores/ha:', result.arvoresPorHectare.toString()),
            _buildStatRow('CAP Médio:', '${result.mediaCap.toStringAsFixed(1)} cm'),
            _buildStatRow('Altura Média:', '${result.mediaAltura.toStringAsFixed(1)} m'),
            _buildStatRow('Área Basal (G):', '${result.areaBasalPorHectare.toStringAsFixed(2)} m²/ha'),
            _buildStatRow('Volume Estimado:', '${result.volumePorHectare.toStringAsFixed(2)} m³/ha'),
            const Divider(height: 20, thickness: 0.5, indent: 20, endIndent: 20),
            _buildStatRow('Nº de Parcelas Amostradas:', result.totalParcelasAmostradas.toString()),
            _buildStatRow('Nº de Árvores Medidas:', result.totalArvoresAmostradas.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard(String title, List<String> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      color: color,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Text('- $item'))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}