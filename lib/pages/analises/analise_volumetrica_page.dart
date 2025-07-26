// lib/pages/analises/analise_volumetrica_page.dart (VERSÃO FINAL COM FILTROS)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Imports do seu projeto
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/providers/license_provider.dart';
import 'package:geoforestcoletor/services/analysis_service.dart';
import 'package:geoforestcoletor/services/pdf_service.dart';

class AnaliseVolumetricaPage extends StatefulWidget {
  const AnaliseVolumetricaPage({super.key});

  @override
  State<AnaliseVolumetricaPage> createState() => _AnaliseVolumetricaPageState();
}

class _AnaliseVolumetricaPageState extends State<AnaliseVolumetricaPage> {
  final dbHelper = DatabaseHelper.instance;
  final analysisService = AnalysisService();
  final pdfService = PdfService();

  // Estados para o Filtro
  List<Projeto> _projetosDisponiveis = [];
  Projeto? _projetoSelecionado;

  // Estados para as listas de dados
  List<Talhao> _todosTalhoesCubadosDaLicenca = [];
  List<Talhao> _todosTalhoesInventarioDaLicenca = [];
  final Set<int> _talhoesCubadosSelecionados = {};
  final Set<int> _talhoesInventarioSelecionados = {};

  // Estados para resultados e controle de UI
  Map<String, dynamic>? _resultadoRegressao;
  Map<String, dynamic>? _tabelaProducaoInventario;
  Map<String, dynamic>? _tabelaProducaoSortimento;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDadosIniciais();
    });
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final licenseProvider = context.read<LicenseProvider>();
      if (licenseProvider.licenseData == null) {
        throw Exception("Dados da licença não encontrados.");
      }
      final licenseId = licenseProvider.licenseData!.id;

      // Busca e armazena os projetos para o dropdown do filtro
      final projetos = await dbHelper.getTodosProjetos(licenseId);
      
      // Busca todos os talhões da licença
      final List<Talhao> todosTalhoesDaLicenca = [];
      for (var proj in projetos) {
        final atividades = await dbHelper.getAtividadesDoProjeto(proj.id!);
        for (var atv in atividades) {
          final fazendas = await dbHelper.getFazendasDaAtividade(atv.id!);
          for (var faz in fazendas) {
            todosTalhoesDaLicenca.addAll(await dbHelper.getTalhoesDaFazenda(faz.id, faz.atividadeId));
          }
        }
      }

      // Separa os talhões em listas para cubagem e inventário
      final todasCubagens = await dbHelper.getTodasCubagens();
      final idsTalhoesCubados = todasCubagens.map((a) => a.talhaoId).where((id) => id != null).toSet();
      final talhoesInventario = await dbHelper.getTalhoesComParcelasConcluidas();
      final idsTalhoesInventario = talhoesInventario.map((t) => t.id).toSet();

      if (mounted) {
        setState(() {
          _projetosDisponiveis = projetos;
          _todosTalhoesCubadosDaLicenca = todosTalhoesDaLicenca.where((t) => idsTalhoesCubados.contains(t.id)).toList();
          _todosTalhoesInventarioDaLicenca = todosTalhoesDaLicenca.where((t) => idsTalhoesInventario.contains(t.id)).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Erro ao carregar dados: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _onFilterChanged(Projeto? novoProjeto) {
    setState(() {
      _projetoSelecionado = novoProjeto;
      // Limpa as seleções ao mudar o filtro para evitar inconsistências
      _talhoesCubadosSelecionados.clear();
      _talhoesInventarioSelecionados.clear();
    });
  }

  // O resto do seu código (_gerarAnaliseCompleta, build, etc.) permanece o mesmo,
  // mas agora ele vai ler as listas filtradas que preparamos no _buildBody.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise Volumétrica'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: (_resultadoRegressao == null || _isAnalyzing) ? null : () {}, // _exportarAnaliseVolumetricaPdf,
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
        onPressed: _isAnalyzing ? null : () {}, // _gerarAnaliseCompleta,
        icon: _isAnalyzing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.functions),
        label: Text(_isAnalyzing ? 'Analisando...' : 'Gerar Análise Completa'),
      ),
    );
  }

  Widget _buildBody() {
    // LÓGICA DE FILTRO APLICADA AQUI
    final List<Talhao> talhoesCubadosParaExibir = _projetoSelecionado == null
        ? _todosTalhoesCubadosDaLicenca
        : _todosTalhoesCubadosDaLicenca.where((t) => t.projetoId == _projetoSelecionado!.id).toList();

    final List<Talhao> talhoesInventarioParaExibir = _projetoSelecionado == null
        ? _todosTalhoesInventarioDaLicenca
        : _todosTalhoesInventarioDaLicenca.where((t) => t.projetoId == _projetoSelecionado!.id).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: DropdownButtonFormField<Projeto?>(
            value: _projetoSelecionado,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Filtrar por Projeto',
              border: const OutlineInputBorder(),
              suffixIcon: _projetoSelecionado != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _onFilterChanged(null)) : null,
            ),
            hint: const Text('Mostrar todos os projetos'),
            items: [
              const DropdownMenuItem<Projeto?>(
                value: null,
                child: Text('Mostrar todos os projetos'),
              ),
              ..._projetosDisponiveis.map((projeto) {
                return DropdownMenuItem(value: projeto, child: Text(projeto.nome));
              }).toList(),
            ],
            onChanged: _onFilterChanged,
          ),
        ),
        _buildSelectionCard(
            '1. Selecione os Talhões CUBADOS',
            'Serão usados para gerar a equação de volume.',
            talhoesCubadosParaExibir, // <-- USA A LISTA FILTRADA
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
            talhoesInventarioParaExibir, // <-- USA A LISTA FILTRADA
            _talhoesInventarioSelecionados,
            (id, selected) => setState(() => selected ? _talhoesInventarioSelecionados.add(id) : _talhoesInventarioSelecionados.remove(id))) ,
        
        if (_resultadoRegressao != null) Container(), //_buildResultCard(),
        if (_tabelaProducaoSortimento != null) Container(), //_buildSortmentTable(),
        if (_tabelaProducaoInventario != null) Container(), //_buildProductionTable(),
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
            if (talhoes.isEmpty) const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Nenhum talhão disponível para este filtro.'),
            ),
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
}