// lib/pages/fazenda/form_fazenda_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/fazenda_model.dart';
import 'package:sqflite/sqflite.dart';

class FormFazendaPage extends StatefulWidget {
  final int atividadeId;
  final Fazenda? fazendaParaEditar; 

  const FormFazendaPage({
    super.key,
    required this.atividadeId,
    this.fazendaParaEditar, 
  });

  bool get isEditing => fazendaParaEditar != null;

  @override
  State<FormFazendaPage> createState() => _FormFazendaPageState();
}

class _FormFazendaPageState extends State<FormFazendaPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nomeController = TextEditingController();
  final _municipioController = TextEditingController();
  final _estadoController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final fazenda = widget.fazendaParaEditar!;
      _idController.text = fazenda.id;
      _nomeController.text = fazenda.nome;
      _municipioController.text = fazenda.municipio;
      _estadoController.text = fazenda.estado;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nomeController.dispose();
    _municipioController.dispose();
    _estadoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);

      final fazenda = Fazenda(
        id: _idController.text.trim(),
        atividadeId: widget.atividadeId,
        nome: _nomeController.text.trim(),
        municipio: _municipioController.text.trim(),
        estado: _estadoController.text.trim().toUpperCase(),
      );

      try {
        final dbHelper = DatabaseHelper.instance;
        
        if (widget.isEditing) {
            // No modo de edição, não podemos simplesmente dar update no ID, pois ele faz parte da chave primária.
            // A melhor abordagem é apagar e inserir novamente, garantindo que o ID permaneça o mesmo.
            // O DatabaseHelper não tem um método update para fazenda, então esta é a lógica correta.
            await dbHelper.deleteFazenda(widget.fazendaParaEditar!.id, widget.fazendaParaEditar!.atividadeId);
        }
        await dbHelper.insertFazenda(fazenda);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fazenda ${widget.isEditing ? 'atualizada' : 'criada'} com sucesso!'),
              backgroundColor: Colors.green
            ),
          );
          Navigator.of(context).pop(true);
        }
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError() && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: O ID "${fazenda.id}" já existe para esta atividade.'), backgroundColor: Colors.red),
          );
        } else if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro de banco de dados ao salvar: $e'), backgroundColor: Colors.red),
          );
        }
      } 
      catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ocorreu um erro inesperado: $e'), backgroundColor: Colors.red),
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
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Fazenda' : 'Nova Fazenda'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _idController,
                // <<< ALTERAÇÃO PRINCIPAL AQUI >>>
                enabled: !widget.isEditing,
                style: TextStyle(
                  color: widget.isEditing ? Colors.grey.shade600 : null,
                ),
                decoration: InputDecoration(
                  labelText: 'ID da Fazenda (Código do Cliente)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  // Adiciona uma cor de preenchimento para indicar que está desabilitado
                  filled: widget.isEditing,
                  fillColor: Colors.grey.shade200,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O ID da fazenda é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Fazenda',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.maps_home_work_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome da fazenda é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _municipioController,
                decoration: const InputDecoration(
                  labelText: 'Município',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O município é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _estadoController,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Estado (UF)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public_outlined),
                  counterText: "",
                ),
                 validator: (value) {
                  if (value == null || value.trim().length != 2) {
                    return 'Informe a sigla do estado (ex: SP).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvar,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar Fazenda'),
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