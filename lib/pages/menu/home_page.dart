// lib/pages/menu/home_page.dart (VERSÃO COM FLUXO DE SELEÇÃO DE PROJETO)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Importações do Projeto
import 'package:geoforestcoletor/pages/analises/analise_selecao_page.dart';
import 'package:geoforestcoletor/pages/menu/configuracoes_page.dart';
import 'package:geoforestcoletor/pages/projetos/lista_projetos_page.dart';
import 'package:geoforestcoletor/pages/planejamento/selecao_atividade_mapa_page.dart';
import 'package:geoforestcoletor/pages/menu/paywall_page.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/providers/license_provider.dart';
import 'package:geoforestcoletor/services/export_service.dart';
import 'package:geoforestcoletor/widgets/menu_card.dart';
import 'package:geoforestcoletor/services/sync_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSyncing = false;

  Future<void> _executarSincronizacao() async {
    // ... (esta função não muda)
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Iniciando sincronização...'), duration: Duration(seconds: 15)),
    );
    try {
      final syncService = SyncService();
      await syncService.sincronizarDados();
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados sincronizados com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na sincronização: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }
  
  // <<< LÓGICA DE IMPORTAÇÃO RESTAURADA PARA NAVEGAR PARA A LISTA DE PROJETOS >>>
  void _mostrarDialogoImportacao(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text('Importar Dados para um Projeto', style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined, color: Colors.blue),
            title: const Text('Importar Arquivo CSV Universal'),
            subtitle: const Text('Selecione o projeto de destino para os dados.'),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => const ListaProjetosPage(
                  title: 'Importar para o Projeto...',
                  isImporting: true, // Ativa o modo de importação
                ),
              ));
            },
          ),
        ],
      ),
    );
  }

  // O resto do arquivo (build, _abrirAnalista, _mostrarDialogoExportacao, etc.) não muda.
  void _abrirAnalistaDeDados(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnaliseSelecaoPage()),
    );
  }

  void _mostrarDialogoExportacao(BuildContext context) {
    final exportService = ExportService();

    void _mostrarDialogoParcelas(BuildContext mainDialogContext) {
      showDialog(
        context: mainDialogContext,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Tipo de Exportação de Coleta'),
          content: const Text(
              'Deseja exportar apenas os dados novos ou um backup completo de todas as coletas de parcela?'),
          actions: [
            TextButton(
              child: const Text('Apenas Novas'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarDados(context);
              },
            ),
            ElevatedButton(
              child: const Text('Todas (Backup)'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarTodasAsParcelasBackup(context);
              },
            ),
          ],
        ),
      );
    }

    void _mostrarDialogoCubagem(BuildContext mainDialogContext) {
      showDialog(
        context: mainDialogContext,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Tipo de Exportação de Cubagem'),
          content: const Text(
              'Deseja exportar apenas os dados novos ou um backup completo de todas as cubagens?'),
          actions: [
            TextButton(
              child: const Text('Apenas Novas'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarNovasCubagens(context);
              },
            ),
            ElevatedButton(
              child: const Text('Todas (Backup)'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarTodasCubagensBackup(context);
              },
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
              child: Text('Escolha o que deseja exportar',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              leading:
                  const Icon(Icons.table_rows_outlined, color: Colors.green),
              title: const Text('Coletas de Parcela (CSV)'),
              subtitle: const Text('Exporta os dados de parcelas e árvores.'),
              onTap: () {
                Navigator.of(ctx).pop();
                _mostrarDialogoParcelas(context);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.table_chart_outlined, color: Colors.brown),
              title: const Text('Cubagens Rigorosas (CSV)'),
              subtitle: const Text('Exporta os dados de cubagens e seções.'),
              onTap: () {
                Navigator.of(ctx).pop();
                _mostrarDialogoCubagem(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: Colors.purple),
              title: const Text('Plano de Amostragem (GeoJSON)'),
              subtitle:
                  const Text('Exporta o plano de amostragem do mapa.'),
              onTap: () {
                Navigator.of(ctx).pop();
                context.read<MapProvider>().exportarPlanoDeAmostragem(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarAvisoDeUpgrade(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Funcionalidade indisponível"),
        content: Text("A função '$featureName' não está disponível no seu plano atual. Faça upgrade para desbloqueá-la."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Entendi"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallPage()));
            },
            child: const Text("Ver Planos"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final licenseProvider = context.watch<LicenseProvider>();
    final bool podeExportar = licenseProvider.licenseData?.features['exportacao'] ?? false;
    final bool podeAnalisar = licenseProvider.licenseData?.features['analise'] ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 1.0,
          children: [
            MenuCard(
              icon: Icons.folder_copy_outlined,
              label: 'Projetos e Coletas',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListaProjetosPage(title: 'Meus Projetos'),
                ),
              ),
            ),
            MenuCard(
              icon: Icons.map_outlined,
              label: 'Planejamento de Campo',
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const SelecaoAtividadeMapaPage()));
              },
            ),
            MenuCard(
              icon: Icons.insights_outlined,
              label: 'GeoForest Analista',
              onTap: podeAnalisar
                  ? () => _abrirAnalistaDeDados(context)
                  : () => _mostrarAvisoDeUpgrade(context, "GeoForest Analista"),
            ),
            MenuCard(
              icon: Icons.download_for_offline_outlined,
              label: 'Importar Dados (CSV)',
              onTap: () => _mostrarDialogoImportacao(context),
            ),
            MenuCard(
              icon: Icons.upload_file_outlined,
              label: 'Exportar Dados',
              onTap: podeExportar
                  ? () => _mostrarDialogoExportacao(context)
                  : () => _mostrarAvisoDeUpgrade(context, "Exportar Dados"),
            ),
            MenuCard(
              icon: Icons.settings_outlined,
              label: 'Configurações',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConfiguracoesPage()),
              ),
            ),
            MenuCard(
              icon: Icons.credit_card,
              label: 'Assinaturas',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PaywallPage()),
              ),
            ),
            MenuCard(
              icon: _isSyncing ? Icons.downloading_outlined : Icons.sync_outlined,
              label: _isSyncing ? 'Sincronizando...' : 'Sincronizar Dados',
              onTap: _isSyncing ? () {} : _executarSincronizacao,
            ),
          ],
        ),
      ),
    );
  }
}