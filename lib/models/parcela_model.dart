// lib/models/parcela_model.dart

import 'dart:convert'; // <<< IMPORT NECESSÁRIO PARA JSON
import 'package:flutter/material.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';

enum StatusParcela {
  pendente(Icons.pending_outlined, Colors.grey),
  emAndamento(Icons.edit_note_outlined, Colors.orange),
  concluida(Icons.check_circle_outline, Colors.green),
  exportada(Icons.cloud_done_outlined, Colors.blue);

  final IconData icone;
  final Color cor;
  
  const StatusParcela(this.icone, this.cor);
}

class Parcela {
  int? dbId;
  int? talhaoId; 
  DateTime? dataColeta;
  
  final String? idFazenda;
  final String? nomeFazenda;
  final String? nomeTalhao;

  // Campos principais
  final String idParcela;
  final double areaMetrosQuadrados;
  final String? observacao;
  final double? latitude;
  final double? longitude;
  StatusParcela status;
  bool exportada;
  bool isSynced;
  final double? largura;
  final double? comprimento;
  final double? raio;
  
  // <<< NOVOS CAMPOS >>>
  List<String> photoPaths; // Para os caminhos das fotos
  
  // <<< CAMPOS REMOVIDOS >>>
  // final String? espacamento;
  // final double? idadeFloresta;
  // final double? areaTalhao;

  List<Arvore> arvores;

  Parcela({
    this.dbId,
    required this.talhaoId,
    required this.idParcela,
    required this.areaMetrosQuadrados,
    this.idFazenda,
    this.nomeFazenda,
    this.nomeTalhao,
    // espacamento, // removido
    this.observacao,
    this.latitude,
    this.longitude,
    this.dataColeta,
    this.status = StatusParcela.pendente,
    this.exportada = false,
    this.isSynced = false,
    this.largura,
    this.comprimento,
    this.raio,
    // idadeFloresta, // removido
    // areaTalhao,    // removido
    this.photoPaths = const [], // <<< VALOR PADRÃO
    this.arvores = const [],
  });

  Parcela copyWith({
    int? dbId,
    int? talhaoId,
    String? idFazenda,
    String? nomeFazenda,
    String? nomeTalhao,
    String? idParcela,
    double? areaMetrosQuadrados,
    // String? espacamento, // removido
    String? observacao,
    double? latitude,
    double? longitude,
    DateTime? dataColeta,
    StatusParcela? status,
    bool? exportada,
    bool? isSynced,
    double? largura,
    double? comprimento,
    double? raio,
    // double? idadeFloresta, // removido
    // double? areaTalhao,    // removido
    List<String>? photoPaths, // <<< ADICIONADO
    List<Arvore>? arvores,
  }) {
    return Parcela(
      dbId: dbId ?? this.dbId,
      talhaoId: talhaoId ?? this.talhaoId,
      idFazenda: idFazenda ?? this.idFazenda,
      nomeFazenda: nomeFazenda ?? this.nomeFazenda,
      nomeTalhao: nomeTalhao ?? this.nomeTalhao,
      idParcela: idParcela ?? this.idParcela,
      areaMetrosQuadrados: areaMetrosQuadrados ?? this.areaMetrosQuadrados,
      // espacamento: espacamento ?? this.espacamento, // removido
      observacao: observacao ?? this.observacao,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dataColeta: dataColeta ?? this.dataColeta,
      status: status ?? this.status,
      exportada: exportada ?? this.exportada,
      isSynced: isSynced ?? this.isSynced,
      largura: largura ?? this.largura,
      comprimento: comprimento ?? this.comprimento,
      raio: raio ?? this.raio,
      // idadeFloresta: idadeFloresta ?? this.idadeFloresta, // removido
      // areaTalhao: areaTalhao ?? this.areaTalhao,       // removido
      photoPaths: photoPaths ?? this.photoPaths, // <<< ADICIONADO
      arvores: arvores ?? this.arvores,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': dbId,
      'talhaoId': talhaoId,
      'idFazenda': idFazenda,
      'nomeFazenda': nomeFazenda,
      'nomeTalhao': nomeTalhao,
      'idParcela': idParcela,
      'areaMetrosQuadrados': areaMetrosQuadrados,
      // 'espacamento': espacamento, // removido
      'observacao': observacao,
      'latitude': latitude,
      'longitude': longitude,
      'dataColeta': dataColeta?.toIso8601String(),
      'status': status.name,
      'exportada': exportada ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
      'largura': largura,
      'comprimento': comprimento,
      'raio': raio,
      'photoPaths': jsonEncode(photoPaths), // <<< SALVA A LISTA COMO TEXTO JSON
      // 'idadeFloresta': idadeFloresta, // removido
      // 'areaTalhao': areaTalhao,       // removido
    };
  }

  factory Parcela.fromMap(Map<String, dynamic> map) {
    List<String> paths = [];
    if (map['photoPaths'] != null) {
      try {
        // Tenta decodificar o JSON. Se falhar, a lista permanece vazia.
        paths = List<String>.from(jsonDecode(map['photoPaths']));
      } catch (e) {
        // Lida com casos onde o dado pode não ser um JSON válido.
        print("Erro ao decodificar photoPaths: $e");
      }
    }

    return Parcela(
      dbId: map['id'],
      talhaoId: map['talhaoId'],
      idFazenda: map['idFazenda'],
      nomeFazenda: map['nomeFazenda'],
      nomeTalhao: map['nomeTalhao'],
      idParcela: map['idParcela'],
      areaMetrosQuadrados: map['areaMetrosQuadrados'],
      // espacamento: map['espacamento'], // removido
      observacao: map['observacao'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      dataColeta: map['dataColeta'] != null ? DateTime.parse(map['dataColeta']) : null,
      status: StatusParcela.values.firstWhere(
            (e) => e.name == map['status'],
        orElse: () => StatusParcela.pendente,
      ),
      exportada: map['exportada'] == 1,
      isSynced: map['isSynced'] == 1,
      largura: map['largura'],
      comprimento: map['comprimento'],
      raio: map['raio'],
      photoPaths: paths, // <<< LÊ A LISTA DO TEXTO JSON
      // idadeFloresta: map['idadeFloresta'], // removido
      // areaTalhao: map['areaTalhao'],       // removido
    );
  }
}