// lib/models/projeto_model.dart

class Projeto {
  final String? licenseId;
  final int? id;
  final String nome;
  final String empresa;
  final String responsavel;
  final DateTime dataCriacao;
  final String status; // <<< ADICIONADO

  Projeto({
    this.id,
    this.licenseId,
    required this.nome,
    required this.empresa,
    required this.responsavel,
    required this.dataCriacao,
    this.status = 'ativo', // <<< ADICIONADO (com valor padrão)
  });

  Projeto copyWith({
    int? id,
    String? licenseId,
    String? nome,
    String? empresa,
    String? responsavel,
    DateTime? dataCriacao,
    String? status, // <<< ADICIONADO
  }) {
    return Projeto(
      id: id ?? this.id,
      licenseId: licenseId ?? this.licenseId,
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
      'licenseId': licenseId,
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
      licenseId: map['licenseId'],
      nome: map['nome'],
      empresa: map['empresa'],
      responsavel: map['responsavel'],
      dataCriacao: DateTime.parse(map['dataCriacao']),
      status: map['status'] ?? 'ativo', // <<< ADICIONADO
    );
  }
}