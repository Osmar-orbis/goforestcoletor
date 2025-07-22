// lib/models/projeto_model.dart

class Projeto {
  final int? id;
  final String nome;
  final String empresa;
  final String responsavel;
  final DateTime dataCriacao;
  final String status; // <<< ADICIONADO

  Projeto({
    this.id,
    required this.nome,
    required this.empresa,
    required this.responsavel,
    required this.dataCriacao,
    this.status = 'ativo', // <<< ADICIONADO (com valor padrão)
  });

  Projeto copyWith({
    int? id,
    String? nome,
    String? empresa,
    String? responsavel,
    DateTime? dataCriacao,
    String? status, // <<< ADICIONADO
  }) {
    return Projeto(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      empresa: empresa ?? this.empresa,
      responsavel: responsavel ?? this.responsavel,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      status: status ?? this.status, // <<< ADICIONADO
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'empresa': empresa,
      'responsavel': responsavel,
      'dataCriacao': dataCriacao.toIso8601String(),
      'status': status, // <<< ADICIONADO
    };
  }

  factory Projeto.fromMap(Map<String, dynamic> map) {
    return Projeto(
      id: map['id'],
      nome: map['nome'],
      empresa: map['empresa'],
      responsavel: map['responsavel'],
      dataCriacao: DateTime.parse(map['dataCriacao']),
      status: map['status'] ?? 'ativo', // <<< ADICIONADO
    );
  }
}