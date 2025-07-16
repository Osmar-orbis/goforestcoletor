// lib/pages/dashboard/dashboard_page.dart (VERSÃO COM FILTRO DE KPI E LÓGICA CORRETA)

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';

class DashboardPage extends StatefulWidget {
  final int parcelaId;
  const DashboardPage({super.key, required this.parcelaId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  String _errorMessage = '';

  Map<String, double> _distribuicaoPorCodigo = {};
  List<Map<String, dynamic>> _dadosCAP = []; 

  int _totalFustes = 0; 
  int _totalCovas = 0;
  double _mediaCAP = 0.0;
  double _minCAP = 0.0;
  double _maxCAP = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final dbHelper = DatabaseHelper.instance;
      final results = await Future.wait([
        dbHelper.getDistribuicaoPorCodigo(widget.parcelaId),
        dbHelper.getValoresCAP(widget.parcelaId),
      ]);

      final codigoData = results[0] as Map<String, double>;
      final capData = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _distribuicaoPorCodigo = codigoData;
          _dadosCAP = capData;
          _calculateKPIs();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao carregar dados do relatório: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _calculateKPIs() {
    _totalFustes = 0;
    _distribuicaoPorCodigo.forEach((key, value) {
      if (key != 'falha' && key != 'caida') {
        _totalFustes += value.toInt();
      }
    });

    _totalCovas = _distribuicaoPorCodigo.values.fold(0, (prev, element) => prev + element.toInt());

    final valoresValidos = _dadosCAP
        .where((dado) => 
            dado['codigo'] != 'falha' && 
            dado['codigo'] != 'caida' && 
            dado['codigo'] != 'morta')
        .map((dado) => dado['cap'] as double)
        .toList();

    if (valoresValidos.isEmpty) {
      _mediaCAP = 0.0;
      _minCAP = 0.0;
      _maxCAP = 0.0;
    } else {
      _mediaCAP = valoresValidos.reduce((a, b) => a + b) / valoresValidos.length;
      _minCAP = valoresValidos.reduce(min);
      _maxCAP = valoresValidos.reduce(max);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Relatório da Parcela ${widget.parcelaId}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDashboardData,
            tooltip: 'Atualizar Dados',
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)));
    }
    if (_distribuicaoPorCodigo.isEmpty) {
      return const Center(child: Text("Nenhuma árvore coletada para gerar relatório."));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKPIs(),
          const SizedBox(height: 24),
          _buildSectionTitle("Distribuição por Código"),
          SizedBox(height: 250, child: _buildCodeBarChart()), 
          const SizedBox(height: 24),
          _buildSectionTitle("Histograma de CAP"),
          SizedBox(height: 300, child: _buildHistogram()),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildKPIs() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 16.0,
          runSpacing: 16.0,
          children: [
            _kpiCard('Total de Covas', _totalCovas.toString(), Icons.grid_on),
            _kpiCard('Total de Fustes', _totalFustes.toString(), Icons.park),
            _kpiCard('Média CAP', '${_mediaCAP.toStringAsFixed(1)} cm', Icons.straighten),
            _kpiCard('Min CAP', '${_minCAP.toStringAsFixed(1)} cm', Icons.arrow_downward),
            _kpiCard('Max CAP', '${_maxCAP.toStringAsFixed(1)} cm', Icons.arrow_upward),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildCodeBarChart() {
    if (_distribuicaoPorCodigo.isEmpty) return const SizedBox.shrink();
    final entries = _distribuicaoPorCodigo.entries.toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (entries.map((e) => e.value).reduce(max)) * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
             getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${entries[groupIndex].key}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(
                    text: rod.toY.toInt().toString(),
                    style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(
                    entries[value.toInt()].key,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(entries.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entries[index].value,
                color: Theme.of(context).colorScheme.secondary,
                width: 22,
                borderRadius: BorderRadius.zero,
              )
            ],
          );
        }),
      ),
    );
  }
  
  Widget _buildHistogram() {
    final valoresValidos = _dadosCAP
        .where((dado) => 
            dado['codigo'] != 'falha' && 
            dado['codigo'] != 'caida' && 
            dado['codigo'] != 'morta')
        .map((dado) => dado['cap'] as double)
        .toList();

    if (valoresValidos.isEmpty) return const Center(child: Text("Sem dados de CAP válidos para o histograma."));

    final double minVal = valoresValidos.reduce(min);
    double maxVal = valoresValidos.reduce(max);

    if (minVal == maxVal) {
      maxVal = minVal + 10;
    }

    final int numBins = min(10, (maxVal - minVal).floor() + 1);
    if (numBins <= 0) return const Center(child: Text("Dados insuficientes para o histograma."));

    final double binSize = (maxVal - minVal) / numBins;

    List<int> bins = List.filled(numBins, 0);
    List<double> binStarts = List.generate(numBins, (i) => minVal + i * binSize);

    for (double val in valoresValidos) {
      int binIndex = binSize > 0 ? ((val - minVal) / binSize).floor() : 0;
      if (binIndex >= numBins) binIndex = numBins - 1;
      if (binIndex < 0) binIndex = 0;
      bins[binIndex]++;
    }

    final double maxY = bins.isEmpty ? 1 : (bins.reduce(max).toDouble()) * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
             getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final binStart = binStarts[group.x.toInt()];
              final binEnd = binStart + binSize;
              return BarTooltipItem(
                'CAP: ${binStart.toStringAsFixed(0)}-${binEnd.toStringAsFixed(0)}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(
                    text: '${rod.toY.toInt()} árvores',
                    style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value.toInt() >= binStarts.length) return const SizedBox.shrink();
                final String text = binStarts[value.toInt()].toStringAsFixed(0);
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(text, style: const TextStyle(fontSize: 10)),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: true),
        barGroups: List.generate(numBins, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: bins[index].toDouble(),
                color: Theme.of(context).primaryColor,
                width: 15,
                borderRadius: BorderRadius.zero,
              )
            ],
          );
        }),
      ),
    );
  }
}