// lib/pages/projetos/lista_projetos_page.dart (VERSÃO COM EDIÇÃO DE PROJETO)

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
// <<< MUDANÇA 1 >>> Import do Slidable
import 'package:flutter_slidable/flutter_slidable.dart'; 
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/pages/projetos/detalhes_projeto_page.dart';
import 'form_projeto_page.dart';

// <<< MUDANÇA 2 >>> Import do form_projeto_page para reutilização no modo de edição


class ListaProjetosPage extends StatefulWidget {
  final String title;
  final bool isImporting;
  final String? importType;

  const ListaProjetosPage({
    super.key,
    required this.title,
    this.isImporting = false,
    this.importType,
  });

  @override
  State<ListaProjetosPage> createState() => _ListaProjetosPageState();
}

class _ListaProjetosPageState extends State<ListaProjetosPage> {
  final dbHelper = DatabaseHelper.instance;
  List<Projeto> projetos = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final Set<int> _selectedProjetos = {};

  final Map<int, List<Atividade>> _atividadesPorProjeto = {};
  bool _isLoadingAtividades = false;

  @override
  void initState() {
    super.initState();
    _carregarProjetos();
  }

  Future<void> _carregarProjetos() async {
    setState(() => _isLoading = true);
    final data = await dbHelper.getTodosProjetos();
    if (mounted) {
      setState(() {
        projetos = data;
        _isLoading = false;
      });
    }
  }
  
  // --- MÉTODOS PARA O MODO DE VISUALIZAÇÃO/EDIÇÃO ---

  void _clearSelection() {
    if (mounted) {
      setState(() {
        _selectedProjetos.clear();
        _isSelectionMode = false;
      });
    }
  }

  void _toggleSelection(int projetoId) {
    if (mounted) {
      setState(() {
        if (_selectedProjetos.contains(projetoId)) {
          _selectedProjetos.remove(projetoId);
        } else {
          _selectedProjetos.add(projetoId);
        }
        _isSelectionMode = _selectedProjetos.isNotEmpty;
      });
    }
  }

  Future<void> _deletarProjetosSelecionados() async {
    if (_selectedProjetos.isEmpty || !mounted) return;

    final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Confirmar Exclusão'),
              content: Text('Tem certeza que deseja apagar os ${_selectedProjetos.length} projetos selecionados e TODOS os seus dados (atividades, fazendas, coletas, etc)? Esta ação é PERMANENTE.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Apagar')),
              ],
            ));
    if (confirmar == true && mounted) {
      for (final id in _selectedProjetos) {
        await dbHelper.deleteProjeto(id);
      }
      _clearSelection();
      await _carregarProjetos();
    }
  }

  // <<< MUDANÇA 3 >>> Nova função para navegar para a tela de edição
  void _navegarParaEdicao(Projeto projeto) async {
    final bool? projetoEditado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        // Reutilizamos a FormProjetoPage, passando o projeto a ser editado
        builder: (context) => FormProjetoPage(
          projetoParaEditar: projeto,
        ),
      ),
    );
    // Se a edição foi salva com sucesso, recarregamos a lista
    if (projetoEditado == true && mounted) {
      _carregarProjetos();
    }
  }
  
  void _navegarParaDetalhes(Projeto projeto) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => DetalhesProjetoPage(projeto: projeto)))
      .then((_) => _carregarProjetos());
  }
  
  // --- MÉTODOS PARA O MODO DE IMPORTAÇÃO ---

  Future<void> _carregarAtividadesDoProjeto(int projetoId) async {
    if (_atividadesPorProjeto.containsKey(projetoId)) return;
    if (mounted) setState(() => _isLoadingAtividades = true);
    final atividades = await dbHelper.getAtividadesDoProjeto(projetoId);
    if (mounted) {
      setState(() {
        _atividadesPorProjeto[projetoId] = atividades;
        _isLoadingAtividades = false;
      });
    }
  }
  
  // (O resto dos métodos de importação permanece igual)
  Future<void> _iniciarImportacao(Atividade atividade) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importação cancelada.')));
      return;
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Processando arquivo..."),
          ],
        ),
      ),
    );

    try {
      final file = File(result.files.single.path!);
      final csvContent = await file.readAsString();
      String message;

      // <<< CORREÇÃO NA IMPORTAÇÃO >>> A importação de CSV precisa do ID do PROJETO, não da atividade.
      final projetoPai = projetos.firstWhere((p) => _atividadesPorProjeto[p.id]?.contains(atividade) ?? false);
      final projetoId = projetoPai.id!;

      switch (widget.importType) {
        case 'cubagem':
          message = await dbHelper.importarCubagemDeEquipe(csvContent, projetoId);
          break;
        case 'parcela':
        default:
          message = await dbHelper.importarColetaDeEquipe(csvContent, projetoId);
          break;
      }
      
      if (mounted) {
        Navigator.of(context).pop(); // Fecha o dialog de "processando"
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resultado da Importação'),
            content: Text(message),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
          ),
        );
        Navigator.of(context).pop(); // Volta para a tela de menu
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Fecha o dialog de "processando"
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  // --- WIDGETS DE CONSTRUÇÃO ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : projetos.isEmpty
              ? _buildEmptyState()
              : widget.isImporting ? _buildImportListView() : _buildNormalListView(),
      floatingActionButton: widget.isImporting ? null : _buildAddProjectButton(),
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          icon: const Icon(Icons.upload_file_outlined),
          onPressed: () { /* Ação de importar GeoJSON se necessário */},
          tooltip: 'Importar Carga de Projeto (GeoJSON)',
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection),
      title: Text('${_selectedProjetos.length} selecionados'),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _deletarProjetosSelecionados,
          tooltip: 'Apagar Selecionados',
        ),
      ],
    );
  }

  Widget _buildNormalListView() {
    return ListView.builder(
      itemCount: projetos.length,
      itemBuilder: (context, index) {
        final projeto = projetos[index];
        final isSelected = _selectedProjetos.contains(projeto.id!);

        // <<< MUDANÇA 4 >>> O Card agora é envolvido por um Slidable
        return Slidable(
          key: ValueKey(projeto.id),
          // Ações que aparecem ao deslizar (neste caso, da esquerda para a direita)
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25, // Ocupa 25% da largura
            children: [
              SlidableAction(
                onPressed: (_) => _navegarParaEdicao(projeto),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                icon: Icons.edit_outlined,
                label: 'Editar',
              ),
            ],
          ),
          child: Card(
            color: isSelected ? Colors.lightBlue.shade100 : null,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              onTap: () => _isSelectionMode ? _toggleSelection(projeto.id!) : _navegarParaDetalhes(projeto),
              onLongPress: () => _toggleSelection(projeto.id!),
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.folder_outlined,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(projeto.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Responsável: ${projeto.responsavel}'),
              trailing: Text(DateFormat('dd/MM/yy').format(projeto.dataCriacao)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImportListView() {
    return ListView.builder(
      itemCount: projetos.length,
      itemBuilder: (context, index) {
        final projeto = projetos[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            leading: Icon(Icons.folder_copy_outlined, color: Theme.of(context).primaryColor),
            title: Text(projeto.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(projeto.responsavel),
            onExpansionChanged: (isExpanding) {
              if (isExpanding) _carregarAtividadesDoProjeto(projeto.id!);
            },
            children: [
              if (_isLoadingAtividades && !_atividadesPorProjeto.containsKey(projeto.id))
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_atividadesPorProjeto[projeto.id]?.isEmpty ?? true)
                const ListTile(
                  title: Text('Nenhuma atividade neste projeto.'),
                  leading: Icon(Icons.info_outline, color: Colors.grey),
                )
              else
                ..._atividadesPorProjeto[projeto.id]!.map((atividade) {
                  return ListTile(
                    title: Text(atividade.tipo),
                    subtitle: Text(atividade.descricao.isNotEmpty ? atividade.descricao : 'Sem descrição'),
                    leading: const Icon(Icons.file_download_outlined, color: Colors.green),
                    onTap: () => _iniciarImportacao(atividade),
                  );
                }).toList()
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Nenhum projeto encontrado.', style: TextStyle(fontSize: 18)),
          if (!widget.isImporting)
            const Text('Use o botão "+" para adicionar um novo.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAddProjectButton() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const FormProjetoPage()))
          .then((criado) {
            if (criado == true) _carregarProjetos();
          });
      },
      tooltip: 'Adicionar Projeto',
      child: const Icon(Icons.add),
    );
  }
}