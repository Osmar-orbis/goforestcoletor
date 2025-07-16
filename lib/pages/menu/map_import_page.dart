// lib/pages/menu/map_import_page.dart (VERSÃO COMPLETA E FINAL)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/models/sample_point.dart';
import 'package:geoforestcoletor/pages/amostra/coleta_dados_page.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';

class MapImportPage extends StatefulWidget {
  const MapImportPage({super.key});

  @override
  State<MapImportPage> createState() => _MapImportPageState();
}

class _MapImportPageState extends State<MapImportPage> with RouteAware {
  final _mapController = MapController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MapProvider.routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }
  
  @override
  void didPopNext() {
    super.didPopNext();
    debugPrint("Mapa visível novamente, recarregando os dados das amostras...");
    context.read<MapProvider>().loadSamplesParaAtividade();
  }

  @override
  void dispose() {
    MapProvider.routeObserver.unsubscribe(this);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    if (mapProvider.isFollowingUser) {
      mapProvider.toggleFollowingUser();
    }
    super.dispose();
  }

  Color _getMarkerColor(SampleStatus status) {
    switch (status) {
      case SampleStatus.open: return Colors.orange.shade300;
      case SampleStatus.completed: return Colors.green;
      case SampleStatus.exported: return Colors.blue;
      case SampleStatus.untouched: return Colors.white;
    }
  }

  Color _getMarkerTextColor(SampleStatus status) {
    switch (status) {
      case SampleStatus.open: case SampleStatus.untouched: return Colors.black;
      case SampleStatus.completed: case SampleStatus.exported: return Colors.white;
    }
  }

  // NOVA FUNÇÃO para mostrar o diálogo de importação
  Future<void> _handleImport() async {
    final provider = context.read<MapProvider>();
    
    // Mostra um diálogo para o usuário escolher o que importar
    final bool? isPlano = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O que você quer importar?'),
        content: const Text('Escolha o tipo de arquivo para importar para esta atividade.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false), // Carga de Talhões
            child: const Text('Carga de Talhões (Polígonos)'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true), // Plano de Amostragem
            child: const Text('Plano de Amostragem (Pontos)'),
          ),
        ],
      ),
    );

    if (isPlano == null || !mounted) return;

    final resultMessage = await provider.processarImportacaoDeArquivo(isPlanoDeAmostragem: isPlano);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultMessage), duration: const Duration(seconds: 5)));
    
    if (provider.polygons.isNotEmpty) {
      _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(provider.polygons.expand((p) => p.points).toList()),
          padding: const EdgeInsets.all(50.0)));
    } else if (provider.samplePoints.isNotEmpty) {
      _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(provider.samplePoints.map((p) => p.position).toList()),
          padding: const EdgeInsets.all(50.0)));
    }
  }
  
  Future<void> _handleGenerateSamples() async {
    final provider = context.read<MapProvider>();
    if (provider.polygons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importe ou desenhe os polígonos dos talhões primeiro.')));
      return;
    }

    final density = await _showDensityDialog();
    if (density == null || !mounted) return;
    
    final resultMessage = await provider.gerarAmostrasParaAtividade(hectaresPerSample: density);
    
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultMessage), duration: const Duration(seconds: 4)));
    }
  }

  Future<double?> _showDensityDialog() {
    final densityController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Densidade da Amostragem'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: densityController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Hectares por amostra', suffixText: 'ha'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Campo obrigatório';
              if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Número inválido';
              return null;
            }
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, double.parse(densityController.text.replaceAll(',', '.')));
              }
            },
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLocationButtonPressed() async {
    final provider = context.read<MapProvider>();
    if (provider.isFollowingUser) {
      final currentPosition = provider.currentUserPosition;
      if (currentPosition != null) {
        _mapController.move(LatLng(currentPosition.latitude, currentPosition.longitude), 17.0);
      }
      return;
    }
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Serviço de GPS desabilitado.')));
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de localização negada.')));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão negada permanentemente.')));
      return;
    }
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando sua localização...')));
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      provider.updateUserPosition(position);
      provider.toggleFollowingUser();
      _mapController.move(LatLng(position.latitude, position.longitude), 17.0);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível obter a localização: $e')));
      }
    }
  }

  AppBar _buildAppBar(MapProvider mapProvider) {
    final atividadeTipo = mapProvider.currentAtividade?.tipo ?? 'Planejamento';

    return AppBar(
      title: Text('Planejamento: $atividadeTipo'),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: mapProvider.isLoading ? null : () => context.read<MapProvider>().exportarPlanoDeAmostragem(context),
          tooltip: 'Exportar Plano de Amostragem',
        ),
        if(mapProvider.polygons.isNotEmpty)
          IconButton(
              icon: const Icon(Icons.grid_on_sharp),
              onPressed: mapProvider.isLoading ? null : _handleGenerateSamples,
              tooltip: 'Gerar Amostras'),
        IconButton(
            icon: const Icon(Icons.edit_location_alt_outlined),
            onPressed: () => mapProvider.startDrawing(),
            tooltip: 'Desenhar Área'),
        IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: mapProvider.isLoading ? null : _handleImport, // Chama a nova função com diálogo
            tooltip: 'Importar Arquivo'),
      ],
    );
  }

  AppBar _buildDrawingAppBar(MapProvider mapProvider) {
    return AppBar(
      backgroundColor: Colors.grey.shade800,
      title: const Text('Desenhando a Área'),
      leading: IconButton(icon: const Icon(Icons.close), onPressed: () => mapProvider.cancelDrawing(), tooltip: 'Cancelar Desenho'),
      actions: [
        IconButton(icon: const Icon(Icons.undo), onPressed: () => mapProvider.undoLastDrawnPoint(), tooltip: 'Desfazer Último Ponto'),
        IconButton(icon: const Icon(Icons.check), onPressed: () => mapProvider.saveDrawnPolygon(), tooltip: 'Salvar Polígono'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final currentUserPosition = mapProvider.currentUserPosition;
    final isDrawing = mapProvider.isDrawing;

    if (currentUserPosition != null && mapProvider.isFollowingUser) {
      _mapController.move(LatLng(currentUserPosition.latitude, currentUserPosition.longitude), _mapController.camera.zoom);
    }

    return Scaffold(
      appBar: isDrawing ? _buildDrawingAppBar(mapProvider) : _buildAppBar(mapProvider),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-15.7, -47.8),
              initialZoom: 4,
              onPositionChanged: (position, hasGesture) {
                if(hasGesture && mapProvider.isFollowingUser) {
                  context.read<MapProvider>().toggleFollowingUser();
                }
              },
              onTap: (tapPosition, point) { if (isDrawing) mapProvider.addDrawnPoint(point); },
            ),
            children: [
              TileLayer(
                  urlTemplate: mapProvider.currentTileUrl,
                  userAgentPackageName: 'com.example.geoforestcoletor'),
              if (mapProvider.polygons.isNotEmpty)
                PolygonLayer(polygons: mapProvider.polygons),
              
              MarkerLayer(
                markers: mapProvider.samplePoints.map((samplePoint) {
                  final color = _getMarkerColor(samplePoint.status);
                  final textColor = _getMarkerTextColor(samplePoint.status);
                  return Marker(
                    width: 40.0, height: 40.0, point: samplePoint.position,
                    child: GestureDetector(
                      onTap: () async {
                        if (!mounted) return;
                        final dbId = samplePoint.data['dbId'] as int?;
                        if (dbId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: ID da parcela não encontrado.')));
                          return;
                        }
                        final parcela = await DatabaseHelper.instance.getParcelaById(dbId);
                        if (!mounted || parcela == null) return;

                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (context) => ColetaDadosPage(parcelaParaEditar: parcela))
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(2, 2))]),
                        child: Center(child: Text(samplePoint.id.toString(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14))),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              if (isDrawing && mapProvider.drawnPoints.isNotEmpty)
                PolylineLayer(polylines: [ Polyline(points: mapProvider.drawnPoints, strokeWidth: 2.0, color: Colors.red.withOpacity(0.8)), ]),
              if (isDrawing)
                MarkerLayer(
                  markers: mapProvider.drawnPoints.map((point) {
                    return Marker(
                      point: point,
                      width: 12,
                      height: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              if (currentUserPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: LatLng(currentUserPosition.latitude, currentUserPosition.longitude),
                      child: const LocationMarker(),
                    ),
                  ],
                ),
            ],
          ),
          if (mapProvider.isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Processando...", style: TextStyle(color: Colors.white, fontSize: 16))
                  ]
                )
              )
            ),
          if (!isDrawing)
            Positioned(
              top: 10,
              left: 10,
              child: Column(
                children: [
                   FloatingActionButton(
                     onPressed: _handleLocationButtonPressed,
                     tooltip: 'Minha Localização',
                     heroTag: 'centerLocationFab',
                     backgroundColor: mapProvider.isFollowingUser ? Colors.blue : Theme.of(context).colorScheme.primary,
                     foregroundColor: Colors.white,
                     child: Icon(mapProvider.isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed),
                   ),
                   const SizedBox(height: 10),
                   FloatingActionButton(
                     onPressed: () => context.read<MapProvider>().switchMapLayer(),
                     tooltip: 'Mudar Camada do Mapa',
                     heroTag: 'switchLayerFab',
                     mini: true,
                     child: Icon(mapProvider.currentLayer == MapLayerType.ruas
                         ? Icons.satellite_outlined
                         : (mapProvider.currentLayer == MapLayerType.satelite
                             ? Icons.terrain
                             : Icons.map_outlined)),
                   ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class LocationMarker extends StatefulWidget {
  const LocationMarker({super.key});

  @override
  State<LocationMarker> createState() => _LocationMarkerState();
}

class _LocationMarkerState extends State<LocationMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: false);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_animation),
          child: ScaleTransition(
            scale: _animation,
            child: Container(
              width: 50.0,
              height: 50.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.4),
              ),
            ),
          ),
        ),
        Container(
          width: 20.0,
          height: 20.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade700,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}