// lib/pages/gerente/gerente_dashboard_page.dart (VERSÃO COM BOTÃO PARA O MAPA)

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/providers/gerente_provider.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';


class GerenteDashboardPage extends StatelessWidget {
  const GerenteDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GerenteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(child: Text('Ocorreu um erro:\n${provider.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
        }

        final progressoGeral = provider.parcelasFiltradas.isNotEmpty ? provider.parcelasFiltradas.where((p) => p.status == StatusParcela.concluida).length / provider.parcelasFiltradas.length : 0.0;

        // <<< MUDANÇA 1: Adicionado o Scaffold para abrigar o FloatingActionButton >>>
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async => context.read<GerenteProvider>().iniciarMonitoramento(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0), // Adiciona padding no final para não cobrir o último card
              children: [
                _buildProjectFilter(context, provider),
                const SizedBox(height: 16),
                
                if (provider.progressoPorStatus.isNotEmpty)
                  _buildPieChartCard(context, provider.progressoPorStatus),
                const SizedBox(height: 16),
                
                _buildSummaryCard(
                  context: context,
                  title: 'Progresso Geral',
                  value: '${(progressoGeral * 100).toStringAsFixed(0)}%',
                  subtitle: '${provider.parcelasFiltradas.where((p) => p.status == StatusParcela.concluida).length} de ${provider.parcelasFiltradas.length} parcelas concluídas',
                  progress: progressoGeral,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                
                if (provider.coletasPorMes.isNotEmpty)
                  _buildLineChartCard(context, provider.coletasPorMes),
                const SizedBox(height: 24),

                if (provider.progressoPorFazenda.isNotEmpty) ...[
                  Text('Desempenho por Fazenda', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(),
                  const SizedBox(height: 8),
                  SizedBox(height: 250, child: Card(elevation: 2, child: Padding(padding: const EdgeInsets.fromLTRB(8, 16, 8, 8), child: _buildBarChart(context, provider.progressoPorFazenda)))),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
          // <<< MUDANÇA 2: Adicionado o FloatingActionButton >>>
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              // Navega para a nova rota que vamos criar no próximo passo
              Navigator.pushNamed(context, '/gerente_map');
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Mapa Geral'),
          ),
        );
      },
    );
  }

  Widget _buildProjectFilter(BuildContext context, GerenteProvider provider) {
    return DropdownButtonFormField<int?>(
      value: provider.selectedProjetoId,
      hint: const Text('Filtrar por Projeto'),
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Todos os Projetos')),
        ...provider.projetosDisponiveis.map((Projeto projeto) => DropdownMenuItem<int?>(value: projeto.id, child: Text(projeto.nome))),
      ],
      onChanged: (int? newValue) => provider.selectProjeto(newValue),
    );
  }

  Widget _buildSummaryCard({required BuildContext context, required String title, required String value, required String subtitle, required double progress, required Color color}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(title, style: Theme.of(context).textTheme.titleLarge, overflow: TextOverflow.ellipsis)),
                Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, minHeight: 6, borderRadius: BorderRadius.circular(3), backgroundColor: color.withOpacity(0.2), valueColor: AlwaysStoppedAnimation<Color>(color)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPieChartCard(BuildContext context, Map<StatusParcela, int> data) {
    final totalValue = data.values.fold<double>(0, (prev, e) => prev + e);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Distribuição por Status", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {}),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: data.entries.map((entry) {
                    final percentage = totalValue > 0 ? (entry.value / totalValue) * 100 : 0;
                    return PieChartSectionData(
                      color: entry.key.cor,
                      value: entry.value.toDouble(),
                      title: '${percentage.toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.center,
              children: data.entries.map((entry) => _buildIndicator(color: entry.key.cor, text: '${entry.key.name} (${entry.value})')).toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator({required Color color, required String text}) {
    return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12))
    ]);
  }

  Widget _buildBarChart(BuildContext context, Map<String, Map<String, int>> data) {
    final entries = data.entries.toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final fazenda = entries[groupIndex].key;
              return BarTooltipItem('$fazenda\n', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(text: rod.toY.toInt().toString(), style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.w500)),
                  const TextSpan(text: ' parcelas concluídas'),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (double value, TitleMeta meta) {
            final index = value.toInt();
            if (index >= entries.length) return const SizedBox.shrink();
            final text = entries[index].key.length > 3 ? entries[index].key.substring(0, 3) : entries[index].key;
            return SideTitleWidget(axisSide: meta.axisSide, space: 4, child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)));
          }, reservedSize: 32)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(entries.length, (index) => BarChartGroupData(x: index, barRods: [
          BarChartRodData(toY: entries[index].value['concluidas']!.toDouble(), color: Theme.of(context).colorScheme.primary, width: 22, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)))
        ])),
      ),
    );
  }

  Widget _buildLineChartCard(BuildContext context, Map<String, int> data) {
    final spots = data.entries.mapIndexed((index, e) => FlSpot(index.toDouble(), e.value.toDouble())).toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          children: [
            Text("Coletas Concluídas por Mês", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= data.keys.length) return const SizedBox.shrink();
                      return SideTitleWidget(axisSide: meta.axisSide, child: Text(data.keys.elementAt(index), style: const TextStyle(fontSize: 10)));
                    }, reservedSize: 30)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.teal,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Colors.teal.withOpacity(0.3)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}