// lib/pages/projetos/lista_projetos_page.dart (VERSÃO FINAL COM PERMISSÕES RESTAURADAS PARA TODOS)

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// Imports do projeto
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/pages/projetos/detalhes_projeto_page.dart';
import 'package:geoforestcoletor/providers/license_provider.dart';
import 'package:geoforestcoletor/services/sync_service.dart';
import 'form_projeto_page.dart';

class ListaProjetosPage extends StatefulWidget {
  final String title;
  final bool isImporting;

  const ListaProjetosPage({
    super.key,
    required this.title,
    this.isImporting = false,
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
  
  // A variável 'isGerente' agora é usada APENAS para a função de arquivar e para a lista de projetos.
  bool _isGerente = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserRoleAndLoadProjects();
    });
  }

  Future<void> _checkUserRoleAndLoadProjects() async {
    final licenseProvider = context.read<LicenseProvider>();
    setState(() {
      _isGerente = licenseProvider.licenseData?.cargo == 'gerente';
      _isLoading = true;
    });

    final data = _isGerente
        ? await dbHelper.getTodosOsProjetosParaGerente()
        : await dbHelper.getTodosProjetos();

    if (mounted) {
      setState(() {
        projetos = data;
        _isLoading = false;
      });
    }
  }

  // A função de arquivar continua sendo exclusiva do gerente.
  Future<void> _toggleArchiveStatus(Projeto projeto) async {
    if (!_isGerente) return;

    final novoStatus = projeto.status == 'ativo' ? 'arquivado' : 'ativo';
    final acao = novoStatus == 'arquivado' ? 'Arquivar' : 'Reativar';

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$acao Projeto'),
        content: Text('Tem certeza que deseja $acao o projeto "${projeto.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: novoStatus == 'arquivado' ? Colors.orange.shade700 : Colors.green.shade600,
            ),
            child: Text(acao),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final projetoAtualizado = projeto.copyWith(status: novoStatus);
        final db = await dbHelper.database;
        await db.update('projetos', projetoAtualizado.toMap(), where: 'id = ?', whereArgs: [projeto.id]);

        final syncService = SyncService();
        await syncService.atualizarStatusProjetoNaFirebase(projeto.id!.toString(), novoStatus);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Projeto ${projeto.nome} foi atualizado para "$novoStatus".'), backgroundColor: Colors.green),
        );
        
        await _checkUserRoleAndLoadProjects();

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar status: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

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
        Navigator.of(context).pop();
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resultado da Importação'),
            content: SingleChildScrollView(child: Text(message)),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
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
      await _checkUserRoleAndLoadProjects();
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
      _checkUserRoleAndLoadProjects();
    }
  }
  
  void _navegarParaDetalhes(Projeto projeto) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => DetalhesProjetoPage(projeto: projeto)))
      .then((_) => _checkUserRoleAndLoadProjects());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : projetos.isEmpty
              ? _buildEmptyState()
              : _buildListView(),
      // <<< PERMISSÃO RESTAURADA >>>
      // O botão de adicionar agora aparece para todos, exceto no modo de importação.
      floatingActionButton: widget.isImporting ? null : _buildAddProjectButton(),
    );
  }
  
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: projetos.length,
      itemBuilder: (context, index) {
        final projeto = projetos[index];
        final isSelected = _selectedProjetos.contains(projeto.id!);
        final isArchived = projeto.status == 'arquivado';

        return Slidable(
          key: ValueKey(projeto.id),
          // <<< PERMISSÃO RESTAURADA >>>
          // As ações de deslizar agora estão disponíveis para todos,
          // com uma condição interna apenas para o botão de arquivar.
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: _isGerente ? 0.5 : 0.25, // O gerente vê 2 botões, a equipe vê 1.
            children: [
              SlidableAction(
                onPressed: (_) => _navegarParaEdicao(projeto),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                icon: Icons.edit_outlined,
                label: 'Editar',
              ),
              // O botão de arquivar continua sendo exclusivo do gerente
              if (_isGerente)
                SlidableAction(
                  onPressed: (_) => _toggleArchiveStatus(projeto),
                  backgroundColor: isArchived ? Colors.green.shade600 : Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  label: isArchived ? 'Reativar' : 'Arquivar',
                ),
            ],
          ),
          child: Card(
            color: isArchived ? Colors.grey.shade300 : (isSelected ? Colors.lightBlue.shade100 : null),
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
              // <<< PERMISSÃO RESTAURADA >>>
              // A seleção por toque longo agora está disponível para todos.
              onLongPress: () => _toggleSelection(projeto.id!),
              leading: Icon(
                isSelected ? Icons.check_circle : (isArchived ? Icons.archive_rounded : Icons.folder_outlined),
                color: isArchived ? Colors.grey.shade700 : Theme.of(context).primaryColor,
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
          // <<< PERMISSÃO RESTAURADA >>>
          // A mensagem de ajuda aparece para todos.
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
            if (criado == true) _checkUserRoleAndLoadProjects();
          });
      },
      tooltip: 'Adicionar Projeto',
      child: const Icon(Icons.add),
    );
  }
}