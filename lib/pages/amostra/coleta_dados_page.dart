// lib/pages/amostra/coleta_dados_page.dart (VERSÃO COM CORREÇÃO DE NULL CHECK)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/pages/amostra/inventario_page.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:geoforestcoletor/services/permission_service.dart';
import 'package:image/image.dart' as img;


enum FormaParcela { retangular, circular }

class ColetaDadosPage extends StatefulWidget {
  final Parcela? parcelaParaEditar;
  final Talhao? talhao;

  const ColetaDadosPage({super.key, this.parcelaParaEditar, this.talhao})
      : assert(parcelaParaEditar != null || talhao != null, 'É necessário fornecer uma parcela para editar ou um talhão para criar uma nova parcela.');

  @override
  State<ColetaDadosPage> createState() => _ColetaDadosPageState();
}

class _ColetaDadosPageState extends State<ColetaDadosPage> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper.instance;
  late Parcela _parcelaAtual;

  final _nomeFazendaController = TextEditingController();
  final _idFazendaController = TextEditingController();
  final _talhaoParcelaController = TextEditingController();
  final _idParcelaController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _larguraController = TextEditingController();
  final _comprimentoController = TextEditingController();
  final _raioController = TextEditingController();

  Position? _posicaoAtualExibicao;
  bool _buscandoLocalizacao = false;
  String? _erroLocalizacao;
  bool _salvando = false;
  FormaParcela _formaDaParcela = FormaParcela.retangular;
  
  bool _isModoEdicao = false;
  bool _isVinculadoATalhao = false;

  final ImagePicker _picker = ImagePicker();
  final PermissionService _permissionService = PermissionService();
  bool _isReadOnly = false;

  @override
  void initState() {
    super.initState();
    _setupInitialData();
  }
  
  Future<void> _setupInitialData() async {
    setState(() { _salvando = true; });
    if (widget.parcelaParaEditar != null) {
      _isModoEdicao = true;
      final parcelaDoBanco = await dbHelper.getParcelaById(widget.parcelaParaEditar!.dbId!);
      _parcelaAtual = parcelaDoBanco ?? widget.parcelaParaEditar!;
      if(parcelaDoBanco != null) {
        _parcelaAtual.arvores = await dbHelper.getArvoresDaParcela(_parcelaAtual.dbId!);
      }
      _isVinculadoATalhao = _parcelaAtual.talhaoId != null;
      if (_parcelaAtual.status == StatusParcela.concluida) {
        _isReadOnly = true;
      }
    } else {
      _isModoEdicao = false;
      _isReadOnly = false;
      _isVinculadoATalhao = true;
      _parcelaAtual = Parcela(talhaoId: widget.talhao!.id, idParcela: '', areaMetrosQuadrados: 0, dataColeta: DateTime.now(), nomeFazenda: widget.talhao!.fazendaNome, nomeTalhao: widget.talhao!.nome);
    }
    _preencherControllersComDadosAtuais();
    setState(() { _salvando = false; });
  }

  void _preencherControllersComDadosAtuais() {
    final p = _parcelaAtual;
    _nomeFazendaController.text = p.nomeFazenda ?? '';
    _talhaoParcelaController.text = p.nomeTalhao ?? '';
    _idFazendaController.text = p.idFazenda ?? '';
    _idParcelaController.text = p.idParcela;
    _observacaoController.text = p.observacao ?? '';
    _larguraController.clear();
    _comprimentoController.clear();
    _raioController.clear();
    if (p.raio != null && p.raio! > 0) {
      _raioController.text = p.raio.toString().replaceAll('.', ',');
      _formaDaParcela = FormaParcela.circular;
    } else {
      _formaDaParcela = FormaParcela.retangular;
      if (p.largura != null && p.largura! > 0) _larguraController.text = p.largura.toString().replaceAll('.', ',');
      if (p.comprimento != null && p.comprimento! > 0) _comprimentoController.text = p.comprimento.toString().replaceAll('.', ',');
    }
    if (p.latitude != null && p.longitude != null) {
      _posicaoAtualExibicao = Position(latitude: p.latitude!, longitude: p.longitude!, timestamp: DateTime.now(), accuracy: 0.0, altitude: 0.0, altitudeAccuracy: 0.0, heading: 0.0, headingAccuracy: 0.0, speed: 0.0, speedAccuracy: 0.0);
    }
  }

  @override
  void dispose() {
    _nomeFazendaController.dispose();
    _idFazendaController.dispose();
    _talhaoParcelaController.dispose();
    _idParcelaController.dispose();
    _observacaoController.dispose();
    _larguraController.dispose();
    _comprimentoController.dispose();
    _raioController.dispose();
    super.dispose();
  }
  
  Parcela _construirObjetoParcelaParaSalvar() {
    double? largura, comprimento, raio;
    double area = 0.0;
    if (_formaDaParcela == FormaParcela.retangular) {
        largura = double.tryParse(_larguraController.text.replaceAll(',', '.'));
        comprimento = double.tryParse(_comprimentoController.text.replaceAll(',', '.'));
        area = (largura ?? 0) * (comprimento ?? 0);
        raio = null;
    } else {
        raio = double.tryParse(_raioController.text.replaceAll(',', '.'));
        area = math.pi * math.pow(raio ?? 0, 2);
        largura = null;
        comprimento = null;
    }
    return _parcelaAtual.copyWith(
      idParcela: _idParcelaController.text.trim(),
      nomeFazenda: _nomeFazendaController.text.trim(),
      idFazenda: _idFazendaController.text.trim().isNotEmpty ? _idFazendaController.text.trim() : null,
      nomeTalhao: _talhaoParcelaController.text.trim(),
      observacao: _observacaoController.text.trim(),
      areaMetrosQuadrados: area,
      largura: largura,
      comprimento: comprimento,
      raio: raio,
    );
  }

  // <<< INÍCIO DA CORREÇÃO DE NULL CHECK >>>
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1280);
    if (pickedFile == null) return;
    if (!mounted) return;

    final bool hasPermission = await _permissionService.requestStoragePermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de armazenamento negada.'), backgroundColor: Colors.red));
      return;
    }

    try {
      if (_parcelaAtual.talhaoId == null) {
        throw Exception("A parcela precisa ser salva e vinculada a um talhão antes de adicionar fotos.");
      }

      // 1. Obter o Talhão e, a partir dele, a Atividade para encontrar o Projeto.
      final db = await dbHelper.database;
      final talhaoMaps = await db.query('talhoes', where: 'id = ?', whereArgs: [_parcelaAtual.talhaoId]);
      if (talhaoMaps.isEmpty) throw Exception("Talhão vinculado não encontrado no banco de dados.");
      
      final talhao = Talhao.fromMap(talhaoMaps.first);
      final projeto = await dbHelper.getProjetoPelaAtividade(talhao.fazendaAtividadeId);

      // 2. Montar o nome do arquivo com todas as informações
      final projetoNome = projeto?.nome.replaceAll(RegExp(r'[^\w\s-]'), '') ?? 'PROJETO';
      final fazendaNome = _parcelaAtual.nomeFazenda?.replaceAll(RegExp(r'[^\w\s-]'), '') ?? 'FAZENDA';
      final talhaoNome = _parcelaAtual.nomeTalhao?.replaceAll(RegExp(r'[^\w\s-]'), '') ?? 'TALHAO';
      final idParcela = _idParcelaController.text.trim().replaceAll(RegExp(r'[^\w\s-]'), '');
      
      String utmString = "UTM N/A";
      if (_parcelaAtual.latitude != null && _parcelaAtual.longitude != null) {
        final prefs = await SharedPreferences.getInstance();
        final nomeZona = prefs.getString('zona_utm_selecionada') ?? 'SIRGAS 2000 / UTM Zona 22S';
        final codigoEpsg = zonasUtmSirgas2000[nomeZona]!;
        final projWGS84 = proj4.Projection.get('EPSG:4326')!;
        final projUTM = proj4.Projection.get('EPSG:$codigoEpsg')!;
        var pUtm = projWGS84.transform(projUTM, proj4.Point(x: _parcelaAtual.longitude!, y: _parcelaAtual.latitude!));
        utmString = "E: ${pUtm.x.toInt()} N: ${pUtm.y.toInt()}";
      }
      
      final timestamp = DateTime.now();
      final dataHoraFormatada = DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp);
      final nomeArquivoTimestamp = DateFormat('yyyyMMdd_HHmmss').format(timestamp);
      
      final novoNomeArquivo = "${projetoNome}_${fazendaNome}_${talhaoNome}_${idParcela}_$nomeArquivoTimestamp.jpg";
      final textoMarcaDagua = "Projeto: $projetoNome\n"
                              "Fazenda: $fazendaNome | Talhao: $talhaoNome | Parcela: $idParcela\n"
                              "$utmString | $dataHoraFormatada";

      // 3. O resto da lógica de salvar e aplicar a marca d'água
      final directory = await getDownloadsDirectory();
      if (directory == null) throw Exception("Não foi possível acessar a pasta de Downloads.");
      final geoForestDir = Directory(path.join(directory.path, 'GeoForest', 'Fotos'));
      if (!await geoForestDir.exists()) {
        await geoForestDir.create(recursive: true);
      }
      final novoCaminho = path.join(geoForestDir.path, novoNomeArquivo);
      final File arquivoFinal = File(novoCaminho);
      
      final bytesImagemOriginal = await File(pickedFile.path).readAsBytes();
      img.Image? imagemEditavel = img.decodeImage(bytesImagemOriginal);
      if (imagemEditavel == null) throw Exception("Não foi possível decodificar a imagem.");

      img.fillRect(imagemEditavel, x1: 0, y1: imagemEditavel.height - 75, x2: imagemEditavel.width, y2: imagemEditavel.height, color: img.ColorRgba8(0, 0, 0, 128));
      img.drawString(imagemEditavel, textoMarcaDagua, font: img.arial48, x: 10, y: imagemEditavel.height - 65, color: img.ColorRgb8(255, 255, 255));

      await arquivoFinal.writeAsBytes(img.encodeJpg(imagemEditavel, quality: 85));

      setState(() {
        _parcelaAtual.photoPaths.add(novoCaminho);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto salva em: ${geoForestDir.path}'), backgroundColor: Colors.green));

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar foto: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _reabrirParaEdicao() async {
    setState(() => _salvando = true);
    try {
      final parcelaReaberta = _parcelaAtual.copyWith(status: StatusParcela.emAndamento);
      await dbHelper.updateParcela(parcelaReaberta);
      if(mounted) {
        setState(() {
          _parcelaAtual = parcelaReaberta;
          _isReadOnly = false;
          _salvando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parcela reaberta. Agora você pode editar os dados.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao reabrir parcela: $e'), backgroundColor: Colors.red));
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _salvarEIniciarColeta() async {
    if (!_formKey.currentState!.validate()) return;
    
    final parcelaParaSalvar = _construirObjetoParcelaParaSalvar();

    if (parcelaParaSalvar.areaMetrosQuadrados <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A área da parcela deve ser maior que zero'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _salvando = true);

    if (!_isModoEdicao) {
        final parcelaExistente = await dbHelper.getParcelaPorIdParcela(widget.talhao!.id!, _idParcelaController.text.trim());
        if(parcelaExistente != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este ID de Parcela já existe neste talhão.'), backgroundColor: Colors.red));
            setState(() => _salvando = false);
            return;
        }
    }

    try {
      final parcelaAtualizada = parcelaParaSalvar.copyWith(status: StatusParcela.emAndamento);
      final parcelaSalva = await dbHelper.saveFullColeta(parcelaAtualizada, []);

      if (mounted) {
        await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => InventarioPage(parcela: parcelaSalva)));
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _finalizarParcelaVazia() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Parcela?'),
        content: const Text('Você vai marcar a parcela como concluída sem árvores. Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar')),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => _salvando = true);

    try {
      final parcelaFinalizada = _construirObjetoParcelaParaSalvar().copyWith(status: StatusParcela.concluida);
      await dbHelper.saveFullColeta(parcelaFinalizada, []);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parcela finalizada com sucesso!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao finalizar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
  
  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final parcelaEditada = _construirObjetoParcelaParaSalvar();
      final parcelaSalva = await dbHelper.saveFullColeta(parcelaEditada, _parcelaAtual.arvores);
      
      if (mounted) {
        setState(() {
          _parcelaAtual = parcelaSalva;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alterações salvas com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _navegarParaInventario() async {
    if (_salvando) return;
    
    if ((double.tryParse(_larguraController.text.replaceAll(',', '.')) ?? 0) <= 0 && (double.tryParse(_raioController.text.replaceAll(',', '.')) ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Defina e salve a área da parcela antes de continuar.'), backgroundColor: Colors.orange));
      return;
    }
    
    final foiAtualizado = await Navigator.push(context, MaterialPageRoute(builder: (context) => InventarioPage(parcela: _parcelaAtual)));
    
    if (foiAtualizado == true && mounted) {
      _recarregarTela();
    }
  }
  
  Future<void> _recarregarTela() async {
    if (_parcelaAtual.dbId == null) return;
    final parcelaRecarregada = await dbHelper.getParcelaById(_parcelaAtual.dbId!);
    if(parcelaRecarregada != null && mounted) {
      final arvoresRecarregadas = await dbHelper.getArvoresDaParcela(parcelaRecarregada.dbId!);
      parcelaRecarregada.arvores = arvoresRecarregadas;
      setState(() {
        _parcelaAtual = parcelaRecarregada;
        _isReadOnly = _parcelaAtual.status == StatusParcela.concluida;
        _preencherControllersComDadosAtuais();
      });
    }
  }

  Future<void> _obterLocalizacaoAtual() async {
    if (_isReadOnly) return;
    setState(() { _buscandoLocalizacao = true; _erroLocalizacao = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Serviço de GPS desabilitado.';
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permissão negada.';
      }
      if (permission == LocationPermission.deniedForever) throw 'Permissão negada permanentemente.';
      
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 20));
      
      setState(() {
        _posicaoAtualExibicao = position;
        _parcelaAtual = _parcelaAtual.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });

    } catch (e) {
      setState(() => _erroLocalizacao = e.toString());
    } finally {
      if (mounted) setState(() => _buscandoLocalizacao = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    double area = 0.0;
    if (_formaDaParcela == FormaParcela.retangular) {
      final largura = double.tryParse(_larguraController.text.replaceAll(',', '.')) ?? 0;
      final comprimento = double.tryParse(_comprimentoController.text.replaceAll(',', '.')) ?? 0;
      area = largura * comprimento;
    } else {
      final raio = double.tryParse(_raioController.text.replaceAll(',', '.')) ?? 0;
      area = math.pi * math.pow(raio, 2);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isModoEdicao ? 'Dados da Parcela' : 'Nova Parcela'),
        backgroundColor: const Color(0xFF617359),
        foregroundColor: Colors.white,
      ),
      body: _salvando && !_buscandoLocalizacao
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isReadOnly)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, size: 18, color: Colors.amber.shade800),
                          const SizedBox(width: 8),
                          Expanded(child: Text("Parcela concluída (modo de visualização).", style: TextStyle(color: Colors.amber.shade900))),
                        ],
                      ),
                    ),
                  TextFormField(controller: _nomeFazendaController, enabled: !_isVinculadoATalhao && !_isReadOnly, decoration: const InputDecoration(labelText: 'Nome da Fazenda', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business))),
                  const SizedBox(height: 16),
                  TextFormField(controller: _idFazendaController, enabled: !_isVinculadoATalhao && !_isReadOnly, decoration: const InputDecoration(labelText: 'Código da Fazenda', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pin_outlined))),
                  const SizedBox(height: 16),
                  TextFormField(controller: _talhaoParcelaController, enabled: !_isVinculadoATalhao && !_isReadOnly, decoration: const InputDecoration(labelText: 'Talhão', border: OutlineInputBorder(), prefixIcon: Icon(Icons.grid_on))),
                  const SizedBox(height: 16),
                  TextFormField(controller: _idParcelaController, enabled: !_isReadOnly, decoration: const InputDecoration(labelText: 'ID da parcela', border: OutlineInputBorder(), prefixIcon: Icon(Icons.tag)), validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null),
                  const SizedBox(height: 16),
                  _buildCalculadoraArea(area),
                  const SizedBox(height: 16),
                  _buildColetorCoordenadas(),
                  const SizedBox(height: 24),
                  _buildPhotoSection(),
                  const SizedBox(height: 16),
                  TextFormField(controller: _observacaoController, enabled: !_isReadOnly, decoration: const InputDecoration(labelText: 'Observações da Parcela', border: OutlineInputBorder(), prefixIcon: Icon(Icons.comment), helperText: 'Opcional'), maxLines: 3),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildActionButtons() {
    if (_isReadOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 50, child: ElevatedButton.icon(onPressed: _salvando ? null : _reabrirParaEdicao, icon: _salvando ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.edit_outlined), label: const Text('Reabrir para Edição', style: TextStyle(fontSize: 18)), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white))),
          const SizedBox(height: 12),
          SizedBox(height: 50, child: OutlinedButton.icon(onPressed: _navegarParaInventario, icon: const Icon(Icons.park_outlined), label: const Text('Ver Inventário', style: TextStyle(fontSize: 18)))),
        ],
      );
    }
    
    if (_isModoEdicao) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 50, child: ElevatedButton.icon(onPressed: _salvando ? null : _salvarAlteracoes, icon: _salvando ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.save_outlined), label: const Text('Salvar Dados da Parcela', style: TextStyle(fontSize: 18)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white))),
          const SizedBox(height: 12),
          SizedBox(height: 50, child: ElevatedButton.icon(onPressed: _salvando ? null : _navegarParaInventario, icon: const Icon(Icons.park_outlined), label: const Text('Ver/Editar Inventário', style: TextStyle(fontSize: 18)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4433), foregroundColor: Colors.white))),
        ],
      );
    } else { 
      return Row(
        children: [
          Expanded(child: SizedBox(height: 50, child: OutlinedButton(onPressed: _salvando ? null : _finalizarParcelaVazia, style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1D4433)), foregroundColor: const Color(0xFF1D4433)), child: const Text('Finalizar Vazia')))),
          const SizedBox(width: 16),
          Expanded(child: SizedBox(height: 50, child: ElevatedButton(onPressed: _salvando ? null : _salvarEIniciarColeta, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4433), foregroundColor: Colors.white), child: _salvando ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : const Text('Iniciar Coleta', style: TextStyle(fontSize: 18))))),
        ],
      );
    }
  }

  Widget _buildCalculadoraArea(double area) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Área da Parcela', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<FormaParcela>(
          segments: const [
            ButtonSegment(value: FormaParcela.retangular, label: Text('Retangular'), icon: Icon(Icons.crop_square)),
            ButtonSegment(value: FormaParcela.circular, label: Text('Circular'), icon: Icon(Icons.circle_outlined)),
          ],
          selected: {_formaDaParcela},
          onSelectionChanged: _isReadOnly ? null : (newSelection) => setState(() { _formaDaParcela = newSelection.first; }),
        ),
        const SizedBox(height: 16),
        if (_formaDaParcela == FormaParcela.retangular)
          Row(children: [
            Expanded(child: TextFormField(controller: _larguraController, enabled: !_isReadOnly, decoration: const InputDecoration(labelText: 'Largura (m)', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null)),
            const SizedBox(width: 8), const Text('x', style: TextStyle(fontSize: 20)), const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _comprimentoController, enabled: !_isReadOnly, decoration: const InputDecoration(labelText: 'Comprimento (m)', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null)),
          ])
        else
          TextFormField(controller: _raioController, enabled: !_isReadOnly, decoration: const InputDecoration(labelText: 'Raio (m)', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null),
        const SizedBox(height: 16),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: area > 0 ? Colors.green[50] : Colors.grey[200], borderRadius: BorderRadius.circular(4), border: Border.all(color: area > 0 ? Colors.green : Colors.grey)),
          child: Column(children: [ const Text('Área Calculada:'), Text('${area.toStringAsFixed(2)} m²', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: area > 0 ? Colors.green[800] : Colors.black)) ]),
        ),
      ],
    );
  }

  Widget _buildColetorCoordenadas() {
    final latExibicao = _posicaoAtualExibicao?.latitude ?? _parcelaAtual.latitude;
    final lonExibicao = _posicaoAtualExibicao?.longitude ?? _parcelaAtual.longitude;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coordenadas da Parcela', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            Expanded(
              child: _buscandoLocalizacao
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Buscando...')])
                : _erroLocalizacao != null
                  ? Text('Erro: $_erroLocalizacao', style: const TextStyle(color: Colors.red))
                  : (latExibicao == null)
                    ? const Text('Nenhuma localização obtida.')
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Lat: ${latExibicao.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Lon: ${lonExibicao!.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (_posicaoAtualExibicao != null && _posicaoAtualExibicao!.accuracy > 0)
                          Text('Precisão: ±${_posicaoAtualExibicao!.accuracy.toStringAsFixed(1)}m', style: TextStyle(color: Colors.grey[700])),
                      ]),
            ),
            IconButton(icon: const Icon(Icons.my_location, color: Color(0xFF1D4433)), onPressed: _buscandoLocalizacao || _isReadOnly ? null : _obterLocalizacaoAtual, tooltip: 'Obter localização'),
          ]),
        ),
      ],
    );
  }
  
  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos da Parcela', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              _parcelaAtual.photoPaths.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Text('Nenhuma foto adicionada.')))
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: _parcelaAtual.photoPaths.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_parcelaAtual.photoPaths[index]), fit: BoxFit.cover)),
                            if (!_isReadOnly)
                              Positioned(
                                top: -8, right: -8,
                                child: IconButton(
                                  icon: const CircleAvatar(backgroundColor: Colors.white, radius: 12, child: Icon(Icons.close, color: Colors.red, size: 16)),
                                  onPressed: () => setState(() => _parcelaAtual.photoPaths.removeAt(index)),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
              if (!_isReadOnly) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Câmera'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeria'))),
                  ],
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }
}