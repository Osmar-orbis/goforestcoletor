// lib/pages/planejamento/selecao_atividade_mapa_page.dart (VERSÃO COMPLETA E CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/pages/menu/map_import_page.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:provider/provider.dart';

class SelecaoAtividadeMapaPage extends StatefulWidget {
  const SelecaoAtividadeMapaPage({super.key});

  @override
  State<SelecaoAtividadeMapaPage> createState() => _SelecaoAtividadeMapaPageState();
}

class _SelecaoAtividadeMapaPageState extends State<SelecaoAtividadeMapaPage> {
  final dbHelper = DatabaseHelper.instance;
  late Future<List<Projeto>> _projetosFuture;
  final Map<int, List<Atividade>> _atividadesPorProjeto = {};
  bool _isLoadingAtividades = false;

  @override
  void initState() {
    super.initState();
    _projetosFuture = dbHelper.getTodosProjetos();
  }

  Future<void> _carregarAtividadesDoProjeto(int projetoId) async {
    if (_atividadesPorProjeto.containsKey(projetoId)) return;

    setState(() => _isLoadingAtividades = true);
    final atividades = await dbHelper.getAtividadesDoProjeto(projetoId);
    if (mounted) {
      setState(() {
        _atividadesPorProjeto[projetoId] = atividades;
        _isLoadingAtividades = false;
      });
    }
  }

  void _navegarParaMapa(Atividade atividade) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    // 1. Limpa qualquer estado antigo do mapa.
    mapProvider.clearAllMapData();
    // 2. Define a atividade atual no provider.
    mapProvider.setCurrentAtividade(atividade);
    // 3. Carrega as amostras existentes para essa atividade, se houver.
    mapProvider.loadSamplesParaAtividade();

    // 4. Navega para a página do mapa (que agora não precisa de parâmetros).
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapImportPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar Atividade'),
      ),
      body: FutureBuilder<List<Projeto>>(
        future: _projetosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          final projetos = snapshot.data ?? [];
          if (projetos.isEmpty) {
            return const Center(child: Text('Nenhum projeto encontrado.'));
          }

          return ListView.builder(
            itemCount: projetos.length,
            itemBuilder: (context, index) {
              final projeto = projetos[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ExpansionTile(
                  title: Text(projeto.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  onExpansionChanged: (isExpanding) {
                    if (isExpanding) {
                      _carregarAtividadesDoProjeto(projeto.id!);
                    }
                  },
                  children: [
                    if (_isLoadingAtividades && !_atividadesPorProjeto.containsKey(projeto.id))
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_atividadesPorProjeto[projeto.id]?.isEmpty ?? true)
                      const ListTile(title: Text('Nenhuma atividade neste projeto.'))
                    else
                      ..._atividadesPorProjeto[projeto.id]!.map((atividade) {
                        return ListTile(
                          title: Text(atividade.tipo),
                          subtitle: Text(atividade.descricao.isNotEmpty ? atividade.descricao : 'Sem descrição'),
                          leading: const Icon(Icons.arrow_right),
                          onTap: () => _navegarParaMapa(atividade),
                          trailing: const Icon(Icons.map_outlined, color: Colors.grey),
                        );
                      }).toList()
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}