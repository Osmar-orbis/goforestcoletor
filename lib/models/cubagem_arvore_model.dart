// lib/models/cubagem_arvore_model.dart

class CubagemArvore {
  // Atributos do Banco de Dados e Identificação
  int? id;
  int? talhaoId; // Chave estrangeira para o Talhão
  String? idFazenda;
  String nomeFazenda;
  String nomeTalhao;
  String identificador;
  String? classe;
  bool exportada;

  // Atributos de Medição
  double alturaTotal;
  String tipoMedidaCAP;
  double valorCAP;
  double alturaBase;

  CubagemArvore({
    this.id,
    this.talhaoId,
    this.idFazenda,
    required this.nomeFazenda,
    required this.nomeTalhao,
    required this.identificador,
    this.classe,
    this.exportada = false,
    
    // Medição
    this.alturaTotal = 0, // Valor padrão para registros "esqueleto"
    this.tipoMedidaCAP = 'fita',
    this.valorCAP = 0,
    this.alturaBase = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'talhaoId': talhaoId,
      'id_fazenda': idFazenda,
      'nome_fazenda': nomeFazenda,
      'nome_talhao': nomeTalhao,
      'identificador': identificador,
      'classe': classe,
      'alturaTotal': alturaTotal,
      'tipoMedidaCAP': tipoMedidaCAP,
      'valorCAP': valorCAP,
      'alturaBase': alturaBase,
      'exportada': exportada ? 1 : 0,
    };
  }

  factory CubagemArvore.fromMap(Map<String, dynamic> map) {
    return CubagemArvore(
      id: map['id'],
      talhaoId: map['talhaoId'],
      idFazenda: map['id_fazenda'],
      nomeFazenda: map['nome_fazenda'] ?? '',
      nomeTalhao: map['nome_talhao'] ?? '',
      identificador: map['identificador'],
      classe: map['classe'],
      exportada: map['exportada'] == 1,
      alturaTotal: map['alturaTotal'] ?? 0,
      tipoMedidaCAP: map['tipoMedidaCAP'] ?? 'fita',
      valorCAP: map['valorCAP'] ?? 0,
      alturaBase: map['alturaBase'] ?? 0,
    );
  }
}