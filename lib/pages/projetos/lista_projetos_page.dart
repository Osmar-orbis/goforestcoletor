// lib/pages/projetos/lista_projetos_page.dart (VERSÃO COM SELEÇÃO DE PROJETO PARA IMPORTAÇÃO)

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/pages/projetos/detalhes_projeto_page.dart';
import 'form_projeto_page.dart';

class ListaProjetosPage extends StatefulWidget {
  final String title;
  final bool isImporting; // <<< PARÂMETRO RESTAURADO

  const ListaProjetosPage({
    super.key,
    required this.title,
    this.isImporting = false, // Valor padrão é false
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

  // <<< NOVA FUNÇÃO PARA INICIAR A IMPORTAÇÃO APÓS SELECIONAR UM PROJETO >>>
  Future<void> _iniciarImportacao(Projeto projeto) async {
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
      
      final message = await DatabaseHelper.instance.importarCsvUniversal(csvContent, projetoIdAlvo: projeto.id!);
      
      if (mounted) {
        Navigator.of(context).pop(); // Fecha o dialog de "processando"
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resultado da Importação'),
            content: SingleChildScrollView(child: Text(message)),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
        // Fecha a tela de seleção de projetos após a importação
        Navigator.of(context).pop(); 
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ... (funções de seleção e exclusão permanecem as mesmas)
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
              content: Text('Tem certeza que deseja apagar os ${_selectedProjetos.length} projetos selecionados e TODOS os seus dados? Esta ação é PERMANENTE.'),
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

  void _navegarParaEdicao(Projeto projeto) async {
    final bool? projetoEditado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormProjetoPage(
          projetoParaEditar: projeto,
        ),
      ),
    );
    if (projetoEditado == true && mounted) {
      _carregarProjetos();
    }
  }
  
  void _navegarParaDetalhes(Projeto projeto) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => DetalhesProjetoPage(projeto: projeto)))
      .then((_) => _carregarProjetos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : projetos.isEmpty
              ? _buildEmptyState()
              : _buildListView(), // <<< MÉTODO DE CONSTRUÇÃO DA LISTA UNIFICADO
      floatingActionButton: widget.isImporting ? null : _buildAddProjectButton(),
    );
  }
  
  // <<< O MÉTODO buildListView AGORA LIDA COM AMBOS OS CASOS >>>
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: projetos.length,
      itemBuilder: (context, index) {
        final projeto = projetos[index];
        final isSelected = _selectedProjetos.contains(projeto.id!);

        return Slidable(
          key: ValueKey(projeto.id),
          startActionPane: widget.isImporting ? null : ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
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
              onTap: () {
                if (widget.isImporting) {
                  _iniciarImportacao(projeto);
                } else if (_isSelectionMode) {
                  _toggleSelection(projeto.id!);
                } else {
                  _navegarParaDetalhes(projeto);
                }
              },
              onLongPress: widget.isImporting ? null : () => _toggleSelection(projeto.id!),
              leading: Icon(
                widget.isImporting
                    ? Icons.file_download_done_outlined
                    : (isSelected ? Icons.check_circle : Icons.folder_outlined),
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

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.title),
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