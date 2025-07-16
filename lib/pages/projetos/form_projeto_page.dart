// lib/pages/projetos/form_projeto_page.dart (VERSÃO COM SUPORTE PARA EDIÇÃO)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';

class FormProjetoPage extends StatefulWidget {
  // <<< MUDANÇA 1 >>> Adiciona o parâmetro opcional para edição
  final Projeto? projetoParaEditar;

  const FormProjetoPage({
    super.key,
    this.projetoParaEditar,
  });

  // <<< MUDANÇA 2 >>> Adiciona um getter para facilitar a verificação do modo de edição
  bool get isEditing => projetoParaEditar != null;

  @override
  State<FormProjetoPage> createState() => _FormProjetoPageState();
}

class _FormProjetoPageState extends State<FormProjetoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _empresaController = TextEditingController();
  final _responsavelController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // <<< MUDANÇA 3 >>> Lógica para pré-preencher o formulário no modo de edição
    if (widget.isEditing) {
      final projeto = widget.projetoParaEditar!;
      _nomeController.text = projeto.nome;
      _empresaController.text = projeto.empresa;
      _responsavelController.text = projeto.responsavel;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _empresaController.dispose();
    _responsavelController.dispose();
    super.dispose();
  }

  // <<< MUDANÇA 4 >>> Função de salvar agora lida com criação e edição
  Future<void> _salvarProjeto() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      
      // Constrói o objeto Projeto. Se estiver editando, mantém o ID e a data de criação originais.
      final projeto = Projeto(
        id: widget.isEditing ? widget.projetoParaEditar!.id : null,
        nome: _nomeController.text.trim(),
        empresa: _empresaController.text.trim(),
        responsavel: _responsavelController.text.trim(),
        dataCriacao: widget.isEditing ? widget.projetoParaEditar!.dataCriacao : DateTime.now(),
      );

      try {
        final dbHelper = DatabaseHelper.instance;
        final db = await dbHelper.database; // Obtém a instância do banco
        
        if (widget.isEditing) {
          // Se estiver editando, executa um UPDATE
          await db.update(
            'projetos',
            projeto.toMap(),
            where: 'id = ?',
            whereArgs: [projeto.id],
          );
        } else {
          // Se não, executa um INSERT
          await db.insert('projetos', projeto.toMap());
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Projeto ${widget.isEditing ? "atualizado" : "criado"} com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Retorna 'true' para recarregar a lista
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar o projeto: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // <<< MUDANÇA 5 >>> O título da página e o texto do botão agora são dinâmicos
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Projeto' : 'Novo Projeto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Projeto',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome do projeto é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _empresaController,
                decoration: const InputDecoration(
                  labelText: 'Empresa Cliente',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome da empresa é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _responsavelController,
                decoration: const InputDecoration(
                  labelText: 'Responsável Técnico',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                 validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome do responsável é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvarProjeto,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Salvando...' : (widget.isEditing ? 'Atualizar Projeto' : 'Salvar Projeto')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}